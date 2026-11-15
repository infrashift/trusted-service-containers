#!/usr/bin/env bash
# Run the summary steps of review.yml and release.yml against fixture download
# directories. The steps are extracted from the workflows, not copied, so this
# tests the code that runs.
#
# Why this exists: actions/download-artifact unpacks ONE artifact that matches
# `pattern:` straight into `path:`, and several into `path/<artifact-name>/`.
# The summaries globbed `verdicts/*/review-verdict.json`, so PR #63 -- one
# mirror leg, a signed PASS with Blocking 0 -- found no verdict and got a red
# review/cve-policy. These cases pin zero, one and many artifacts, and that a
# missing or failing verdict still turns the check red.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WF="${HERE}/../.github/workflows"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "error: test-artifact-summaries: $*" >&2; exit 1; }

# --- Extract the steps ------------------------------------------------------
python3 - "$WF" "$TMP" <<'EOF'
import sys, yaml
wf, out = sys.argv[1], sys.argv[2]
def step(file, job, name, dest):
    d = yaml.safe_load(open(f"{wf}/{file}"))
    s = [s for s in d['jobs'][job]['steps'] if s.get('name') == name]
    if len(s) != 1:
        sys.exit(f"expected one '{name}' step in {file}:{job}, found {len(s)}")
    open(f"{out}/{dest}", 'w').write(s[0]['run'])
step('review.yml', 'summary', 'Build the report', 'review-report.sh')
step('review.yml', 'summary', 'Resolve review/cve-policy', 'review-resolve.sh')
step('release.yml', 'summary', 'Report', 'release-report.sh')
EOF
# The review steps hand files to each other through /tmp. Point that at a
# per-case directory so cases cannot see each other's report.
grep -q '/tmp/report.md' "$TMP/review-report.sh" \
  || fail "Build the report no longer writes /tmp/report.md; update this test"

# --- Stub gh: record the commit status the Resolve step would post ---------
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$GH_ARGS"
EOF
chmod +x "$TMP/bin/gh"

# verdict <file> <leg> <verdict> <namespace> <blocking>
verdict() {
  mkdir -p "$(dirname "$1")"
  jq -n --arg leg "$2" --arg v "$3" --arg ns "$4" --argjson b "$5" '{
    verdict: $v, namespace: $ns,
    subject: {leg: $leg, kind: "mirror", trustClass: "dhi"},
    cve_policy: {
      exceptions_applied: [],
      per_platform: {"linux/amd64": {
        counts: {blocking: $b, waived: 0, recorded: 3},
        violations: (if $b > 0 then [{code: "CVE_BLOCKING", message: "a blocking finding"}] else [] end),
        observations: []}}}}' > "$1"
}

