#!/usr/bin/env bash
# Review actor, native python (ADR-010): re-derive the Python facts LIVE from
# the image in the registry, and print them as JSON. Nothing here reads the
# build actor's evidence.
#
# Usage: native-python-observe.sh <image-ref> <venv>
#
#   <image-ref>  a registry reference (ghcr.io/...@sha256:...), or
#                ocidir://<path>:<tag> for a local test
#   <venv>       the venv (versions.json native.venv); the Containerfile puts
#                the lock at <venv>/requirements.txt
#
#   { "lock_sha256":             sha256 of <venv>/requirements.txt in the image,
#     "installed_distributions": every Python distribution under the venv
#                                (syft), as sorted, normalised "name==version" }
#
# A value that cannot be read is printed as "" or [] -- never invented -- and
# the policy denies on it. Exits non-zero only when a tool cannot run at all.
set -euo pipefail
REF="${1:?image ref}"; VENV="${2:?venv}"
[[ "$VENV" =~ ^/opt/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "::error::native-python-observe.sh: bad venv ${VENV}" >&2; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
regctl image get-file "$REF" "${VENV}/requirements.txt" "$TMP/lock" 2>/dev/null || : > "$TMP/lock"
LOCK_SHA=""
[[ -s "$TMP/lock" ]] && LOCK_SHA=$(sha256sum "$TMP/lock" | cut -d' ' -f1)

case "$REF" in
  ocidir://*) SYFT_SRC="oci-dir:$(sed -E 's|^ocidir://||; s|:[^/:]*$||' <<<"$REF")" ;;
  *)          SYFT_SRC="registry:${REF}" ;;
esac
syft "$SYFT_SRC" -q -o json > "$TMP/syft.json"
# Only what lives under the venv: the RPMs own the interpreter, and the SBOM
# and the rpm database cover them.
INSTALLED=$(jq -c --arg v "${VENV}/" '[ .artifacts[]
    | select(.type == "python")
    | select(any(.locations[]?; (.path // "") | startswith($v)))
    | ((.name | ascii_downcase | gsub("[-_.]+"; "-")) + "==" + .version) ] | unique' "$TMP/syft.json")

jq -n --arg sha "$LOCK_SHA" --argjson inst "$INSTALLED" '{lock_sha256: $sha, installed_distributions: $inst}'
