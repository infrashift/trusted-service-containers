#!/usr/bin/env bash
# Evaluate data.tsc.pdp.repo_decision against the current working tree.
#
# Builds the OPA input from MEASURED facts -- the real gitleaks config size, the
# real scan output, the real versions.json -- never from asserted literals. The
# reference repo wrote "gitleaks_passed": true into a signed attestation as a
# hardcoded string in a shell heredoc while its config was 0 bytes.
set -euo pipefail

OPA="${OPA:-opa}"
GITLEAKS="${GITLEAKS:-gitleaks}"
POLICY_DIR=".github/pdp"
OUT="${1:-repo-decision.json}"

# evaluated_at is supplied by the caller, never read inside the policy, so a
# decision made now replays identically later.
EVALUATED_AT="${EVALUATED_AT:-$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"

CONFIG_BYTES=$(stat -c%s .gitleaks.toml)
if grep -qE 'useDefault[[:space:]]*=[[:space:]]*true' .gitleaks.toml; then
  USES_DEFAULT=true
else
  USES_DEFAULT=false
fi

# The tool reports; the PDP decides. --exit-code 0 keeps a single decision point
# instead of two that can disagree.
GITLEAKS_STATUS="ran"
if command -v "$GITLEAKS" >/dev/null 2>&1; then
  "$GITLEAKS" detect --config .gitleaks.toml --redact --no-banner \
    --report-format json --report-path /tmp/gitleaks.json --exit-code 0 >/dev/null 2>&1 \
    || GITLEAKS_STATUS="error"
  [ -f /tmp/gitleaks.json ] || echo '[]' > /tmp/gitleaks.json
else
  echo "warning: gitleaks not installed; reporting status=not-installed (the policy will deny)" >&2
  GITLEAKS_STATUS="not-installed"
  echo '[]' > /tmp/gitleaks.json
fi

jq -n \
  --arg now "$EVALUATED_AT" \
  --arg status "$GITLEAKS_STATUS" \
  --argjson bytes "$CONFIG_BYTES" \
  --argjson usesdef "$USES_DEFAULT" \
  --slurpfile leaks /tmp/gitleaks.json \
  --slurpfile versions versions.json \
  '{ evaluated_at: $now,
     gitleaks: { status: $status, findings: $leaks[0], config_bytes: $bytes, uses_default_ruleset: $usesdef },
     versions: $versions[0] }' > /tmp/repo-input.json

"$OPA" eval \
  --data "${POLICY_DIR}/policies.rego" \
  --data "${POLICY_DIR}/exceptions.yaml" \
  --input /tmp/repo-input.json \
  --format json 'data.tsc.pdp.repo_decision' \
| jq -e '.result[0].expressions[0].value' > "$OUT"

# jq -e exits non-zero on null/false, so a policy that failed to load or a rule
# that came back undefined is a hard failure, never a silent pass.
ALLOW=$(jq -r '.allow' "$OUT")
jq -r '.violations[]? | "  X \(.code): \(.message)"' "$OUT"
jq -r '.warnings[]?   | "  ! \(.code): \(.message)"' "$OUT"

if [ "$ALLOW" = "true" ]; then
  echo "OK: repo gate passed"
else
  echo "FAIL: repo gate denied ($(jq -r '.counts.violations' "$OUT") violation(s))" >&2
  exit 1
fi
