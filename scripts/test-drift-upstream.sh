#!/usr/bin/env bash
# Run scripts/drift-upstream.sh's build-track bump against a fixture
# versions.json, with stub `regctl` and `git` standing in for the registries
# and the source repositories.
#
# Why this exists: the first drift proposal that ever reached a branch
# (2026-09-30) re-pointed the NATS crosscheck to 2.14.7 and wrote the tag's
# INDEX digest into both the amd64 and the arm64 slot -- `regctl manifest
# head` without --platform on a multi-arch tag. The policy requires a
# crosscheck pinned per platform, but only checks the digest's shape, so it
# would have merged. The same run left dapr's crosscheck on 1.18.3 while the
# source moved to v1.18.4, without a word, and carried the v2.14.5 NATS
# release-tarball hashes into a v2.14.7 proposal. And its shortCommit was one
# character short: computed in a blobless clone, which sees fewer objects than
# the full checkout goreleaser abbreviates in.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${HERE}/drift-upstream.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "error: test-drift-upstream: $*" >&2; exit 1; }

INDEX="sha256:$(printf 'i%.0s' {1..64} | tr i 1)"
AMD64="sha256:$(printf 'a%.0s' {1..64})"
ARM64="sha256:$(printf 'b%.0s' {1..64})"
OLD="sha256:$(printf 'c%.0s' {1..64})"
REAL_GIT="$(command -v git)"

mkdir -p "$TMP/bin" "$TMP/work"

# --- A real nats source repository where the clone kind decides the answer --
# git's automatic abbreviation grows with the object count it can see: 7 hex
# below 2^14 objects, 8 from 2^14. One commit over 16500 files puts a FULL
# clone at 8 while a blobless clone -- one commit, one tree -- stays at 7.
"$REAL_GIT" init -q --bare "$TMP/nats.git"
"$REAL_GIT" -C "$TMP/nats.git" config uploadpack.allowFilter true
{
  for i in $(seq 1 16500); do printf 'blob\nmark :%d\ndata %d\n%d\n' "$i" "$(( ${#i} + 1 ))" "$i"; done
  printf 'commit refs/heads/main\ncommitter t <t@example.invalid> 1800000000 +0000\ndata 2\nv\n'
  for i in $(seq 1 16500); do printf 'M 100644 :%d f%d\n' "$i" "$i"; done
} | "$REAL_GIT" -C "$TMP/nats.git" fast-import --quiet
SHA40="$("$REAL_GIT" -C "$TMP/nats.git" rev-parse refs/heads/main)"
FULL_SHORT="$("$REAL_GIT" -C "$TMP/nats.git" rev-parse --short "$SHA40")"
"$REAL_GIT" clone -q --bare --filter=blob:none "file://$TMP/nats.git" "$TMP/blobless.git" 2>/dev/null
BLOBLESS_SHORT="$("$REAL_GIT" -C "$TMP/blobless.git" rev-parse --short "$SHA40")"
[[ ${#FULL_SHORT} -eq 8 && ${#BLOBLESS_SHORT} -eq 7 ]] \
  || fail "fixture does not discriminate: full=${FULL_SHORT} blobless=${BLOBLESS_SHORT}"

# regctl: a multi-arch index for every tag. `manifest head` answers the index
# digest unless --platform names a child -- which is how the real one behaves
# on nats:2.14.x-alpine3.22.
cat > "$TMP/bin/regctl" <<EOF
#!/usr/bin/env bash
[[ "\$1 \$2" == "manifest head" ]] || exit 1
case " \$* " in
  *" --platform linux/amd64 "*) echo "$AMD64" ;;
  *" --platform linux/arm64 "*) echo "$ARM64" ;;
  *) echo "$INDEX" ;;
esac
EOF

# git: ls-remote is faked -- each source repo has one release past its pin,
# at the fixture commit. Everything else (clone, rev-parse) is real git.
cat > "$TMP/bin/git" <<EOF
#!/usr/bin/env bash
[[ "\$1" == "ls-remote" ]] || exec "$REAL_GIT" "\$@"
case "\$*" in
  *"--tags --refs"*nats*) printf '%s\trefs/tags/v2.14.5\n%s\trefs/tags/v2.14.7\n' "$SHA40" "$SHA40" ;;
  *"--tags --refs"*dapr*) printf '%s\trefs/tags/v1.18.4\n' "$SHA40" ;;
  *"refs/tags/"*) printf '%s\trefs/tags/x\n' "$SHA40" ;;
esac
EOF
chmod +x "$TMP/bin/regctl" "$TMP/bin/git"

