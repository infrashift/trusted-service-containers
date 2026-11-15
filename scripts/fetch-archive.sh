#!/usr/bin/env bash
# Native build (ADR-010): fetch the vendor's release archive of one source,
# verify its pinned sha256, and prove that its file tree equals the tree of the
# pinned commit that scripts/fetch-source.sh checked out into src/<service>/.
#
# Usage: fetch-archive.sh <service> <source-key>
#
# Prints one JSON object on success:
#   { "url": ..., "sha256": ..., "tree_match": true, "files": <count> }
#
# Why both: the commit is what we build, and a commit is immutable, but a
# commit SHA alone says nothing about whether it is the release the vendor
# shipped. The vendor publishes the archive's sha256 in a second place
# (Valkey: valkey-io/valkey-hashes). When the archive matches that hash AND its
# tree matches the commit, the commit is the release. Neither check alone says
# that: the hash proves the archive, the tree comparison ties it to the commit.
#
# Exits non-zero on any mismatch. Never prints tree_match:false -- a failed
# comparison stops the build, and the policy denies an absent value
# (NATIVE_ARCHIVE_TREE_MISMATCH).
set -euo pipefail
SERVICE="${1:?service}"; SRC_KEY="${2:?source key}"
VERSIONS="${VERSIONS:-versions.json}"
fail() { echo "::error::fetch-archive.sh: $*" >&2; exit 1; }

REF=$(jq -r --arg s "$SRC_KEY" '.sources[$s].ref // ""' "$VERSIONS")
URL=$(jq -r --arg s "$SRC_KEY" '.sources[$s].archive.url // ""' "$VERSIONS")
SUM=$(jq -r --arg s "$SRC_KEY" '.sources[$s].archive.sha256 // ""' "$VERSIONS")
[[ -n "$REF" ]]                        || fail "sources.${SRC_KEY}.ref unresolved"
[[ "$URL" =~ ^https://[^[:space:]]+$ ]] || fail "sources.${SRC_KEY}.archive.url is not an https URL: '${URL}'"
[[ "$SUM" =~ ^[a-f0-9]{64}$ ]]         || fail "sources.${SRC_KEY}.archive.sha256 is malformed: '${SUM}'"
# The archive must be the release being built. A bump that moved ref and
# commit but not this URL would otherwise compare the new commit with the old
# archive -- and the old hash would still match the old file.
[[ "$URL" == *"/${REF}."* || "$URL" == *"/${REF}/"* ]] || fail "archive url does not name release ${REF}: ${URL}"

TREE="src/${SERVICE}"
[[ -d "$TREE" ]] || fail "${TREE} does not exist; run scripts/fetch-source.sh first"

DEST="src/.archive/${SERVICE}"
rm -rf "$DEST"; mkdir -p "$DEST/x"
OUT="${DEST}/archive"
curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$OUT" "$URL" || fail "download failed: ${URL}"
echo "${SUM}  ${OUT}" | sha256sum -c --quiet - >/dev/null 2>&1 || {
  got=$(sha256sum "$OUT" | cut -d' ' -f1); rm -f "$OUT"
  fail "sha256 mismatch for ${URL}: got ${got}, versions.json pins ${SUM}"; }

case "$URL" in
  *.tar.gz|*.tgz) tar -xzf "$OUT" -C "$DEST/x" ;;
  *.tar.xz)       tar -xJf "$OUT" -C "$DEST/x" ;;
  *) fail "unsupported archive type: ${URL}" ;;
esac
# A release archive has exactly one top-level directory.
mapfile -t TOP < <(find "$DEST/x" -mindepth 1 -maxdepth 1)
[[ ${#TOP[@]} -eq 1 && -d "${TOP[0]}" ]] || fail "the archive does not have exactly one top-level directory"

# Every file, every symlink target and every mode bit diff -r sees. .git is the
# only thing the checkout has that an archive cannot.
diff -r --no-dereference --exclude=.git "$TREE" "${TOP[0]}" > "${DEST}/diff.txt" 2>&1 || {
  head -20 "${DEST}/diff.txt" >&2
  fail "the file tree of ${URL} differs from the pinned commit in ${TREE}"; }
FILES=$(find "${TOP[0]}" -type f | wc -l)
[[ "$FILES" -gt 0 ]] || fail "the archive holds no files"
rm -rf "$DEST/x"

jq -n --arg url "$URL" --arg sha "$SUM" --argjson n "$FILES" \
  '{url: $url, sha256: $sha, tree_match: true, files: $n}'
