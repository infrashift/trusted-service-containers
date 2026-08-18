#!/usr/bin/env bash
# Detect drift between the pinned base-image digests and what the sibling repo
# currently publishes, and rewrite versions.json in place when they differ.
#
# Runs in THIS repo on a schedule rather than being pushed here by the sibling.
# That needs no cross-repo credential, does not depend on the sibling's
# cooperation, and keeps working if the sibling is refactored. A
# repository_dispatch from the sibling would lower latency at the cost of a
# cross-repo write token -- exactly the standing credential the three-actor key
# isolation exists to avoid.
#
# Writes a markdown summary to $DRIFT_REPORT (default /tmp/drift-base.md).
set -euo pipefail

VERSIONS=versions.json
REPORT="${DRIFT_REPORT:-/tmp/drift-base.md}"
CHANGED=0
: > "$REPORT"

mapfile -t BASES < <(jq -r '.bases | keys[]' "$VERSIONS")

echo "checking ${#BASES[@]} base image(s)"
ROWS=""

for key in "${BASES[@]}"; do
  IMG=$(jq -r --arg k "$key" '.bases[$k].image' "$VERSIONS")
  mapfile -t ARCHES < <(jq -r --arg k "$key" '.bases[$k] | keys[] | select(. == "amd64" or . == "arm64")' "$VERSIONS")

  for arch in "${ARCHES[@]}"; do
    PINNED=$(jq -r --arg k "$key" --arg a "$arch" '.bases[$k][$a].digest' "$VERSIONS")

    # The PER-ARCH child digest from inside the index, not the index digest.
    # Pinning the index would rebuild every image whenever any architecture
    # changed, and would not tell us which one moved.
    if ! ACTUAL=$(regctl manifest head --platform "linux/${arch}" \
                    --format '{{.GetDescriptor.Digest}}' "${IMG}:latest" 2>/dev/null); then
      echo "  ${key} ${arch}: UNRESOLVABLE (registry error or visibility change)"
      ROWS+="| \`${key}\` | ${arch} | \`${PINNED:0:19}…\` | unresolvable | :warning: |"$'\n'
      continue
    fi

    if [[ "$ACTUAL" == "$PINNED" ]]; then
      printf '  %-14s %-6s current\n' "$key" "$arch"
    else
      printf '  %-14s %-6s DRIFT  %s -> %s\n' "$key" "$arch" "${PINNED:0:19}…" "${ACTUAL:0:19}…"
      jq --arg k "$key" --arg a "$arch" --arg d "$ACTUAL" \
        '.bases[$k][$a].digest = $d' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
      ROWS+="| \`${key}\` | ${arch} | \`${PINNED:0:19}…\` | \`${ACTUAL:0:19}…\` | updated |"$'\n'
      CHANGED=1
    fi
  done
done

if [[ "$CHANGED" -eq 1 ]]; then
  TODAY=$(date -u +'%Y-%m-%d')
  jq --arg d "$TODAY" '
    .bases |= with_entries(.value.updated = $d)' "$VERSIONS" > "${VERSIONS}.tmp" && mv "${VERSIONS}.tmp" "$VERSIONS"
  {
    echo "Automated scan found base-image digests differing from the pins in \`versions.json\`."
    echo
    echo "| Base | Arch | Pinned | Current | |"
    echo "|---|---|---|---|---|"
    printf '%s' "$ROWS"
    echo
    echo "Merging this rebuilds **every build-track image**: \`versions.json\` is a"
    echo "path trigger for \`build.yml\`, so no extra wiring is needed."
    echo
    echo "Before merging, sanity-check that the new base still satisfies the"
    echo "assumptions the Containerfiles rely on — it ships no CA bundle, no tzdata"
    echo "and no UID 1001, and those are compensated for at build time:"
    echo
    echo '```'
    echo "make -f Ops.mk verify-pins"
    echo '```'
  } > "$REPORT"
  echo "drift detected; versions.json updated"
else
  echo "No base-image drift: every pin matches what the sibling repo publishes." > "$REPORT"
  echo "no drift"
fi

echo "changed=${CHANGED}" >> "${GITHUB_OUTPUT:-/dev/null}"
