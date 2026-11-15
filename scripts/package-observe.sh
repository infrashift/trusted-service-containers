#!/usr/bin/env bash
# Review actor, package track: re-derive the package facts LIVE from the image
# in the registry, and print them as JSON. Nothing here reads the build
# actor's evidence.
#
# Usage: package-observe.sh <image-ref> <repo-id>
#
#   <image-ref>  a registry reference (ghcr.io/...@sha256:...), or
#                ocidir://<path>:<tag> for a local test
#   <repo-id>    the packageRepos key; the Containerfile writes the repository
#                file /etc/yum.repos.d/tsc-<repo-id>.repo and the key
#                /etc/pki/rpm-gpg/RPM-GPG-KEY-<repo-id>
#
#   { "repo_url":         baseurl= of the repository file,
#     "gpgcheck":         gpgcheck= of the repository file,
#     "repo_gpgcheck":    repo_gpgcheck= of the repository file,
#     "key_sha256":       sha256 of the key file in the image,
#     "key_fingerprint":  fingerprint of the one primary key in that file,
#     "installed_nevras": every rpm in the image's rpm database (syft) }
#
# A value that cannot be read is printed as "" or [] -- never invented -- and
# the policy denies on it (PACKAGE_REPO_MISMATCH, PACKAGE_GPGCHECK_DISABLED,
# PACKAGE_KEY_*, PACKAGE_NEVRA_NOT_INSTALLED). Exits non-zero only when a tool
# cannot run at all.
set -euo pipefail

REF="${1:?image ref}"; REPO_ID="${2:?repo id}"
[[ "$REPO_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "::error::package-observe.sh: bad repo id ${REPO_ID}" >&2; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

regctl image get-file "$REF" "/etc/yum.repos.d/tsc-${REPO_ID}.repo" "$TMP/repo" 2>/dev/null || : > "$TMP/repo"
regctl image get-file "$REF" "/etc/pki/rpm-gpg/RPM-GPG-KEY-${REPO_ID}" "$TMP/key" 2>/dev/null || : > "$TMP/key"

# key=value from the [REPO_ID] section only, so a second section cannot
# supply the answer.
ini() {
  awk -v sec="[${REPO_ID}]" -v k="$1" '
    /^\[/ { in_sec = ($0 == sec); next }
    in_sec { line = $0; sub(/^[ \t]+/, "", line)
             if (index(line, k "=") == 1) { v = substr(line, length(k) + 2); sub(/[ \t\r]+$/, "", v); print v; exit } }' "$TMP/repo"
}

KEY_SHA=""; KEY_FPR=""
if [[ -s "$TMP/key" ]]; then
  KEY_SHA=$(sha256sum "$TMP/key" | cut -d' ' -f1)
  # --show-keys reads the file without importing it. Exactly one primary key,
  # or no fingerprint at all: a second key in the file would be a second
  # trust root that the pin does not name.
  export GNUPGHOME="$TMP/gnupg"; mkdir -m 700 "$GNUPGHOME"
  COLONS=$(gpg --batch --with-colons --show-keys "$TMP/key" 2>/dev/null || true)
  if [[ "$(grep -c '^pub:' <<<"$COLONS" || true)" -eq 1 ]]; then
    KEY_FPR=$(awk -F: '/^pub:/ { p = 1; next } p && /^fpr:/ { print $10; exit }' <<<"$COLONS")
  fi
fi

case "$REF" in
  ocidir://*) SYFT_SRC="oci-dir:$(sed -E 's|^ocidir://||; s|:[^/:]*$||' <<<"$REF")" ;;
  *)          SYFT_SRC="registry:${REF}" ;;
esac
syft "$SYFT_SRC" -q -o json > "$TMP/syft.json"
INSTALLED=$(jq -c '[ .artifacts[] | select(.type == "rpm")
    | .metadata as $m
    | select(($m.name // .name) | startswith("gpg-pubkey") | not)
    | "\($m.name // .name)-\($m.version)-\($m.release).\($m.architecture)" ] | unique' "$TMP/syft.json")

jq -n --arg url "$(ini baseurl)" --arg gc "$(ini gpgcheck)" --arg rgc "$(ini repo_gpgcheck)" \
      --arg sha "$KEY_SHA" --arg fpr "$KEY_FPR" --argjson inst "$INSTALLED" \
  '{repo_url: $url, gpgcheck: $gc, repo_gpgcheck: $rgc,
    key_sha256: $sha, key_fingerprint: $fpr, installed_nevras: $inst}'
