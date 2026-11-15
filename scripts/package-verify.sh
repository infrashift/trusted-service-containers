#!/usr/bin/env bash
# Build actor, package track: ask the rpm database INSIDE a built image what is
# installed, and print it as JSON.
#
# Usage: package-verify.sh <image> <nevra>...
#
#   { "verified_nevras": [ every pinned NEVRA that `rpm -q` found at exactly
#                          that NEVRA ],
#     "missing":         [ every pinned NEVRA it did not ],
#     "signatures":      [ { "nevra": ..., "key_id": <16 hex, or "none"> }
#                          for EVERY installed package except gpg-pubkey ] }
#
# Run, don't mount: the rpm database is read by the image's own rpm, so the
# answer does not depend on the runner's rpm version or database backend. The
# image is ours and has rpm (ubi9-minimal), unlike the vendor images that
# binary-crosscheck.sh has to mount.
#
# Exits non-zero if rpm cannot be run at all. A pinned NEVRA that is absent is
# NOT an error here: it is reported in `missing`, scripts/build-leg.sh fails on
# it, and the policy (PACKAGE_NEVRA_NOT_VERIFIED) denies it again at review.
set -euo pipefail

IMAGE="${1:?image}"; shift
[[ $# -gt 0 ]] || { echo "::error::package-verify.sh: no NEVRA to verify" >&2; exit 1; }

CTR=$(buildah from --pull=missing "$IMAGE")
trap 'buildah rm "$CTR" >/dev/null 2>&1 || true' EXIT

# One query per NEVRA. `rpm -q NEVRA` succeeds for exactly that NEVRA; the
# --qf output is compared again here, so an rpm that matched loosely (an epoch,
# an arch) still does not count.
VERIFIED='[]'; MISSING='[]'
for n in "$@"; do
  got=$(buildah run "$CTR" -- rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$n" 2>/dev/null || true)
  if [[ "$got" == "$n" ]]; then
    VERIFIED=$(jq -c --arg n "$n" '. + [$n]' <<<"$VERIFIED")
  else
    MISSING=$(jq -c --arg n "$n" '. + [$n]' <<<"$MISSING")
  fi
done

# Every package and the key ID of its header signature. `%{RSAHEADER:pgpsig}`
# prints "RSA/SHA256, <date>, Key ID 40bca2b408b40d20", or "(none)".
# gpg-pubkey entries are the imported keys themselves, not packages.
RAW=$(buildah run "$CTR" -- rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\t%{RSAHEADER:pgpsig}\n')
[[ -n "$RAW" ]] || { echo "::error::package-verify.sh: rpm -qa returned nothing for ${IMAGE}" >&2; exit 1; }
SIGS=$(jq -R -s -c '
  split("\n") | map(select(length > 0) | split("\t"))
  | map(select(.[0] | startswith("gpg-pubkey-") | not))
  | map({ nevra: .[0],
          key_id: ((.[1] // "") | (capture("Key ID (?<k>[0-9a-fA-F]{16})$").k // "none") | ascii_downcase) })
  | sort_by(.nevra)' <<<"$RAW")

jq -n --argjson v "$VERIFIED" --argjson m "$MISSING" --argjson s "$SIGS" \
  '{verified_nevras: $v, missing: $m, signatures: $s}'
