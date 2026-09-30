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
# release-tarball hashes into a v2.14.7 proposal.
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
SHA40="$(printf 'd%.0s' {1..40})"

mkdir -p "$TMP/bin" "$TMP/work"

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

# git: ls-remote only. Each source repo has one release past its pin.
cat > "$TMP/bin/git" <<EOF
#!/usr/bin/env bash
[[ "\$1" == "ls-remote" ]] || exit 1
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
    "nats": { "url": "https://example.invalid/nats", "track": "^v2\\\\.14\\\\.[0-9]+\$", "ref": "v2.14.5", "commit": "$SHA40" },
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

# --- dapr: not moved, and SAID so, per platform -----------------------------
[[ "$(xc daprd amd64 tag)" == "1.18.3-linux-amd64" ]] || fail "daprd crosscheck tag changed unexpectedly"
grep -q 'daprd` crosscheck amd64: tag `1.18.3-linux-amd64` does not embed' "$TMP/report.md" \
  || fail "no alarm for the daprd amd64 crosscheck left behind by the source bump"
grep -q 'daprd` crosscheck arm64' "$TMP/report.md" \
  || fail "no alarm for the daprd arm64 crosscheck left behind by the source bump"

# --- NATS release-tarball hashes: flagged, not silently carried ------------
grep -q 'nats`: `crosscheck.releaseTarballSha256` still holds the `v2.14.5`' "$TMP/report.md" \
  || fail "no alarm for the stale nats releaseTarballSha256"

echo "OK: drift-upstream.sh pins crosschecks per platform and flags what it cannot move"
