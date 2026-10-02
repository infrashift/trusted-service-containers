#!/usr/bin/env bash
# Fetch the pinned release assets of one source into src/.assets/<service>/.
#
# Usage: fetch-assets.sh <service> <source-key>
#
# An asset is a vendor-published file the build needs but cannot produce from
# the source checkout with our toolchain. The one case today is Prometheus's web
# UI: a source build without Node ships no UI, and upstream publishes the
# compiled UI as prometheus-web-ui-<version>.tar.gz precisely so packagers can
# embed it (its Makefile honours PREBUILT_ASSETS_STATIC_DIR). The binary is
# still compiled from the pinned commit; only these files are taken prebuilt.
#
# The pin is a sha256, and that is the whole trust claim: Prometheus does not
# sign its release assets, so the hash a reviewer copied from the vendor's
# sha256sums.txt is what makes a swapped file fail here instead of shipping.
#
# Written OUTSIDE src/<service>/: untracked files in the worktree make Go stamp
# vcs.modified=true (see fetch-source.sh).
set -euo pipefail

SERVICE="${1:?service}"; SRC_KEY="${2:?source key}"
VERSIONS="${VERSIONS:-versions.json}"
DEST="src/.assets/${SERVICE}"

REF=$(jq -r --arg s "$SRC_KEY" '.sources[$s].ref' "$VERSIONS")
[[ -n "$REF" && "$REF" != "null" ]] || { echo "::error::sources.${SRC_KEY}.ref unresolved"; exit 1; }

rm -rf "$DEST"; mkdir -p "$DEST"

n=0
while read -r name; do
  url=$(jq -r --arg s "$SRC_KEY" --arg n "$name" '.sources[$s].assets[$n].url'    "$VERSIONS")
  sum=$(jq -r --arg s "$SRC_KEY" --arg n "$name" '.sources[$s].assets[$n].sha256' "$VERSIONS")

  [[ "$sum" =~ ^[a-f0-9]{64}$ ]] || { echo "::error::asset ${SRC_KEY}/${name}: malformed sha256"; exit 1; }
  [[ "$url" == https://* ]]       || { echo "::error::asset ${SRC_KEY}/${name}: url must be https"; exit 1; }

  # The asset must belong to the release being built. A drift bump that moved
  # ref/commit but not this URL would otherwise embed the OLD release's UI in
  # the NEW binary -- and the stale hash would still match the stale file, so
  # the checksum alone cannot catch it.
  [[ "$url" == *"/${REF}/"* ]] || {
    echo "::error::asset ${SRC_KEY}/${name}: url does not name release ${REF}: ${url}"; exit 1; }

  out="${DEST}/${name}"
  curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$out" "$url"
  echo "${sum}  ${out}" | sha256sum -c --quiet - || {
    rm -f "$out"
    echo "::error::asset ${SRC_KEY}/${name}: sha256 mismatch for ${url}"; exit 1; }
  echo "fetched asset ${SRC_KEY}/${name} (${REF}) sha256=${sum:0:12}"
  n=$((n + 1))
done < <(jq -r --arg s "$SRC_KEY" '.sources[$s].assets // {} | keys[]' "$VERSIONS")

echo "${n} asset(s) for ${SERVICE}"
