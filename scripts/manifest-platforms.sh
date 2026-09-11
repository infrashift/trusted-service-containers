#!/usr/bin/env bash
# Print the platform set an image reference carries, as JSON:
#
#   { "media_type": "...", "is_index": true|false, "platforms": ["linux/amd64", ...] }
#
# Two shapes exist upstream and both must be handled the same way:
#
#   index      -- a manifest list / OCI index. Platforms come from the child
#                 entries. BuildKit attestation manifests (unknown/unknown,
#                 vnd.docker.reference.type) are filtered out: nexus3 3.90.1 and
#                 3.90.5 both carry them and handing one to syft fails
#                 confusingly. Attestation shape varies between patch releases
#                 of the same upstream, so nothing may be assumed.
#   manifest   -- a bare single-platform manifest with no index at all.
#                 mcr.microsoft.com/mssql/* publishes this shape. The platform
#                 comes from the config blob's os/architecture.
#
# FAIL CLOSED. An empty platform list is never printed: a manifest that is
# neither shape, or a config with an empty os or architecture, exits 1. The
# callers compare this set against versions.json, so an empty list would read
# as "upstream dropped every architecture" rather than as a tooling bug.
#
# Usage: manifest-platforms.sh <repo>@<digest>   (or <repo>:<tag>)
set -euo pipefail

REF="${1:?usage: manifest-platforms.sh <image-ref>}"

MEDIA_TYPE=$(regctl manifest head --format '{{.GetDescriptor.MediaType}}' "$REF")
[[ -n "$MEDIA_TYPE" ]] || { echo "::error::could not resolve media type for ${REF}" >&2; exit 1; }

MANIFEST=$(regctl manifest get --format '{{jsonPretty .}}' "$REF")

if jq -e '.manifests | type == "array"' <<<"$MANIFEST" >/dev/null; then
  IS_INDEX=true
  PLATFORMS=$(jq -c '[ .manifests[]
    | select((.annotations // {})["vnd.docker.reference.type"] == null)
    | select(.platform.os != null and .platform.os != "unknown" and .platform.os != "")
    | select(.platform.architecture != null and .platform.architecture != "unknown" and .platform.architecture != "")
    | "\(.platform.os)/\(.platform.architecture)" ] | unique' <<<"$MANIFEST")
elif jq -e '.config | type == "object"' <<<"$MANIFEST" >/dev/null; then
  IS_INDEX=false
  OS=$(regctl image config --format '{{.OS}}' "$REF")
  ARCH=$(regctl image config --format '{{.Architecture}}' "$REF")
  if [[ -z "$OS" || -z "$ARCH" || "$OS" == "unknown" || "$ARCH" == "unknown" ]]; then
    echo "::error::${REF} is a single manifest whose config declares os=${OS:-<empty>} architecture=${ARCH:-<empty>}" >&2
    exit 1
  fi
  PLATFORMS=$(jq -cn --arg p "${OS}/${ARCH}" '[$p]')
else
  echo "::error::${REF} (${MEDIA_TYPE}) is neither an index nor an image manifest" >&2
  exit 1
fi

if [[ "$(jq 'length' <<<"$PLATFORMS")" -eq 0 ]]; then
  echo "::error::${REF} (${MEDIA_TYPE}) yields no scannable platform" >&2
  exit 1
fi

jq -cn --arg mt "$MEDIA_TYPE" --argjson idx "$IS_INDEX" --argjson p "$PLATFORMS" \
  '{media_type: $mt, is_index: $idx, platforms: $p}'
