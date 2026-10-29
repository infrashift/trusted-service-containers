#!/usr/bin/env bash
# Run the `Derive identifiers` step of release.yml's Gate job against a stub
# `gh`. The step is extracted from the workflow, not copied, so this tests the
# code that runs.
#
# Why this exists: the step looked up the merge commit's pull request once.
# GitHub links the two a few seconds after the push event, so the merges of #40
# and #41 both found nothing and refused to release. The step now retries an
# EMPTY answer for a bounded time. These cases pin both halves of that: the
# retry recovers a late link, and it never turns a missing PR or an API error
# into a pass.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="${HERE}/../.github/workflows/release.yml"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "error: test-release-gate: $*" >&2; exit 1; }

# --- Extract the step's script and its LOOKUP_ATTEMPTS ----------------------
python3 - "$WORKFLOW" "$TMP/step.sh" "$TMP/attempts" <<'EOF'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
steps = [s for s in wf['jobs']['gate-check']['steps'] if s.get('name') == 'Derive identifiers']
if len(steps) != 1:
    sys.exit(f"expected one 'Derive identifiers' step in gate-check, found {len(steps)}")
open(sys.argv[2], 'w').write(steps[0]['run'])
open(sys.argv[3], 'w').write(str(steps[0]['env']['LOOKUP_ATTEMPTS']))
EOF
ATTEMPTS="$(cat "$TMP/attempts")"
[[ "$ATTEMPTS" =~ ^[0-9]+$ && "$ATTEMPTS" -ge 2 ]] \
  || fail "LOOKUP_ATTEMPTS must be an integer >= 2 for a retry to exist, got '${ATTEMPTS}'"

MERGE=1111111111111111111111111111111111111111
HEAD=2222222222222222222222222222222222222222
MERGED='[{"number":40,"merged_at":"2026-10-29T01:35:11Z","head":{"sha":"'"$HEAD"'"}}]'
OPEN='[{"number":40,"merged_at":null,"head":{"sha":"'"$HEAD"'"}}]'

# --- Stub gh: answer each call from the next line of $GH_SCRIPT -------------
# A line is a JSON body to print, or the word FAIL to exit 1 like an API error.
# Past the last line, the last line repeats.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
n=$(( $(wc -l < "$GH_CALLS") + 1 ))
echo "$*" >> "$GH_CALLS"
line=$(sed -n "${n}p" "$GH_SCRIPT")
[[ -n "$line" ]] || line=$(tail -n 1 "$GH_SCRIPT")
if [[ "$line" == FAIL ]]; then
  echo "gh: HTTP 401: Bad credentials" >&2
  exit 1
fi
printf '%s\n' "$line"
EOF
chmod +x "$TMP/bin/gh"

# run_case <name> <answers...>: run the step; sets RC, CALLS and OUT.
run_case() {
  local name="$1"; shift
  printf '%s\n' "$@" > "$TMP/$name.script"
  : > "$TMP/$name.calls"
  : > "$TMP/$name.output"
  RC=0
  GH_SCRIPT="$TMP/$name.script" GH_CALLS="$TMP/$name.calls" PATH="$TMP/bin:$PATH" \
    GITHUB_OUTPUT="$TMP/$name.output" GH_TOKEN=x REPO=infrashift/test MERGE_SHA="$MERGE" \
    LOOKUP_ATTEMPTS="$ATTEMPTS" LOOKUP_DELAY_SECONDS=0 \
    bash "$TMP/step.sh" > "$TMP/$name.log" 2>&1 || RC=$?
  CALLS=$(wc -l < "$TMP/$name.calls")
  OUT="$TMP/$name.output"
}

# 1. The link is there on the first call: one call, and the outputs are right.
run_case first "$MERGED"
[[ "$RC" -eq 0 ]] || { cat "$TMP/first.log" >&2; fail "first: a listed merged PR did not resolve"; }
[[ "$CALLS" -eq 1 ]] || fail "first: expected 1 API call, made ${CALLS}"
grep -qx 'pr_number=40' "$OUT" || fail "first: pr_number=40 missing from GITHUB_OUTPUT"
grep -qx "head_sha=${HEAD}" "$OUT" || fail "first: head_sha missing from GITHUB_OUTPUT"
grep -qx "short_sha=${MERGE:0:7}" "$OUT" || fail "first: short_sha is not the merge commit's"

# 2. The link appears late: the retry recovers it. This is the #40/#41 race.
run_case late '[]' '[]' "$MERGED"
[[ "$RC" -eq 0 ]] || { cat "$TMP/late.log" >&2; fail "late: a PR listed on the 3rd call did not resolve; the retry is missing"; }
[[ "$CALLS" -eq 3 ]] || fail "late: expected 3 API calls, made ${CALLS}"
grep -qx 'pr_number=40' "$OUT" || fail "late: pr_number=40 missing from GITHUB_OUTPUT"

# 3. No PR ever: fail after exactly LOOKUP_ATTEMPTS calls, writing no outputs.
run_case never '[]'
[[ "$RC" -ne 0 ]] || fail "never: a push with no merged PR passed the Gate"
[[ "$CALLS" -eq "$ATTEMPTS" ]] || fail "never: expected ${ATTEMPTS} API calls, made ${CALLS}"
grep -q 'refusing to release' "$TMP/never.log" || fail "never: no 'refusing to release' error"
[[ ! -s "$OUT" ]] || fail "never: wrote GITHUB_OUTPUT despite failing"

# 4. A PR that is listed but NOT merged counts as no PR, and is retried.
run_case unmerged "$OPEN"
[[ "$RC" -ne 0 ]] || fail "unmerged: an unmerged PR passed the Gate"
[[ "$CALLS" -eq "$ATTEMPTS" ]] || fail "unmerged: expected ${ATTEMPTS} API calls, made ${CALLS}"

# 5. An API error fails on the first call. It is not retried as if empty.
run_case apierror FAIL "$MERGED"
[[ "$RC" -ne 0 ]] || fail "apierror: an API error passed the Gate"
[[ "$CALLS" -eq 1 ]] || fail "apierror: an API error was retried (${CALLS} calls); only an empty answer may be"

# 6. A malformed head sha still fails.
run_case badsha '[{"number":40,"merged_at":"2026-10-29T01:35:11Z","head":{"sha":"not-a-sha"}}]'
[[ "$RC" -ne 0 ]] || fail "badsha: a malformed head sha passed the Gate"
grep -q 'malformed head sha' "$TMP/badsha.log" || fail "badsha: no 'malformed head sha' error"

echo "OK: release.yml Gate retries a late PR link, and still fails on no PR, an unmerged PR, an API error and a bad sha"
