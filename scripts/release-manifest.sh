#!/usr/bin/env bash
# Assemble multi-arch manifest lists for ONE built service.
#
# Build-track only. Mirror legs are excluded structurally, via manifest_matrix,
# not by a condition inside this script: running `buildah manifest create` over
# a mirrored index would replace the vendor's signed index with one they never
# signed, which is the single thing the mirror track exists to prevent.
#
# Runs only when EVERY arch for this service landed in trusted/. A quarantined
# arch must not get a manifest list -- otherwise `:<version>` would silently
# resolve to a partly-quarantined image.
#
# Required env: SERVICE LEG SHORT_SHA DATE_TAG GITHUB_REPOSITORY
#               COSIGN_PRIVATE_KEY COSIGN_PASSWORD
set -euo pipefail

: "${SERVICE:?}" "${LEG:?}" "${SHORT_SHA:?}" "${DATE_TAG:?}" "${GITHUB_REPOSITORY:?}"

IMG=$(jq -ce --arg s "$SERVICE" '.images[$s]' versions.json)
SRC_KEY=$(jq -r '.source' <<<"$IMG")
VERSION=$(jq -r --arg s "$SRC_KEY" '.sources[$s].ref' versions.json)
mapfile -t ARCHES < <(jq -r '.arches[]' <<<"$IMG")

TRUSTED="ghcr.io/${GITHUB_REPOSITORY}/trusted/${SERVICE}"

# Gate: every declared arch must be present in trusted/ before any list is made.
MISSING=()
for a in "${ARCHES[@]}"; do
  if ! regctl manifest head "${TRUSTED}:${VERSION}-${SHORT_SHA}-${a}" >/dev/null 2>&1; then
    MISSING+=("$a")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "::warning::${SERVICE}: arch(es) ${MISSING[*]} did not reach trusted/; skipping manifest lists so :${VERSION} cannot resolve to a partly-quarantined image"
  echo "skipped=true" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

# No :latest, anywhere in this repo. With eleven services and runtime/dev
# variants it has no defensible meaning, and it invites pulling a -dev image
# (root, shell, package manager) into production.
TAGS=("$VERSION" "${VERSION}-${SHORT_SHA}" "${VERSION}-${DATE_TAG}")

for t in "${TAGS[@]}"; do
  buildah manifest rm "${TRUSTED}:${t}" >/dev/null 2>&1 || true
  buildah manifest create "${TRUSTED}:${t}" >/dev/null
  for a in "${ARCHES[@]}"; do
    buildah manifest add "${TRUSTED}:${t}" "docker://${TRUSTED}:${VERSION}-${SHORT_SHA}-${a}" >/dev/null
  done
  buildah manifest push --all "${TRUSTED}:${t}" "docker://${TRUSTED}:${t}" >/dev/null
  echo "  pushed manifest list ${TRUSTED}:${t}"
done

# Read the list digest back FROM THE REGISTRY rather than computing it locally.
# The reference repo does `skopeo inspect --raw | sha256sum`, which re-derives
# the digest from raw bytes and can disagree with what the registry stored.
LIST_DIGEST=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${TRUSTED}:${TAGS[0]}")
LIST_URI="${TRUSTED}@${LIST_DIGEST}"

# Dual-sign the list itself: consumers pin the list, not the per-arch children.
echo "Pass 1: sovereign keyed signature (tlog off)"
cosign sign --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY "$LIST_URI" >/dev/null
echo "Pass 2: keyless OIDC signature (tlog on -> Rekor)"
cosign sign --yes "$LIST_URI" >/dev/null

jq -n --arg svc "$SERVICE" --arg uri "$LIST_URI" --arg dig "$LIST_DIGEST" \
      --argjson tags "$(printf '%s\n' "${TAGS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
      --argjson arches "$(printf '%s\n' "${ARCHES[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
  '{service:$svc, manifestList:$uri, digest:$dig, tags:$tags, arches:$arches}' \
  > "manifest-result.json"

echo "OK: ${SERVICE} manifest lists published (${LIST_DIGEST})"
