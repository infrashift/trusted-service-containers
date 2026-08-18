#!/usr/bin/env bash
# Fail if any .rego file exists outside the single policy directory, or if that
# directory grows a file other than the policy and its tests.
#
# Why this exists: the reference repo (trusted-base-oci-images) accumulated six
# orphaned .rego files under .github/ that nothing evaluated and that
# contradicted the one live policy. Two of them (labels.rego, policy.rego) would
# have denied every image had anything ever run them. A reader could not tell
# which policy was authoritative. One file, one package, enforced mechanically.
set -euo pipefail

ALLOWED=("policies.rego" "policies_test.rego")
POLICY_DIR=".github/pdp"
fail=0

# 1. No .rego anywhere except the policy dir.
while IFS= read -r f; do
  case "$f" in
    "./${POLICY_DIR}/"*) : ;;
    *) echo "error: orphan rego outside ${POLICY_DIR}: ${f#./}" >&2; fail=1 ;;
  esac
done < <(find . -name '*.rego' -not -path './.git/*' -type f)

# 2. Nothing unexpected inside the policy dir.
while IFS= read -r f; do
  base=$(basename "$f")
  ok=0
  for a in "${ALLOWED[@]}"; do [ "$base" = "$a" ] && ok=1; done
  if [ "$ok" -eq 0 ]; then
    echo "error: unexpected rego in ${POLICY_DIR}: ${base}" >&2
    echo "       One file, one package. Add rules to policies.rego instead." >&2
    fail=1
  fi
done < <(find "$POLICY_DIR" -name '*.rego' -type f 2>/dev/null)

# 3. Exactly one package declaration in the policy itself.
pkgs=$(grep -c '^package ' "${POLICY_DIR}/policies.rego" || true)
if [ "$pkgs" -ne 1 ]; then
  echo "error: ${POLICY_DIR}/policies.rego declares ${pkgs} packages; expected exactly 1" >&2
  fail=1
fi
grep -q '^package tsc\.pdp$' "${POLICY_DIR}/policies.rego" || {
  echo "error: policy package must be tsc.pdp" >&2; fail=1; }

[ "$fail" -eq 0 ] && echo "OK: single authoritative policy (${POLICY_DIR}/policies.rego, package tsc.pdp)"
exit "$fail"
