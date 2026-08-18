#!/usr/bin/env bash
# Fetch one upstream source tree at a pinned commit into src/<service>/.
#
# Usage: fetch-source.sh <service> <url> <commit-sha> <tag>
set -euo pipefail

SERVICE="${1:?service}"; URL="${2:?url}"; COMMIT="${3:?commit}"; TAG="${4:?tag}"
DEST="src/${SERVICE}"

[[ "$COMMIT" =~ ^[0-9a-f]{40}$ ]] || { echo "::error::commit must be a 40-hex SHA, got: ${COMMIT}"; exit 1; }

rm -rf "$DEST"; mkdir -p "$DEST"
git -C "$DEST" init -q
git -C "$DEST" remote add origin "$URL"

# Fetch the COMMIT, not the tag: a tag is a mutable pointer.
git -C "$DEST" fetch --depth 1 -q origin "$COMMIT"
git -C "$DEST" checkout -q FETCH_HEAD

ACTUAL=$(git -C "$DEST" rev-parse HEAD)
[[ "$ACTUAL" == "$COMMIT" ]] || { echo "::error::checkout mismatch: ${ACTUAL} != ${COMMIT}"; exit 1; }

# Confirm the pinned commit really IS the pinned tag. Catches a stale
# versions.json where someone bumped the ref but not the commit, or vice versa.
# rev-list dereferences annotated tags (Ory and NATS use them; Dapr's are
# lightweight), so this works for both.
if git -C "$DEST" fetch --depth 1 -q origin "refs/tags/${TAG}:refs/tags/${TAG}" 2>/dev/null; then
  TAG_COMMIT=$(git -C "$DEST" rev-list -n1 "refs/tags/${TAG}")
  [[ "$TAG_COMMIT" == "$COMMIT" ]] || {
    echo "::error::${TAG} points at ${TAG_COMMIT} but versions.json pins ${COMMIT}"; exit 1; }
else
  echo "::warning::could not fetch tag ${TAG} for cross-check; proceeding on the commit pin"
fi

# The Ory services vendor github.com/ory/x in-tree at ./oryx via a `replace`
# directive -- NOT a git submodule and NOT a Go workspace (verified: .gitmodules
# and go.work both 404 in all four repos), so a plain shallow checkout is
# complete. Assert rather than trust: a repo can grow a submodule between
# releases, and a silent miscompile is worse than a build failure.
[[ -f "$DEST/.gitmodules" ]] && {
  echo "::error::${URL} now has .gitmodules; the checkout strategy needs revisiting"; exit 1; }

# Capture git-derived build inputs into a SIBLING directory, never inside the
# checkout. Writing them into $DEST leaves untracked files in the worktree, and
# Go then stamps vcs.modified=true -- which differs from the vendor's release
# build and makes a byte-identical cross-check impossible. Verified empirically.
META="src/.meta"
mkdir -p "$META"
git -C "$DEST" show -s --format=%cI "$COMMIT" > "${META}/${SERVICE}.source-date"
(git -C "$DEST" describe --always --abbrev=7 2>/dev/null || echo "$TAG") > "${META}/${SERVICE}.source-git-version"

# .git is KEPT deliberately. Verified empirically with `go version -m`:
#
#   with .git + the tag fetched above -> mod = v2.14.5, and the binary carries
#                                        vcs.revision / vcs.time / vcs.modified
#   without .git                      -> mod = (devel), no vcs provenance at all
#
# The concern that motivates deleting it -- a shallow clone yielding a
# v0.0.0-<ts>-<sha> pseudo-version that sorts below every release and makes
# scanners report already-fixed advisories -- is solved by fetching the TAG
# (above), not by discarding provenance. If that tag fetch ever fails, this
# script warns, and the resulting module version is worth checking.
#
# The metadata files this script writes go to src/.meta/, NOT into the
# worktree: untracked files there make Go stamp vcs.modified=true, which
# diverges from the vendor's release build.

echo "fetched ${SERVICE} @ ${COMMIT} (${TAG}), source-date=$(cat "${META}/${SERVICE}.source-date")"
