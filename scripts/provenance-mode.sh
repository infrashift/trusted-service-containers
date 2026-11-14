#!/usr/bin/env bash
# Resolve and validate the provenance mode of one build entry in versions.json.
#
# Usage: provenance-mode.sh <service> [versions.json]
#
# Prints one JSON object on stdout:
#   {"mode":"vendor-crosscheck"}
#   {"mode":"first-party","reason":"<reason>","sourceUrl":"<url>"}
#
# Exits non-zero with an ::error:: when the entry declares NEITHER mode, BOTH
# modes, a malformed `firstParty`, or `firstParty` on a source outside
# https://github.com/infrashift/ (ADR-008).
#
# A missing `crosscheck` is never read as first-party. The only route to the
# first-party mode is an explicit `firstParty: {noVendorBinary: true, reason}`.
#
# build-leg.sh calls this so a leg the policy would deny fails BEFORE it builds
# and pushes anything. It is not the decision. The review actor re-derives the
# same facts from the checked-out versions.json and the PDP decides
# (PROVENANCE_MODE_MISMATCH and the FIRST_PARTY_* rules); the repo gate
# decides at PR time (VERSIONS_FIRST_PARTY_*). Keep the URL pattern and the
# reason length here in step with first_party_source_pattern and
# min_first_party_reason_chars in .github/pdp/policies.rego;
# scripts/test-provenance-mode.sh holds both to the same cases.
set -euo pipefail

SERVICE="${1:?service}"
VERSIONS="${2:-versions.json}"

fail() { echo "::error::provenance-mode: ${SERVICE}: $*" >&2; exit 1; }

FIRST_PARTY_URL_RE='^https://github\.com/infrashift/[A-Za-z0-9][A-Za-z0-9._-]*$'
MIN_REASON_CHARS=40

IMG=$(jq -ce --arg s "$SERVICE" '.images[$s] | select(type == "object")' "$VERSIONS") \
  || fail "no image entry in ${VERSIONS}"
[[ "$(jq -r '.kind' <<<"$IMG")" == "build" ]] || fail "not a build entry"

HAS_XC=$(jq -r 'has("crosscheck")' <<<"$IMG")
HAS_FP=$(jq -r 'has("firstParty")' <<<"$IMG")

case "${HAS_XC}/${HAS_FP}" in
  true/false)
    jq -cn '{mode: "vendor-crosscheck"}'
    exit 0 ;;
  false/false)
    fail "declares neither crosscheck nor firstParty. A missing crosscheck is not a first-party claim." ;;
  true/true)
    fail "declares both crosscheck and firstParty. A vendor binary either exists or it does not." ;;
  false/true) ;;
  *) fail "could not read the provenance mode (${HAS_XC}/${HAS_FP})" ;;
esac

# --- first-party: every condition, or nothing --------------------------------
[[ "$(jq -r '.firstParty | if type == "object" and .noVendorBinary == true then "yes" else "no" end' <<<"$IMG")" == "yes" ]] \
  || fail "firstParty.noVendorBinary is not the boolean true"

REASON_LEN=$(jq -r '.firstParty.reason | if type == "string" then (gsub("^\\s+|\\s+$"; "") | length) else 0 end' <<<"$IMG")
[[ "$REASON_LEN" -ge "$MIN_REASON_CHARS" ]] \
  || fail "firstParty.reason has ${REASON_LEN} characters; at least ${MIN_REASON_CHARS} are required"
REASON=$(jq -r '.firstParty.reason' <<<"$IMG")

SRC_KEY=$(jq -r '.source // ""' <<<"$IMG")
REPO_KEY=$(jq -r '.repo // ""' <<<"$IMG")
if [[ -n "$REPO_KEY" ]]; then
  URL=$(jq -r --arg s "$SRC_KEY" --arg r "$REPO_KEY" '.sources[$s].repos[$r].url // ""' "$VERSIONS")
else
  URL=$(jq -r --arg s "$SRC_KEY" '.sources[$s].url // ""' "$VERSIONS")
fi
[[ "$URL" =~ $FIRST_PARTY_URL_RE ]] \
  || fail "declares firstParty but its source '${URL:-<none>}' is not a repository under https://github.com/infrashift/"

jq -cn --arg r "$REASON" --arg u "$URL" '{mode: "first-party", reason: $r, sourceUrl: $u}'
