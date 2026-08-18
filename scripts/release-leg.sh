#!/usr/bin/env bash
# Promote one reviewed leg from development/ into trusted/ or quarantine/.
#
# The verdict is read from the SIGNED review attestation on the image, never
# from a workflow artifact: an artifact is mutable by anyone who can re-run a
# job, an attestation is not.
#
# Required env: LEG SERVICE VARIANT KIND [ARCH] PR_NUM HEAD_SHA SHORT_SHA
#               DATE_TAG GITHUB_REPOSITORY COSIGN_PRIVATE_KEY COSIGN_PASSWORD
set -euo pipefail

: "${LEG:?}" "${SERVICE:?}" "${VARIANT:?}" "${KIND:?}" "${PR_NUM:?}" \
  "${HEAD_SHA:?}" "${SHORT_SHA:?}" "${DATE_TAG:?}" "${GITHUB_REPOSITORY:?}"
ARCH="${ARCH:-}"

REVIEW_PUB=.github/pdp/public-keys/review.pub
fail() { echo "::error::$*"; exit 1; }

IMG=$(jq -ce --arg s "$SERVICE" '.images[$s]' versions.json)
DEV_REPO="ghcr.io/${GITHUB_REPOSITORY}/development/${SERVICE}"

if [[ "$KIND" == "mirror" ]]; then
  UPSTREAM_TAG=$(jq -r --arg v "$VARIANT" '.variants[$v].tag' <<<"$IMG")
  DEV_TAG="pr-${PR_NUM}-${UPSTREAM_TAG}"
  BASE_TAG="$UPSTREAM_TAG"
else
  SRC_KEY=$(jq -r '.source' <<<"$IMG")
  VERSION=$(jq -r --arg s "$SRC_KEY" '.sources[$s].ref' versions.json)
  DEV_TAG="pr-${PR_NUM}-${VERSION}-${ARCH}"
  BASE_TAG="$VERSION"
fi

DEV_DIGEST=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${DEV_REPO}:${DEV_TAG}") \
  || fail "cannot resolve ${DEV_REPO}:${DEV_TAG}"

# ===========================================================================
# 1. Verdict, from the signed attestation.
# ===========================================================================
PAYLOAD=$(cosign verify-attestation \
  --key "$REVIEW_PUB" \
  --type https://infrashift.io/attestation/review/v1 \
  --insecure-ignore-tlog \
  --certificate-identity-regexp='.*' --certificate-oidc-issuer-regexp='.*' \
  "${DEV_REPO}@${DEV_DIGEST}" 2>/dev/null) \
  || fail "no verifiable review attestation on ${DEV_REPO}@${DEV_DIGEST}"

