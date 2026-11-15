#!/usr/bin/env bash
# Native python (ADR-010): hold every committed lock to its pin.
#
# For each image of kind native, language python:
#   * native.lock.path exists and is locks/<image>/requirements.txt,
#   * its sha256 is native.lock.sha256,
#   * scripts/python-lock.sh accepts it (every line name==version with a
#     sha256, nothing else),
#   * it pins native.distribution==native.version,
#   * locks/<image>/requirements.in, the file it is generated from, exists.
# And no directory under locks/ is orphaned.
set -euo pipefail
VERSIONS="${VERSIONS:-versions.json}"
fail=0
err() { echo "error: $*" >&2; fail=1; }

declared=()
while IFS=$'\t' read -r img path sha dist ver; do
  declared+=("locks/${img}")
  [[ "$path" == "locks/${img}/requirements.txt" ]] || { err "images.${img}.native.lock.path is ${path}, not locks/${img}/requirements.txt"; continue; }
  [[ -f "$path" ]] || { err "${path} does not exist"; continue; }
  got=$(sha256sum "$path" | cut -d' ' -f1)
  [[ "$got" == "$sha" ]] || err "images.${img}.native.lock.sha256 is ${sha} but ${path} has ${got}; regenerate the pin with the lock"
  locked=$(./scripts/python-lock.sh "$path") || { err "${path} is not a hash lock"; continue; }
  norm=$(tr '[:upper:]' '[:lower:]' <<<"$dist" | sed -E 's/[-_.]+/-/g')
  jq -e --arg r "${norm}==${ver}" 'index($r) != null' <<<"$locked" >/dev/null \
    || err "${path} does not pin ${dist}==${ver} (images.${img}.native.version)"
  [[ -f "locks/${img}/requirements.in" ]] || err "locks/${img}/requirements.in, the input of ${path}, does not exist"
  [[ "$fail" -eq 0 ]] && printf '  %-16s %s  %s locked, sha256 %s\n' "$img" "$path" "$(jq length <<<"$locked")" "${sha:0:12}"
done < <(jq -r '.images | to_entries[] | select(.value.kind == "native" and .value.native.language == "python")
                | [.key, (.value.native.lock.path // ""), (.value.native.lock.sha256 // ""),
                   (.value.native.distribution // ""), (.value.native.version // "")] | @tsv' "$VERSIONS")

if [[ -d locks ]]; then
  for d in locks/*/; do
    d="${d%/}"
    [[ -d "$d" ]] || continue
    printf '%s\n' "${declared[@]}" | grep -qxF "$d" || err "${d} is not the lock of any native python image"
  done
fi

[[ "$fail" -eq 0 ]] || exit 1
echo "OK: ${#declared[@]} python lock(s) match their pins"
