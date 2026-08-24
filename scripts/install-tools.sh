#!/usr/bin/env bash
# Install pipeline tools at the versions pinned in tools.lock.
#
# Usage: scripts/install-tools.sh regctl syft grype opa gitleaks
#
# Never install from an unpinned `latest` URL. These binaries run in the same
# job as the build signing key.
set -euo pipefail

# Every download goes through fetch(). Retrying only where a retry can help is
# the point of the flag choice:
#
#   --retry 3 --retry-delay 2   timeouts, 5xx and 429 -- the release CDN or the
#                               registry having a bad second
#   --retry-connrefused         a refused connection, which curl does not count
#                               as transient on its own
#
# NOT --retry-all-errors: that would also retry a 404, and a 404 here means a
# wrong pin in tools.lock rather than a flaky network. Three retries would turn
# a clear "this version does not exist" into a slow one.
#
# --max-time bounds a SINGLE attempt, not the whole sequence.
fetch() {
  curl -sSfL --retry 3 --retry-delay 2 --retry-connrefused --max-time 120 "$@"
}

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
  fetch -o "$BIN/regctl" \
    "https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-${GOARCH}"
  chmod +x "$BIN/regctl"
  regctl version --format '{{.VCSTag}}' || true
}

# The installer is fetched to a FILE and then run, rather than piped straight
# into sh. Piping cannot be retried safely: if the transfer dies half way, sh has
# already executed everything that arrived, so a retry re-runs an installer on
# top of a partial one. Landing it on disk first makes the download atomic with
# respect to execution -- either fetch() returns a whole script or nothing ran.
# The version is passed WITH its leading v. Both installers resolve the argument
# as a git tag, and the tags are v1.51.0 / v0.117.0. This script stripped the v
# -- `"${SYFT_VERSION#v}"` -- which yields
#     [error] received HTTP status=404 for url='.../releases/1.51.0'
#     [error] unable to find tag=''
# and reads like a bad pin rather than a malformed argument. That was true before
# this change too; fetching the installer to a file and running it here is what
# made the failure visible instead of a broken pipe buried in a log.
install_anchore() {
  local tool="$1" version="$2" tmp
  tmp=$(mktemp -d)
  fetch -o "$tmp/install.sh" \
    "https://raw.githubusercontent.com/anchore/${tool}/${version}/install.sh"
  sh "$tmp/install.sh" -b "$BIN" "$version"
  rm -rf "$tmp"
  "$BIN/${tool}" version
}

install_syft()  { install_anchore syft  "${SYFT_VERSION}"; }
install_grype() { install_anchore grype "${GRYPE_VERSION}"; }

install_opa() {
  fetch -o "$BIN/opa" \
    "https://openpolicyagent.org/downloads/${OPA_VERSION}/opa_linux_${GOARCH}_static"
  chmod +x "$BIN/opa"
  opa version
}

install_gitleaks() {
  local tmp arch
  tmp=$(mktemp -d)
  # gitleaks names its 64-bit x86 asset x64, not amd64. arm64 matches.
  case "$GOARCH" in amd64) arch=x64 ;; *) arch="$GOARCH" ;; esac
  fetch -o "$tmp/g.tar.gz" \
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
