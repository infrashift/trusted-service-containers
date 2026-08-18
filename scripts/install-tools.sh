#!/usr/bin/env bash
# Install pipeline tools at the versions pinned in tools.lock.
#
# Usage: scripts/install-tools.sh regctl syft grype opa gitleaks
#
# Never install from an unpinned `latest` URL. These binaries run in the same
# job as the build signing key.
set -euo pipefail

# shellcheck disable=SC1091
source ./tools.lock

BIN="${BIN:-/usr/local/bin}"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) GOARCH=amd64 ;;
  aarch64|arm64) GOARCH=arm64 ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac

install_regctl() {
  curl -sSfL -o "$BIN/regctl" \
    "https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-${GOARCH}"
  chmod +x "$BIN/regctl"
  regctl version --format '{{.VCSTag}}' || true
}

install_syft() {
  curl -sSfL "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/install.sh" \
    | sh -s -- -b "$BIN" "${SYFT_VERSION#v}"
}

install_grype() {
  curl -sSfL "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/install.sh" \
    | sh -s -- -b "$BIN" "${GRYPE_VERSION#v}"
}

install_opa() {
  curl -sSfL -o "$BIN/opa" \
    "https://openpolicyagent.org/downloads/${OPA_VERSION}/opa_linux_${GOARCH}_static"
  chmod +x "$BIN/opa"
  opa version
}

install_gitleaks() {
  local tmp arch
  tmp=$(mktemp -d)
  # gitleaks names its 64-bit x86 asset x64, not amd64. arm64 matches.
  case "$GOARCH" in amd64) arch=x64 ;; *) arch="$GOARCH" ;; esac
  curl -sSfL -o "$tmp/g.tar.gz" \
    "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_${arch}.tar.gz"
  tar -xzf "$tmp/g.tar.gz" -C "$tmp" gitleaks
  install -m 0755 "$tmp/gitleaks" "$BIN/gitleaks"
  rm -rf "$tmp"
  gitleaks version
}

for tool in "$@"; do
  echo "::group::install $tool"
  "install_${tool}"
  echo "::endgroup::"
done