# review_case <name>: run Build the report, then Resolve, in $TMP/<name>.
# Sets STATE (the posted commit status) and REPORT (the report file).
review_case() {
  local d="$TMP/$1"
  mkdir -p "$d/tmp"
  : > "$d/output"; : > "$d/summary"
  sed "s#/tmp/#${d}/tmp/#g" "$TMP/review-report.sh" > "$d/report.sh"
  sed "s#/tmp/#${d}/tmp/#g" "$TMP/review-resolve.sh" > "$d/resolve.sh"
  (cd "$d" && GITHUB_OUTPUT="$d/output" GITHUB_STEP_SUMMARY="$d/summary" bash "$d/report.sh") \
    > "$d/report.log" 2>&1 || { cat "$d/report.log" >&2; fail "$1: Build the report exited non-zero"; }
  local overall quarantined
  overall=$(sed -n 's/^overall=//p' "$d/output")
  quarantined=$(sed -n 's/^quarantined=//p' "$d/output")
  (cd "$d" && PATH="$TMP/bin:$PATH" GH_ARGS="$d/gh.args" GH_TOKEN=x REPO=infrashift/test \
     SHA=1111111111111111111111111111111111111111 REVIEW_RESULT=success \
     OVERALL="$overall" QUARANTINED="$quarantined" \
     GITHUB_SERVER_URL=https://github.com GITHUB_RUN_ID=1 bash "$d/resolve.sh") \
    > "$d/resolve.log" 2>&1 || { cat "$d/resolve.log" >&2; fail "$1: Resolve exited non-zero"; }
  STATE=$(sed -n 's/^state=//p' "$d/gh.args")
  grep -qx 'context=review/cve-policy' "$d/gh.args" || fail "$1: no review/cve-policy status posted"
  REPORT="$d/tmp/report.md"
}

rows() { grep -c '^| `' "$1" || true; }

# 1. Zero artifacts: no verdicts/ at all. The check must fail.
review_case zero
[[ "$STATE" == failure ]] || fail "zero: no verdicts gave state '${STATE}', want failure"
grep -q 'No verdicts were produced' "$REPORT" || fail "zero: report does not say no verdicts were produced"

# 1b. verdicts/ exists but holds no verdict (an artifact with no files).
mkdir -p "$TMP/empty/verdicts/review-x"
review_case empty
[[ "$STATE" == failure ]] || fail "empty: an empty download gave state '${STATE}', want failure"

# 2. One artifact: download-artifact unpacks it straight into verdicts/. #63.
verdict "$TMP/one/verdicts/review-verdict.json" ollama-runtime PASS trusted 0
review_case one
[[ "$STATE" == success ]] || fail "one: a single PASS verdict gave state '${STATE}', want success (the #63 bug)"
[[ "$(rows "$REPORT")" -eq 1 ]] || fail "one: expected 1 verdict row, got $(rows "$REPORT")"
grep -q '`ollama-runtime`' "$REPORT" || fail "one: leg missing from the report"

# 2b. One artifact that FAILs is still red.
verdict "$TMP/onefail/verdicts/review-verdict.json" ollama-runtime FAIL quarantine 2
review_case onefail
[[ "$STATE" == failure ]] || fail "onefail: a single FAIL verdict gave state '${STATE}', want failure"

# 2c. One observe leg: green, but the report and description say quarantine.
verdict "$TMP/oneobs/verdicts/review-verdict.json" ollama-runtime PASS quarantine 1
review_case oneobs
[[ "$STATE" == success ]] || fail "oneobs: an observe PASS gave state '${STATE}', want success"
grep -q 'PASS (observe)' "$REPORT" || fail "oneobs: observe PASS is printed bare"
grep -q 'route to quarantine' "$TMP/oneobs/gh.args" || fail "oneobs: status description does not mention quarantine"

# 3. Many artifacts: one directory per artifact.
verdict "$TMP/many/verdicts/review-a-amd64/review-verdict.json" a PASS trusted 0
verdict "$TMP/many/verdicts/review-a-arm64/review-verdict.json" a PASS trusted 0
verdict "$TMP/many/verdicts/review-b/review-verdict.json" b PASS trusted 0
review_case many
[[ "$STATE" == success ]] || fail "many: three PASS verdicts gave state '${STATE}', want success"
[[ "$(rows "$REPORT")" -eq 3 ]] || fail "many: expected 3 verdict rows, got $(rows "$REPORT")"

# 3b. Many artifacts, one FAIL: red.
verdict "$TMP/manyfail/verdicts/review-a/review-verdict.json" a PASS trusted 0
verdict "$TMP/manyfail/verdicts/review-b/review-verdict.json" b FAIL quarantine 1
review_case manyfail
[[ "$STATE" == failure ]] || fail "manyfail: one FAIL among many gave state '${STATE}', want failure"

# 3c. The search is bounded: a verdict nested deeper than an artifact is ignored.
verdict "$TMP/deep/verdicts/review-a/nested/review-verdict.json" a PASS trusted 0
review_case deep
[[ "$STATE" == failure ]] || fail "deep: a verdict below verdicts/<artifact>/ was counted"

# --- release.yml Report -----------------------------------------------------
# result <file> <leg> <namespace>
result() {
  mkdir -p "$(dirname "$1")"
  jq -n --arg leg "$2" --arg ns "$3" \
    '{leg: $leg, arch: "amd64", verdict: "PASS", namespace: $ns, tags: ["t1"], pullRequest: 63}' > "$1"
}
manifest() {
  mkdir -p "$(dirname "$1")"
  jq -n --arg s "$2" '{service: $s, digest: ("sha256:" + ("a" * 64)), tags: ["t1"]}' > "$1"
}
release_case() {
  local d="$TMP/rel-$1"
  mkdir -p "$d"; : > "$d/summary"
  (cd "$d" && GITHUB_STEP_SUMMARY="$d/summary" bash "$TMP/release-report.sh") > "$d/log" 2>&1 \
    || { cat "$d/log" >&2; fail "release $1: Report exited non-zero"; }
  SUMMARY="$d/summary"
}

release_case zero
grep -q 'No images were promoted' "$SUMMARY" || fail "release zero: no 'No images were promoted'"

result "$TMP/rel-one/results/release-result.json" ollama-runtime trusted
manifest "$TMP/rel-one/manifests/manifest-result.json" svc
release_case one
[[ "$(rows "$SUMMARY")" -eq 2 ]] || fail "release one: expected 1 result + 1 manifest row, got $(rows "$SUMMARY") (the single-artifact bug)"
! grep -q 'No images were promoted' "$SUMMARY" || fail "release one: a promoted image was reported as none"

result "$TMP/rel-many/results/release-result-a/release-result.json" a trusted
result "$TMP/rel-many/results/release-result-b/release-result.json" b quarantine
manifest "$TMP/rel-many/manifests/manifest-result-a/manifest-result.json" a
manifest "$TMP/rel-many/manifests/manifest-result-b/manifest-result.json" b
release_case many
[[ "$(rows "$SUMMARY")" -eq 4 ]] || fail "release many: expected 2 result + 2 manifest rows, got $(rows "$SUMMARY")"
grep -q '1 leg(s) landed in `quarantine`' "$SUMMARY" || fail "release many: quarantine count is wrong"

echo "OK: review and release summaries find zero, one and many artifacts; no verdict or a FAIL still fails review/cve-policy"