cat > "$TMP/work/versions.json" <<EOF
{
  "sources": {
    "nats": { "url": "file://$TMP/nats.git", "track": "^v2\\\\.14\\\\.[0-9]+\$", "ref": "v2.14.5", "commit": "$SHA40", "shortCommit": "0000000",
      "assets": { "ui": { "url": "https://example.invalid/releases/download/v2.14.5/ui-2.14.5.tar.gz", "sha256": "$(printf 'f%.0s' {1..64})" } } },
    "dapr": { "url": "https://example.invalid/dapr", "track": "^v1\\\\.18\\\\.[0-9]+\$", "ref": "v1.18.4-pre.233f2b49", "commit": "$SHA40" }
  },
  "images": {
    "nats": { "kind": "build", "source": "nats", "crosscheck": {
      "image": "docker.io/library/nats",
      "amd64": { "tag": "2.14.5-alpine3.22", "digest": "$OLD" },
      "arm64": { "tag": "2.14.5-alpine3.22", "digest": "$OLD" },
      "releaseTarballSha256": { "amd64": "$(printf 'e%.0s' {1..64})" } } },
    "daprd": { "kind": "build", "source": "dapr", "crosscheck": {
      "image": "docker.io/daprio/daprd",
      "amd64": { "tag": "1.18.3-linux-amd64", "digest": "$OLD" },
      "arm64": { "tag": "1.18.3-linux-arm64", "digest": "$OLD" } } }
  }
}
EOF

( cd "$TMP/work" && PATH="$TMP/bin:$PATH" DRIFT_REPORT="$TMP/report.md" GITHUB_OUTPUT=/dev/null \
    "$SCRIPT" > "$TMP/out.log" 2>&1 ) \
  || { cat "$TMP/out.log" >&2; fail "drift-upstream.sh exited non-zero"; }

V="$TMP/work/versions.json"
xc() { jq -r --arg s "$1" --arg a "$2" --arg f "$3" '.images[$s].crosscheck[$a][$f]' "$V"; }

# --- NATS: moved, and pinned per platform, never by index ------------------
[[ "$(xc nats amd64 tag)" == "2.14.7-alpine3.22" ]] || fail "nats amd64 crosscheck tag not moved: $(xc nats amd64 tag)"
[[ "$(xc nats amd64 digest)" == "$AMD64" ]] || fail "nats amd64 crosscheck pinned $(xc nats amd64 digest), want the linux/amd64 child"
[[ "$(xc nats arm64 digest)" == "$ARM64" ]] || fail "nats arm64 crosscheck pinned $(xc nats arm64 digest), want the linux/arm64 child"

# --- shortCommit: the full-clone abbreviation, never the blobless one ------
got=$(jq -r '.sources.nats.shortCommit' "$V")
[[ "$got" == "$FULL_SHORT" ]] \
  || fail "nats shortCommit is ${got}; the full clone abbreviates to ${FULL_SHORT} (blobless: ${BLOBLESS_SHORT})"

# --- dapr: not moved, and SAID so, per platform -----------------------------
[[ "$(xc daprd amd64 tag)" == "1.18.3-linux-amd64" ]] || fail "daprd crosscheck tag changed unexpectedly"
grep -q 'daprd` crosscheck amd64: tag `1.18.3-linux-amd64` does not embed' "$TMP/report.md" \
  || fail "no alarm for the daprd amd64 crosscheck left behind by the source bump"
grep -q 'daprd` crosscheck arm64' "$TMP/report.md" \
  || fail "no alarm for the daprd arm64 crosscheck left behind by the source bump"

# --- NATS release-tarball hashes: flagged, not silently carried ------------
grep -q 'nats`: `crosscheck.releaseTarballSha256` still holds the `v2.14.5`' "$TMP/report.md" \
  || fail "no alarm for the stale nats releaseTarballSha256"

# --- Release assets: URL follows the release, hash is flagged not carried ---
# A URL left on the old release would embed the old UI in the new binary, and
# its old hash would still match. Both forms of the version must move.
got=$(jq -r '.sources.nats.assets.ui.url' "$V")
[[ "$got" == "https://example.invalid/releases/download/v2.14.7/ui-2.14.7.tar.gz" ]] \
  || fail "nats asset url not moved to the new release: ${got}"
[[ "$(jq -r '.sources.nats.assets.ui.sha256' "$V")" == "$(printf 'f%.0s' {1..64})" ]] \
  || fail "nats asset sha256 changed; drift has no trusted source for it and must leave it to fail closed"
grep -q 'source `nats` asset `ui`: url moved to `v2.14.7`, but `sha256` still holds the `v2.14.5` hash' "$TMP/report.md" \
  || fail "no alarm for the nats asset sha256 left on the old release"

echo "OK: drift-upstream.sh pins crosschecks per platform, abbreviates in a full clone, moves asset URLs, and flags what it cannot move"
