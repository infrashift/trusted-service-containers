#!/usr/bin/env bash
# Install pipeline tools at the versions pinned in tools.lock.
#
# Usage: scripts/install-tools.sh regctl syft grype opa gitleaks
#
# Never install from an unpinned `latest` URL. These binaries run in the same
# job as the build signing key.
set -euo pipefail

# Every download goes through fetch(), which retries transient failures and
# ONLY transient failures.
#
# curl's own --retry covers what curl classes as transient: timeouts, 5xx, 429,
# and -- with --retry-connrefused -- a refused connection.
#
#   --retry 3 --retry-delay 2   the release CDN or the registry having a bad second
#   --retry-connrefused         a refused connection, which curl does not count
#                               as transient on its own
#
# That set does NOT include a connection which is established and then dies. A
# TLS handshake reset is exit 35, a mid-transfer recv failure is 56, an empty
# reply is 52, and curl retries none of them. One of those took out a 24-leg
# build on the FIRST download of one leg:
#
#   curl: (35) Recv failure: Connection reset by peer
#   ##[error]Process completed with exit code 35.
#
# --retry-all-errors would cover them and is still the wrong flag: combined
# with -f it also retries a 404, and a 404 here means a wrong pin in tools.lock
# rather than a flaky network. Three retries would turn a clear "this version
# does not exist" into a slow one.
#
# So the retry happens here, keyed on the curl exit code, and the list is an
# ALLOW list. 22 -- the code -f returns for any HTTP >= 400 -- is not on it, and
# neither is anything unrecognised: a code only earns a retry by being known
# transient. A wrong pin still fails on the first attempt, loudly.
#
# --max-time bounds a SINGLE curl attempt, not the whole sequence.
fetch() {
  local attempt=1 rc delay
  while :; do
    rc=0
    curl -sSfL --retry 3 --retry-delay 2 --retry-connrefused --max-time 120 "$@" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      return 0
    fi
    case "$rc" in
      # 6 resolve  7 connect  28 timeout  35 TLS  52 empty reply  55 send  56 recv
      6|7|28|35|52|55|56) : ;;
      *) return "$rc" ;;
    esac
    if [[ "$attempt" -ge 3 ]]; then
      echo "fetch: curl exit ${rc} after ${attempt} attempts; giving up" >&2
      return "$rc"
    fi
    delay=$(( attempt * 5 ))
    echo "fetch: curl exit ${rc} (transport), attempt ${attempt}/3; retrying in ${delay}s" >&2
    sleep "$delay"
    attempt=$(( attempt + 1 ))
  done
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

# cosign holds the signing key, so it is the one binary whose identity must be a
# REVIEWED REPO FACT rather than whatever a release endpoint serves today.
# tools.lock carries the version AND the sha256 of each release binary, and a
# mismatch installs nothing.
#
# This replaces the sigstore/cosign-installer action, for two reasons:
#
#   - That action fetches a bootstrap cosign through its own curl, outside
#     fetch(), so the retry above could not reach it. A TLS reset there
#     (curl 35) cost a 24-leg build one leg, in two consecutive runs.
#   - Its `cosign-release:` input restated COSIGN_VERSION in FIVE workflow
#     steps, held in step by a comment on one of them and by nothing else.
#     One install path deletes that drift class; lint-workflows.sh now refuses
#     to let it come back.
#
# The trade is explicit rather than hidden. cosign-installer verified its
# download against sigstore; this verifies it against a digest committed here
# and gated by CODEOWNERS. A signature proves the project signed something; the
# pin proves these are byte-for-byte the bytes that were reviewed, and they
# cannot change without a reviewed commit. The pinned values in tools.lock were
# produced by verifying cosign's own signed cosign_checksums.txt with
# `cosign verify-blob` against the release workflow identity, then
# independently hashing the downloaded binaries.
install_cosign() {
  local want tmp
  case "$GOARCH" in
    amd64) want="${COSIGN_SHA256_AMD64:-}" ;;
    arm64) want="${COSIGN_SHA256_ARM64:-}" ;;
    *)     want="" ;;
  esac
  if [[ -z "$want" ]]; then
    echo "::error::no cosign sha256 pinned in tools.lock for ${GOARCH}" >&2
    return 1
  fi
  tmp=$(mktemp -d)
  fetch -o "$tmp/cosign" \
    "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${GOARCH}"
  if ! echo "${want}  ${tmp}/cosign" | sha256sum -c - >/dev/null 2>&1; then
    echo "::error::cosign-linux-${GOARCH} sha256 $(sha256sum "$tmp/cosign" | cut -d' ' -f1) does not match the ${want} pinned in tools.lock; refusing to install" >&2
    rm -rf "$tmp"
    return 1
  fi
  install -m 0755 "$tmp/cosign" "$BIN/cosign"
  rm -rf "$tmp"
  "$BIN/cosign" version
}

install_notation() {
  local tmp
  tmp=$(mktemp -d)
  fetch -o "$tmp/notation.tgz" \
    "https://github.com/notaryproject/notation/releases/download/${NOTATION_VERSION}/notation_${NOTATION_VERSION#v}_linux_${GOARCH}.tar.gz"
  fetch -o "$tmp/checksums.txt" \
    "https://github.com/notaryproject/notation/releases/download/${NOTATION_VERSION}/notation_${NOTATION_VERSION#v}_checksums.txt"
  # Upstream publishes sha256 sums; a tarball that does not match is not installed.
  (cd "$tmp" && grep " notation_${NOTATION_VERSION#v}_linux_${GOARCH}.tar.gz\$" checksums.txt \
     | sed 's/  .*/  notation.tgz/' | sha256sum -c -)
  tar -xzf "$tmp/notation.tgz" -C "$tmp" notation
  install -m 0755 "$tmp/notation" "$BIN/notation"
  rm -rf "$tmp"
  "$BIN/notation" version
}

for tool in "$@"; do
  echo "::group::install $tool"
  "install_${tool}"
  echo "::endgroup::"
done
