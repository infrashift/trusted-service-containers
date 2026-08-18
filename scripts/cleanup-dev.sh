#!/usr/bin/env bash
# Delete the development-namespace image versions for one PR.
#
# Scoped deliberately narrowly:
#   * development/ ONLY. trusted/ and quarantine/ hold signed, referenced
#     artifacts; quarantine especially is a documented state carrying full
#     evidence, not a wastebasket.
#   * Individual package VERSIONS matching this PR's tag prefix, never whole
#     packages. The reference repo deletes the entire package, which also
#     destroys every other PR's in-flight versions.
#
# Required env: PR_NUM GITHUB_REPOSITORY GH_TOKEN
set -euo pipefail

: "${PR_NUM:?}" "${GITHUB_REPOSITORY:?}"

# The reference resolved the PR number by reading `.version` out of a release
# result -- which is a distro key, not a PR number, so its cleanup silently
# matched nothing. Ours comes from an explicit `pullRequest` field, and we
# assert its shape before it reaches an API path.
[[ "$PR_NUM" =~ ^[0-9]+$ ]] || { echo "::error::PR_NUM '${PR_NUM}' is not numeric"; exit 1; }

ORG="${GITHUB_REPOSITORY%%/*}"
REPO="${GITHUB_REPOSITORY##*/}"
PREFIX="pr-${PR_NUM}-"

mapfile -t SERVICES < <(jq -r '.images | keys[]' versions.json)
echo "cleaning development/* versions tagged ${PREFIX}* across ${#SERVICES[@]} package(s)"

TOTAL_DELETED=0
TOTAL_KEPT=0

for svc in "${SERVICES[@]}"; do
  PKG="${REPO}%2Fdevelopment%2F${svc}"

  if ! gh api "orgs/${ORG}/packages/container/${PKG}" --jq '.name' >/dev/null 2>&1; then
    continue   # nothing published for this service yet
  fi

  # Collect version ids whose tag list contains at least one tag with our
  # prefix. A version can carry several tags; we only delete when every tag on
  # it belongs to this PR, so a version shared with another PR is never removed.
  VERSIONS=$(gh api --paginate "orgs/${ORG}/packages/container/${PKG}/versions" 2>/dev/null || echo '[]')

  # Every tag on the version belongs to this PR -> safe to delete.
  MATCHED=$(jq -c --arg p "$PREFIX" '
      [ .[] | . as $v
        | (($v.metadata.container.tags) // []) as $tags
        | select(($tags | length) > 0)
        | select($tags | all(startswith($p)))
        | {id: $v.id, tags: $tags} ]' <<<"$VERSIONS")

  # Carries one of our tags AND something else -> report, never touch. A version
  # shared with another PR or with a promoted tag must survive.
  SHARED=$(jq -c --arg p "$PREFIX" '
      [ .[] | . as $v
        | (($v.metadata.container.tags) // []) as $tags
        | select($tags | any(startswith($p)))
        | select($tags | all(startswith($p)) | not)
        | {id: $v.id, tags: $tags} ]' <<<"$VERSIONS")

  n=$(jq 'length' <<<"$MATCHED")
  s=$(jq 'length' <<<"$SHARED")
  [[ "$n" -eq 0 && "$s" -eq 0 ]] && continue

  echo "  ${svc}: ${n} version(s) to delete, ${s} shared with other tags"
  while read -r id tags; do
    [[ -z "$id" ]] && continue
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "    would delete ${id} (${tags})"
    else
      printf '    deleting %s (%s)... ' "$id" "$tags"
      gh api -X DELETE "orgs/${ORG}/packages/container/${PKG}/versions/${id}" >/dev/null 2>&1 \
        && echo "deleted" || echo "failed (may already be gone)"
    fi
    TOTAL_DELETED=$((TOTAL_DELETED + 1))
  done < <(jq -r '.[] | "\(.id) \(.tags | join(","))"' <<<"$MATCHED")

  while read -r id tags; do
    [[ -z "$id" ]] && continue
    echo "    keeping ${id} (${tags}) -- shared with tags outside this PR"
    TOTAL_KEPT=$((TOTAL_KEPT + 1))
  done < <(jq -r '.[] | "\(.id) \(.tags | join(","))"' <<<"$SHARED")
done

echo "deleted ${TOTAL_DELETED} version(s), kept ${TOTAL_KEPT} shared version(s)"
