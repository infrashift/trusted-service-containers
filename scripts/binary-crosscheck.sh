#!/usr/bin/env bash
# Hash the same binary from two images and print "<ours> <theirs>".
#
# Usage: binary-crosscheck.sh <our-image> <our-path> <their-image> <their-path>
#        binary-crosscheck.sh --ours-only <our-image> <our-path>
#
# --ours-only is for a first-party build (versions.json `firstParty`, ADR-008):
# no vendor binary exists, so it hashes and prints only ours, with the same
# shape assertion. It is never a fallback for a vendor image whose reference
# cannot be read -- build-leg.sh selects it from the declared mode, and the
# policy denies a mode that versions.json does not declare.
#
# Mount, don't run. The vendor's distroless and Dapr reference images have no
# shell and no coreutils, so `buildah run` would fail on the reference side.
# One mechanism works for both sides.
#
# This produces an OBSERVATION, never a gate. Go builds are rarely
# bit-reproducible: the build path (Ory and Dapr omit -trimpath), the toolchain
# patch version, and module resolution state all affect the output. A mismatch
# is the expected result and proves nothing on its own.
set -euo pipefail

OURS_ONLY=false
if [[ "${1:-}" == "--ours-only" ]]; then
  OURS_ONLY=true; shift
  [[ $# -eq 2 ]] || { echo "::error::--ours-only takes exactly <our-image> <our-path>" >&2; exit 2; }
fi
OUR_IMG="${1:?our image}"; OUR_PATH="${2:?our path}"
if [[ "$OURS_ONLY" == false ]]; then
  THEIR_IMG="${3:?their image}"; THEIR_PATH="${4:?their path}"
fi

hash_from_image() {
  local ref="$1" path="$2" ctr mnt out
  ctr=$(buildah from --pull=missing "$ref")
  mnt=$(buildah mount "$ctr")
  if [[ ! -f "${mnt}${path}" ]]; then
    buildah umount "$ctr" >/dev/null; buildah rm "$ctr" >/dev/null
    echo "::error::${path} not found in ${ref}" >&2
    return 1
  fi
  out=$(sha256sum "${mnt}${path}" | awk '{print $1}')
  buildah umount "$ctr" >/dev/null
  buildah rm "$ctr" >/dev/null
  printf '%s' "$out"
}
export -f hash_from_image

# buildah mount needs a user namespace on a rootless runner.
OURS=$(buildah unshare -- bash -c "hash_from_image '$OUR_IMG' '$OUR_PATH'") || true

if [[ "$OURS_ONLY" == true ]]; then
  # The same assertion as below, for the one side there is. Exit 0 with an
  # empty string would record a first-party build with no binary hash.
  if [[ ! "$OURS" =~ ^[0-9a-f]{64}$ ]]; then
    echo "::error::cross-check produced no usable ours hash for ${OUR_IMG}${OUR_PATH} (got ${OURS:-<empty>})" >&2
    exit 1
  fi
  printf '%s\n' "$OURS"
  exit 0
fi

THEIRS=$(buildah unshare -- bash -c "hash_from_image '$THEIR_IMG' '$THEIR_PATH'") || true

# Assert the output shape before emitting it. Without this the script could exit
# 0 having printed two empty strings, and the caller would compare "" == "" and
# record a MATCH -- a false positive on the one field the whole cross-check
# exists to produce. The policy's DUAL_PROVENANCE_MALFORMED rule is the second
# line of defence; this is the first.
for pair in "ours:$OURS:$OUR_IMG$OUR_PATH" "theirs:$THEIRS:$THEIR_IMG$THEIR_PATH"; do
  side="${pair%%:*}"; rest="${pair#*:}"; val="${rest%%:*}"; src="${rest#*:}"
  if [[ ! "$val" =~ ^[0-9a-f]{64}$ ]]; then
    echo "::error::cross-check produced no usable ${side} hash for ${src} (got ${val:-<empty>})" >&2
    exit 1
  fi
done

printf '%s %s\n' "$OURS" "$THEIRS"