# cosign emits one JSON object per attestation; --replace is banned repo-wide so
# reruns accumulate. Take the newest by evaluatedAt rather than assuming one.
PRED=$(jq -s -r '[ .[] | .payload | @base64d | fromjson | .predicate ]
                 | sort_by(.metadata.evaluatedAt) | last' <<<"$PAYLOAD")
[[ -n "$PRED" && "$PRED" != "null" ]] || fail "could not decode the review predicate"

VERDICT=$(jq -r '.verdict' <<<"$PRED")
VERDICT_COMMIT=$(jq -r '.metadata.commitSha' <<<"$PRED")
VERDICT_LEG=$(jq -r '.subject.leg' <<<"$PRED")

# Freshness. A verdict issued against a different commit is a verdict about
# different bits, however recent it looks.
[[ "$VERDICT_COMMIT" == "$HEAD_SHA" ]] \
  || fail "stale review: verdict is for ${VERDICT_COMMIT}, this release is for ${HEAD_SHA}"
[[ "$VERDICT_LEG" == "$LEG" ]] \
  || fail "verdict is for leg ${VERDICT_LEG}, expected ${LEG}"

echo "verdict=${VERDICT} for ${LEG} @ ${DEV_DIGEST}"

# ===========================================================================
# 2. Destination.
#
# Quarantine gets ONLY the commit-suffixed immutable tag. The bare
# upstream-shaped tag exists exclusively under trusted/, so a registry-mirror
# typo or a copy-paste cannot silently resolve to a quarantined image -- using
# one requires naming the exact commit, which is the deliberate act that should
# be required.
# ===========================================================================
if [[ "$VERDICT" == "PASS" ]]; then
  NAMESPACE=trusted
  if [[ "$KIND" == "mirror" ]]; then
    TAGS=("$BASE_TAG" "${BASE_TAG}-${SHORT_SHA}" "${BASE_TAG}-${DATE_TAG}")
  else
    # Per-arch only here; the manifest job assembles the lists after every arch
    # for this service has landed in trusted/.
    TAGS=("${BASE_TAG}-${SHORT_SHA}-${ARCH}")
  fi
else
  NAMESPACE=quarantine
  if [[ "$KIND" == "mirror" ]]; then
    TAGS=("${BASE_TAG}-${SHORT_SHA}")
  else
    TAGS=("${BASE_TAG}-${SHORT_SHA}-${ARCH}")
  fi
fi
DEST_REPO="ghcr.io/${GITHUB_REPOSITORY}/${NAMESPACE}/${SERVICE}"

# ===========================================================================
# 3. Promote. NEVER rebuild.
#
# regctl, not `cosign copy`: cosign copy understands only cosign's own legacy
# sha256-<digest>.sig/.att tags, so it would silently drop the DHI attestations
# that arrived as OCI referrers -- losing the single thing the mirror track
# exists to preserve.
# ===========================================================================
for t in "${TAGS[@]}"; do
  regctl image copy "${DEV_REPO}@${DEV_DIGEST}" "${DEST_REPO}:${t}" \
    --referrers --referrers-src "$DEV_REPO" --referrers-tgt "$DEST_REPO" \
    --digest-tags --force-recursive
  echo "  -> ${DEST_REPO}:${t}"
done

# Third and final assertion of the invariant that defines this repo.
PROMOTED=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${DEST_REPO}:${TAGS[0]}")
[[ "$PROMOTED" == "$DEV_DIGEST" ]] \
  || fail "promotion altered the digest: ${DEV_DIGEST} -> ${PROMOTED}"

# ===========================================================================
# 4. Release attestation, DUAL-SIGNED.
#
# Pass 1 keyed with tlog off: the sovereign signature, which leaks nothing about
# our release cadence to a public log.
# Pass 2 keyless with tlog on: public Sigstore/Rekor transparency, so a third
# party can independently confirm this release happened.
#
# The predicate permanently records what was waived to get here, so a promoted
# image carries its own exception history.
# ===========================================================================
jq -n \
  --arg leg "$LEG" --arg svc "$SERVICE" --arg var "$VARIANT" --arg kind "$KIND" \
  --arg ns "$NAMESPACE" --arg verdict "$VERDICT" \
  --arg repo "$DEST_REPO" --arg dig "$PROMOTED" \
  --arg devrepo "$DEV_REPO" --arg devtag "$DEV_TAG" \
  --arg head "$HEAD_SHA" --arg pr "$PR_NUM" --arg short "$SHORT_SHA" \
  --arg now "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --argjson tags "$(printf '%s\n' "${TAGS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
  --argjson upstream "$(jq -c '.subject | {trustClass}' <<<"$PRED")" \
  --argjson uv "$(jq -c '.checks.upstream_verification // {}' <<<"$PRED")" \
  --argjson waived "$(jq -c '.cve_policy.exceptions_applied // []' <<<"$PRED")" \
  '{ metadata: { timestamp:$now, releaser:"release-actor",
                 pullRequest:$pr, commitSha:$head, shortSha:$short },
     subject: { leg:$leg, service:$svc, variant:$var, kind:$kind,
                namespace:$ns, repository:$repo, digest:$dig, tags:$tags },
     promotion: { from: ($devrepo + ":" + $devtag), rebuilt:false, tool:"regctl",
                  digestPreserved:true,
                  assertion:"promoted.digest == development.digest" },
     upstream: ($upstream + {verification:$uv}),
     cve_policy: { verdict:$verdict, exceptions_applied:$waived },
     verdict: $verdict }' > release-attestation.json

echo "Pass 1: sovereign keyed signature (tlog off)"
cosign attest --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY \
  --type https://infrashift.io/attestation/release/v1 \
  --predicate release-attestation.json "${DEST_REPO}@${PROMOTED}" >/dev/null

echo "Pass 2: keyless OIDC signature (tlog on -> Rekor)"
cosign attest --yes \
  --type https://infrashift.io/attestation/release/v1 \
  --predicate release-attestation.json "${DEST_REPO}@${PROMOTED}" >/dev/null

jq -n --arg leg "$LEG" --arg svc "$SERVICE" --arg kind "$KIND" --arg arch "$ARCH" \
      --arg ns "$NAMESPACE" --arg verdict "$VERDICT" --arg repo "$DEST_REPO" \
      --arg dig "$PROMOTED" --arg pr "$PR_NUM" \
      --argjson tags "$(printf '%s\n' "${TAGS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
  '{leg:$leg, service:$svc, kind:$kind, arch:$arch, namespace:$ns,
    verdict:$verdict, repository:$repo, digest:$dig, tags:$tags, pullRequest:$pr}' \
  > release-result.json

echo "OK: ${LEG} -> ${NAMESPACE} (${VERDICT})"
