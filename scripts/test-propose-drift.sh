#!/usr/bin/env bash
# Run scripts/propose-drift.sh end to end against a throwaway repository: a
# local bare "origin" and a stub `gh` that records its calls instead of
# talking to GitHub.
#
# Why this exists: propose-drift.sh called `git commit -m ... -F -`, which git
# rejects as a usage error. Only the CHANGED=1 path reaches that line, CI never
# exercised it, and shellcheck cannot see it -- so every scheduled
# drift-upstream run that found drift (2026-09-16..30) died there, before the
# proposal branch or the tracking issue existed. Nobody saw the drift.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/propose-drift.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "error: test-propose-drift: $*" >&2; exit 1; }

# --- A repository with one committed versions.json and a bare origin --------
git init -q --bare "$TMP/origin.git"
git init -q -b main "$TMP/work"
cd "$TMP/work"
git config user.name test; git config user.email test@example.invalid
git config commit.gpgsign false
echo '{"images":{}}' > versions.json
git add versions.json && git commit -q -m init
git remote add origin "$TMP/origin.git"
git push -q origin main

# --- Stub gh: log every call; `issue list` finds no existing issue ----------
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "issue create") echo "https://github.invalid/issues/1" ;;
  *) : ;;
esac
EOF
chmod +x "$TMP/bin/gh"

printf '| svc | from | to |\n|---|---|---|\n| `x/runtime` | a | b |\n' > "$TMP/report.md"
echo '{"images":{"x":{}}}' > versions.json

GH_LOG="$TMP/gh.log" PATH="$TMP/bin:$PATH" \
  BRANCH=automation/upstream-drift LABEL=upstream-drift \
  TITLE="Upstream drift: newer releases available within track" \
  REPORT="$TMP/report.md" GITHUB_REPOSITORY=infrashift/test \
  GITHUB_STEP_SUMMARY=/dev/null CHANGED=1 ALARMS=0 \
  "$SCRIPT" > "$TMP/out.log" 2>&1 \
  || { cat "$TMP/out.log" >&2; fail "propose-drift.sh exited non-zero on the CHANGED=1 path"; }

# --- The branch reached origin, carrying the change and the report ---------
git --git-dir="$TMP/origin.git" rev-parse -q --verify refs/heads/automation/upstream-drift >/dev/null \
  || fail "branch automation/upstream-drift was not pushed"
subject=$(git --git-dir="$TMP/origin.git" log -1 --format=%s automation/upstream-drift)
[[ "$subject" == "chore(pins): Upstream drift: newer releases available within track" ]] \
  || fail "unexpected commit subject: ${subject}"
git --git-dir="$TMP/origin.git" log -1 --format=%B automation/upstream-drift | grep -qF '`x/runtime`' \
  || fail "commit body does not carry the drift report"
git --git-dir="$TMP/origin.git" show automation/upstream-drift:versions.json | grep -q '"x"' \
  || fail "pushed versions.json does not carry the change"

# --- And the drift became visible: one tracking issue created --------------
grep -q '^issue create ' "$TMP/gh.log" || fail "no tracking issue was created"

echo "OK: propose-drift.sh pushes the proposal branch and opens the tracking issue"
