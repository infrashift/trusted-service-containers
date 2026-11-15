#!/usr/bin/env bash
# Build one {service, arch} leg of a BUILT image, scan, sign, attest. Three kinds:
#
#   build    compile a pinned source commit onto our trusted ubi9-micro and
#            cross-check the binary against the vendor's official image.
#   package  install signed RPMs at pinned NEVRAs from one pinned repository
#            onto our trusted base, and prove with `rpm -q` that exactly those
#            NEVRAs, signed by the pinned key, are in the image (ADR-009).
#   native   build on a pinned UBI builder, with the compiler or interpreter
#            from the signed UBI repositories, onto our trusted base (ADR-010).
#            Language c: compile a pinned commit, prove its tree equals the
#            vendor's release archive pinned by sha256, record the binary hash.
#            Language python: install a committed hash lock into a venv, and
#            prove with the venv's own interpreter that it holds exactly it.
#
# The kind comes from versions.json, never from the matrix alone; an entry of
# any other kind fails here.
#
# A first-party build entry (versions.json `firstParty`, ADR-008) has no vendor
# image. It records the hash of our binary only, and says so in the evidence.
# scripts/provenance-mode.sh decides the mode from versions.json and refuses
# an absent, double or non-infrashift declaration before anything is built.
#
# Required env: SERVICE VARIANT LEG ARCH TRUST_CLASS PR_NUM GITHUB_REPOSITORY
#               GITHUB_SHA COSIGN_PRIVATE_KEY COSIGN_PASSWORD
set -euo pipefail

: "${SERVICE:?}" "${LEG:?}" "${ARCH:?}" "${PR_NUM:?}" "${GITHUB_REPOSITORY:?}"
VARIANT="${VARIANT:-runtime}"
TRUST_CLASS="${TRUST_CLASS:-internal}"

fail() { echo "::error::$*"; exit 1; }

EVIDENCE=evidence
mkdir -p "$EVIDENCE"

# ---------------------------------------------------------------------------
# 1. Resolve every input from versions.json. jq --arg, never string concat.
# ---------------------------------------------------------------------------
IMG=$(jq -ce --arg s "$SERVICE" '.images[$s]' versions.json)
KIND=$(jq -r '.kind' <<<"$IMG")
[[ "$KIND" == build || "$KIND" == package || "$KIND" == native ]] \
  || fail "images.${SERVICE}.kind is '${KIND}'; build-leg.sh builds only kind build, package or native"
# The matrix kind is the job family: all three image kinds are "build" legs there.
if [[ -n "${MATRIX_KIND:-}" && "$MATRIX_KIND" != build ]]; then
  fail "the matrix runs ${SERVICE} as a ${MATRIX_KIND} leg, but versions.json kind ${KIND} is built by the build job"
fi

BASE_KEY=$(jq -r '.base'     <<<"$IMG")
ENFORCEMENT=$(jq -r '.enforcement' <<<"$IMG")
CONTAINERFILE=$(jq -r '.containerfile' <<<"$IMG")

lookup() { jq -r --arg k "$1" --arg a "$ARCH" "$2" versions.json; }
BASE_IMG=$(lookup "$BASE_KEY" '.bases[$k].image')
BASE_DIGEST=$(lookup "$BASE_KEY" '.bases[$k][$a].digest')
BASE_KEYFILE=$(lookup "$BASE_KEY" '.bases[$k].verifyKey')
DEST_REPO="ghcr.io/${GITHUB_REPOSITORY}/development/${SERVICE}"

if [[ "$KIND" == build ]]; then
SRC_KEY=$(jq -r '.source' <<<"$IMG")
REPO_KEY=$(jq -r '.repo // empty' <<<"$IMG")

if [[ -n "$REPO_KEY" ]]; then
  SRC_URL=$(jq -r --arg s "$SRC_KEY" --arg r "$REPO_KEY" '.sources[$s].repos[$r].url'    versions.json)
  SRC_REF=$(jq -r --arg s "$SRC_KEY" --arg r "$REPO_KEY" '.sources[$s].repos[$r].commit' versions.json)
else
  SRC_URL=$(jq -r --arg s "$SRC_KEY" '.sources[$s].url'    versions.json)
  SRC_REF=$(jq -r --arg s "$SRC_KEY" '.sources[$s].commit' versions.json)
fi
SRC_VERSION=$(jq -r --arg s "$SRC_KEY" '.sources[$s].ref' versions.json)
# Some vendors stamp a SHORT commit whose length is git's dynamic abbreviation
# for the full repository. We clone --depth 1, where git abbreviates to the
# 7-char minimum, so the value cannot be derived here and is pinned as data.
# Getting the length wrong changes an embedded string and therefore the binary
# hash -- which is exactly what the dual-provenance cross-check detects.
SRC_SHORT=$(jq -r --arg s "$SRC_KEY" '.sources[$s].shortCommit // ""' versions.json)
[[ -n "$SRC_SHORT" ]] || SRC_SHORT="${SRC_REF:0:7}"
[[ "$SRC_REF" == "$SRC_SHORT"* ]] || fail "shortCommit '${SRC_SHORT}' is not a prefix of commit '${SRC_REF}'"

# A tag is NOT a pin: tags move and can be force-pushed. Commits cannot.
[[ "$SRC_REF" =~ ^[0-9a-f]{40}$ ]] || { echo "::error::source ref for ${LEG} is not a 40-hex commit: ${SRC_REF}"; exit 1; }

CA_KEY=$(jq   -r '.caSource' <<<"$IMG")
TC_KEY=$(jq   -r '.toolchain' <<<"$IMG")
CA_IMG=$(lookup "$CA_KEY" '.bases[$k].image')
CA_DIGEST=$(lookup "$CA_KEY" '.bases[$k][$a].digest')
TC_IMG=$(lookup "$TC_KEY" '.toolchains[$k].image')
TC_DIGEST=$(lookup "$TC_KEY" '.toolchains[$k][$a].digest')

# Provenance mode: a vendor comparison, or an explicit first-party
# declaration. Never inferred from a missing crosscheck block.
MODE_JSON=$(./scripts/provenance-mode.sh "$SERVICE") || fail "no valid provenance mode for ${LEG}"
XC_MODE=$(jq -r '.mode' <<<"$MODE_JSON")
case "$XC_MODE" in
  vendor-crosscheck)
    XC_IMG=$(jq -r '.crosscheck.image' <<<"$IMG")
    XC_BINPATH=$(jq -r '.crosscheck.binaryPath' <<<"$IMG")
    XC_TIER=$(jq -r '.crosscheck.reproducibilityTier' <<<"$IMG")
    XC_DIGEST=$(jq -r --arg a "$ARCH" '.crosscheck[$a].digest' <<<"$IMG")
    MUST_RESOLVE=(XC_IMG XC_BINPATH XC_DIGEST)
    ;;
  first-party)
    FP_REASON=$(jq -r '.reason' <<<"$MODE_JSON")
    # The same derivation as SRC_URL above; a disagreement is a bug in one.
    [[ "$(jq -r '.sourceUrl' <<<"$MODE_JSON")" == "$SRC_URL" ]] \
      || fail "provenance-mode.sh resolved $(jq -r '.sourceUrl' <<<"$MODE_JSON") but the build would fetch ${SRC_URL}"
    MUST_RESOLVE=()
    ;;
  *) fail "unknown provenance mode '${XC_MODE}' for ${LEG}" ;;
esac

INSTALL_PATH=$(jq -r '.build.installPath' <<<"$IMG")

for v in SRC_URL SRC_REF BASE_IMG BASE_DIGEST CA_DIGEST TC_DIGEST INSTALL_PATH "${MUST_RESOLVE[@]}"; do
  val="${!v}"
  [[ -n "$val" && "$val" != "null" ]] || { echo "::error::${v} unresolved for ${LEG}"; exit 1; }
done
DIGESTS=("$BASE_DIGEST" "$CA_DIGEST" "$TC_DIGEST")
[[ "$XC_MODE" == "vendor-crosscheck" ]] && DIGESTS+=("$XC_DIGEST")
for d in "${DIGESTS[@]}"; do
  [[ "$d" =~ ^sha256:[a-f0-9]{64}$ ]] || { echo "::error::malformed digest: ${d}"; exit 1; }
done

DEST_TAG="pr-${PR_NUM}-${SRC_VERSION}-${ARCH}"

elif [[ "$KIND" == native ]]; then
  # -------------------------------------------------------------------------
  # 1n. Native kind (ADR-010): the pinned input of the language, the UBI
  #     builder and the build packages, for THIS arch.
  # -------------------------------------------------------------------------
  NATIVE_LANG=$(jq -r '.native.language' <<<"$IMG")
  INSTALL_PATH=$(jq -r '.native.installPath' <<<"$IMG")
  case "$NATIVE_LANG" in
  c)
  [[ "$INSTALL_PATH" =~ ^/usr/bin/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "native.installPath '${INSTALL_PATH}' is malformed"
  SRC_KEY=$(jq -r '.source' <<<"$IMG")
  SRC_URL=$(jq -r --arg s "$SRC_KEY" '.sources[$s].url // ""'    versions.json)
  SRC_REF=$(jq -r --arg s "$SRC_KEY" '.sources[$s].commit // ""' versions.json)
  SRC_VERSION=$(jq -r --arg s "$SRC_KEY" '.sources[$s].ref // ""' versions.json)
  ARCHIVE_SHA=$(jq -r --arg s "$SRC_KEY" '.sources[$s].archive.sha256 // ""' versions.json)
  ARCHIVE_SRC=$(jq -r --arg s "$SRC_KEY" '.sources[$s].archive.hashSource // ""' versions.json)
  [[ "$SRC_REF" =~ ^[0-9a-f]{40}$ ]] || fail "source ref for ${LEG} is not a 40-hex commit: ${SRC_REF}"
  [[ "$SRC_URL" =~ ^https:// ]]      || fail "sources.${SRC_KEY}.url is not an https URL: ${SRC_URL}"
  [[ "$SRC_VERSION" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] || fail "sources.${SRC_KEY}.ref '${SRC_VERSION}' is not tag-safe"
  [[ "$ARCHIVE_SHA" =~ ^[a-f0-9]{64}$ ]] || fail "sources.${SRC_KEY}.archive.sha256 is not pinned"
  ;;
  python)
  # The pinned input is the committed lock. Its sha256 must be the pin here,
  # before anything is built; the Containerfile checks it again, and the
  # review re-reads both the checkout and the copy in the image.
  LOCK_PATH=$(jq -r '.native.lock.path' <<<"$IMG")
  LOCK_SHA=$(jq -r '.native.lock.sha256' <<<"$IMG")
  VENV=$(jq -r '.native.venv' <<<"$IMG")
  PY_DIST=$(jq -r '.native.distribution' <<<"$IMG")
  SRC_VERSION=$(jq -r '.native.version' <<<"$IMG")
  SRC_URL=$(jq -r '.native.projectUrl' <<<"$IMG")
  SRC_REF="$LOCK_SHA"
  [[ "$LOCK_PATH" == "locks/${SERVICE}/requirements.txt" ]] || fail "native.lock.path '${LOCK_PATH}' is not locks/${SERVICE}/requirements.txt"
  [[ "$LOCK_SHA" =~ ^[a-f0-9]{64}$ ]] || fail "native.lock.sha256 is not pinned"
  [[ -f "$LOCK_PATH" ]] || fail "${LOCK_PATH} is not in the checkout"
  GOT_SHA=$(sha256sum "$LOCK_PATH" | cut -d' ' -f1)
  [[ "$GOT_SHA" == "$LOCK_SHA" ]] || fail "${LOCK_PATH} has sha256 ${GOT_SHA}; versions.json pins ${LOCK_SHA}"
  [[ "$VENV" =~ ^/opt/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "native.venv '${VENV}' is malformed"
  [[ "$INSTALL_PATH" == "${VENV}/bin/"* ]] || fail "native.installPath '${INSTALL_PATH}' is not under ${VENV}/bin/"
  [[ "$SRC_VERSION" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] || fail "native.version '${SRC_VERSION}' is not tag-safe"
  [[ "$SRC_URL" =~ ^https:// ]] || fail "native.projectUrl is not an https URL: ${SRC_URL}"
  LOCKED=$(./scripts/python-lock.sh "$LOCK_PATH") || fail "${LOCK_PATH} is not a hash lock"
  jq -e --arg r "${PY_DIST}==${SRC_VERSION}" 'index($r) != null' <<<"$LOCKED" >/dev/null \
    || fail "${LOCK_PATH} does not pin ${PY_DIST}==${SRC_VERSION}"
  mapfile -t RUNTIME_PKGS < <(jq -r '.native.runtimePackages[]?' <<<"$IMG")
  [[ ${#RUNTIME_PKGS[@]} -gt 0 ]] || fail "images.${SERVICE}.native.runtimePackages is empty"
  for b in "${RUNTIME_PKGS[@]}"; do
    [[ "$b" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || fail "runtime package '${b}' is not an RPM name"
  done
  ;;
  *) fail "native.language '${NATIVE_LANG}' is not supported by build-leg.sh" ;;
  esac
  mapfile -t BUILD_PKGS < <(jq -r '.native.buildPackages[]?' <<<"$IMG")
  [[ ${#BUILD_PKGS[@]} -gt 0 ]] || fail "images.${SERVICE}.native.buildPackages is empty"
  for b in "${BUILD_PKGS[@]}"; do
    [[ "$b" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || fail "build package '${b}' is not an RPM name"
  done

  BUILDER_KEY=$(jq -r '.builder' <<<"$IMG")
  BUILDER_IMG=$(lookup "$BUILDER_KEY" '.bases[$k].image')
  BUILDER_DIGEST=$(lookup "$BUILDER_KEY" '.bases[$k][$a].digest')
  BUILDER_KEYFILE=$(lookup "$BUILDER_KEY" '.bases[$k].verifyKey')
  for v in BASE_IMG BASE_DIGEST BUILDER_IMG BUILDER_DIGEST BUILDER_KEYFILE; do
    val="${!v}"
    [[ -n "$val" && "$val" != "null" ]] || fail "${v} unresolved for ${LEG}"
  done
  for d in "$BASE_DIGEST" "$BUILDER_DIGEST"; do
    [[ "$d" =~ ^sha256:[a-f0-9]{64}$ ]] || fail "malformed digest: ${d}"
  done
  DEST_TAG="pr-${PR_NUM}-${SRC_VERSION}-${ARCH}"

else
  # -------------------------------------------------------------------------
  # 1p. Package kind: the repository, the key and the NEVRAs for THIS arch.
  # -------------------------------------------------------------------------
  PKG_REPO_ID=$(jq -r '.packages.repo' <<<"$IMG")
  PKG_VERSION=$(jq -r '.packages.version' <<<"$IMG")
  [[ "$PKG_REPO_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || fail "packages.repo '${PKG_REPO_ID}' is not a repository id"
  [[ "$PKG_VERSION" =~ ^[0-9]+\.[0-9]+$ ]] || fail "packages.version '${PKG_VERSION}' is not a version"
  PKG_REPO=$(jq -ce --arg r "$PKG_REPO_ID" --arg a "$ARCH" '.packageRepos[$r][$a]' versions.json) \
    || fail "packageRepos.${PKG_REPO_ID}.${ARCH} is not pinned"
  PKG_BASEURL=$(jq -r '.baseurl' <<<"$PKG_REPO")
  PKG_KEY=$(jq -r '.key' <<<"$PKG_REPO")
  PKG_KEY_FPR=$(jq -r '.signerFingerprint' <<<"$PKG_REPO")
  PKG_KEY_SHA=$(jq -r '.signerFileSha256' <<<"$PKG_REPO")
  mapfile -t PKG_NEVRAS < <(jq -r --arg a "$ARCH" '.packages[$a][]?' <<<"$IMG")
  [[ ${#PKG_NEVRAS[@]} -gt 0 ]] || fail "images.${SERVICE}.packages.${ARCH} pins no NEVRA"

  [[ "$PKG_BASEURL" =~ ^https://[^[:space:]\$]+$ ]] || fail "baseurl '${PKG_BASEURL}' is not a literal https URL"
  [[ "$PKG_KEY" =~ ^\.github/pdp/keyring/[A-Za-z0-9._-]+\.asc$ ]] || fail "key '${PKG_KEY}' is not under .github/pdp/keyring/"
  [[ "$PKG_KEY_FPR" =~ ^[0-9A-F]{40}$ ]] || fail "signerFingerprint '${PKG_KEY_FPR}' is not a 40-hex fingerprint"
  [[ "$PKG_KEY_SHA" =~ ^[0-9a-f]{64}$ ]] || fail "signerFileSha256 '${PKG_KEY_SHA}' is not a sha256"
  PKG_KEY_ID=$(tr '[:upper:]' '[:lower:]' <<<"${PKG_KEY_FPR:24:16}")

  # The key file must be the pinned one, byte for byte AND by fingerprint,
  # and hold exactly one primary key. The Containerfile checks the sha256
  # again; the review re-derives both from the image on GHCR.
  [[ -f "$PKG_KEY" ]] || fail "${PKG_KEY} is not in the checkout"
  GOT_SHA=$(sha256sum "$PKG_KEY" | cut -d' ' -f1)
  [[ "$GOT_SHA" == "$PKG_KEY_SHA" ]] || fail "${PKG_KEY} has sha256 ${GOT_SHA}; versions.json pins ${PKG_KEY_SHA}"
  KEY_COLONS=$(GNUPGHOME="$(mktemp -d)" gpg --batch --with-colons --show-keys "$PKG_KEY" 2>/dev/null) \
    || fail "gpg cannot read ${PKG_KEY}"
  [[ "$(grep -c '^pub:' <<<"$KEY_COLONS")" -eq 1 ]] || fail "${PKG_KEY} must hold exactly one primary key"
  GOT_FPR=$(awk -F: '/^pub:/ { p = 1; next } p && /^fpr:/ { print $10; exit }' <<<"$KEY_COLONS")
  [[ "$GOT_FPR" == "$PKG_KEY_FPR" ]] || fail "${PKG_KEY} has fingerprint ${GOT_FPR}; versions.json pins ${PKG_KEY_FPR}"

  # One SRPM build per arch: every pinned NEVRA carries the same
  # version-release. It is the revision label.
  PKG_EVR=""
  for n in "${PKG_NEVRAS[@]}"; do
    [[ "$n" =~ ^([A-Za-z0-9][A-Za-z0-9._+-]*)-([0-9][A-Za-z0-9._+~^]*)-([A-Za-z0-9._+~^]+)\.(x86_64|aarch64|noarch)$ ]] \
      || fail "'${n}' is not NAME-VERSION-RELEASE.ARCH"
    [[ "${BASH_REMATCH[2]}" == "$PKG_VERSION" ]] || fail "${n} is not version ${PKG_VERSION}"
    vr="${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    [[ -z "$PKG_EVR" || "$PKG_EVR" == "$vr" ]] || fail "pinned NEVRAs for ${ARCH} span two version-releases (${PKG_EVR}, ${vr})"
    PKG_EVR="$vr"
  done

  for v in BASE_IMG BASE_DIGEST; do
    val="${!v}"
    [[ -n "$val" && "$val" != "null" ]] || fail "${v} unresolved for ${LEG}"
  done
  [[ "$BASE_DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]] || fail "malformed digest: ${BASE_DIGEST}"
  DEST_TAG="pr-${PR_NUM}-${PKG_VERSION}-${ARCH}"
fi

if [[ "$KIND" == build ]]; then
# ---------------------------------------------------------------------------
# 2. Fetch the source at the pinned COMMIT. (build kind only)
# ---------------------------------------------------------------------------
./scripts/fetch-source.sh "$SERVICE" "$SRC_URL" "$SRC_REF" "$SRC_VERSION"
# Pinned vendor release assets the source build needs (Prometheus's web UI).
# A no-op for sources that declare none.
./scripts/fetch-assets.sh "$SERVICE" "$SRC_KEY"

# Committer date, NOT `date -u`. Wall-clock time guarantees a different binary
# on every rerun, which destroys any chance of self-consistency and makes the
# cross-check meaningless even against ourselves.
SOURCE_DATE=$(cat "src/.meta/${SERVICE}.source-date")
SOURCE_GIT_VERSION=$(cat "src/.meta/${SERVICE}.source-git-version")
elif [[ "$KIND" == native ]]; then
# ---------------------------------------------------------------------------
# 2n. Fetch the source at the pinned COMMIT, then the release archive pinned
#     by sha256, and require identical file trees. (native kind only)
# ---------------------------------------------------------------------------
if [[ "$NATIVE_LANG" == c ]]; then
./scripts/fetch-source.sh "$SERVICE" "$SRC_URL" "$SRC_REF" "$SRC_VERSION"
./scripts/fetch-archive.sh "$SERVICE" "$SRC_KEY" > /tmp/archive-check.json \
  || fail "the release archive of ${SRC_KEY} does not verify against the pinned commit"
jq -e --arg sha "$ARCHIVE_SHA" '.tree_match == true and .sha256 == $sha' /tmp/archive-check.json >/dev/null \
  || fail "fetch-archive.sh did not confirm the pinned archive"
ARCHIVE_URL=$(jq -r '.url' /tmp/archive-check.json)
SOURCE_DATE=$(cat "src/.meta/${SERVICE}.source-date")
fi

# The builder is one of our bases: verify it with the same release key as
# the runtime base, and refuse to compile on anything that does not verify.
cosign verify-attestation \
    --key "$BUILDER_KEYFILE" \
    --type https://infrashift.io/attestation/release/v1 \
    --insecure-ignore-tlog \
    --certificate-identity-regexp='.*' --certificate-oidc-issuer-regexp='.*' \
    "${BUILDER_IMG}@${BUILDER_DIGEST}" > /dev/null 2>/tmp/builder-att.err \
  || fail "the builder ${BUILDER_IMG}@${BUILDER_DIGEST} does not verify against ${BUILDER_KEYFILE}: $(head -c 300 /tmp/builder-att.err)"
fi

# ---------------------------------------------------------------------------
# 3. Verify the base image we are about to build on.
#
# release.pub, NOT build.pub: the sibling repo's build key only ever signed the
# development namespace, which its own cleanup workflow deletes.
# ---------------------------------------------------------------------------
UPSTREAM_RESULT=verified; UPSTREAM_REASON=OK
if ! cosign verify-attestation \
      --key "$BASE_KEYFILE" \
      --type https://infrashift.io/attestation/release/v1 \
      --insecure-ignore-tlog \
      --certificate-identity-regexp='.*' --certificate-oidc-issuer-regexp='.*' \
      "${BASE_IMG}@${BASE_DIGEST}" > /tmp/base-att.json 2>/tmp/base-att.err; then
  UPSTREAM_RESULT=failed
  UPSTREAM_REASON="$(head -c 300 /tmp/base-att.err)"
fi

# Written on EVERY path -- a missing file is a hole, a file saying failed is a
# finding. Covered by checksums.sha256 so it cannot be quietly removed.
if [[ "$KIND" == build ]]; then
  CA_TRUST='{"injected": true, "reason": "ubi9-micro ships no CA trust bundle (verified by layer listing); every service here makes outbound TLS calls"}'
else
  CA_TRUST='{"injected": false, "reason": "the package-track and native-track base is ubi9-minimal, which ships its own CA trust bundle"}'
fi
jq -n --arg tc "$TRUST_CLASS" --arg res "$UPSTREAM_RESULT" --arg reason "$UPSTREAM_REASON" \
      --arg uri "$BASE_IMG" --arg dig "$BASE_DIGEST" --arg key "$BASE_KEYFILE" --arg arch "$ARCH" \
      --argjson ca "$CA_TRUST" \
  '{ trust_class: $tc, result: $res, reason: $reason,
     subject: ($uri + "@" + $dig),
     verified_with: $key,
     keyring: { path: $key, pinned_sha256: "", fetched_sha256: "" },
     upstream: { role: "base-image", uri: $uri, digest: $dig, arch: $arch,
                 pinned_in: "versions.json#/bases" },
     attestations: { sbom: "present", provenance: "present", vex: "absent" },
     ca_trust: $ca }' \
  > "$EVIDENCE/upstream-verification.json"

# ---------------------------------------------------------------------------
# 4. Build.
# ---------------------------------------------------------------------------
if [[ "$KIND" == native && "$NATIVE_LANG" == python ]]; then
buildah bud \
  --platform "linux/${ARCH}" \
  --build-arg BUILDER_BASE="$BUILDER_IMG"   --build-arg BUILDER_DIGEST="$BUILDER_DIGEST" \
  --build-arg UPSTREAM_BASE="$BASE_IMG"     --build-arg UPSTREAM_DIGEST="$BASE_DIGEST" \
  --build-arg BUILD_PACKAGES="${BUILD_PKGS[*]}" --build-arg RUNTIME_PACKAGES="${RUNTIME_PKGS[*]}" \
  --build-arg LOCK_SHA256="$LOCK_SHA"       --build-arg VENV="$VENV" \
  --build-arg SOURCE_URL="$SRC_URL"         --build-arg SOURCE_REF="$SRC_REF" \
  --build-arg SOURCE_VERSION="$SRC_VERSION" \
  --build-arg GIT_COMMIT="${GITHUB_SHA:-unknown}" \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg TARGETARCH="$ARCH" \
  -t "${DEST_REPO}:${DEST_TAG}" -f "$CONTAINERFILE" .
elif [[ "$KIND" == native ]]; then
buildah bud \
  --platform "linux/${ARCH}" \
  --build-arg BUILDER_BASE="$BUILDER_IMG"   --build-arg BUILDER_DIGEST="$BUILDER_DIGEST" \
  --build-arg UPSTREAM_BASE="$BASE_IMG"     --build-arg UPSTREAM_DIGEST="$BASE_DIGEST" \
  --build-arg BUILD_PACKAGES="${BUILD_PKGS[*]}" \
  --build-arg SOURCE_URL="$SRC_URL"         --build-arg SOURCE_REF="$SRC_REF" \
  --build-arg SOURCE_VERSION="$SRC_VERSION" --build-arg SOURCE_DATE="$SOURCE_DATE" \
  --build-arg ARCHIVE_SHA256="$ARCHIVE_SHA" \
  --build-arg GIT_COMMIT="${GITHUB_SHA:-unknown}" \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg TARGETARCH="$ARCH" \
  -t "${DEST_REPO}:${DEST_TAG}" -f "$CONTAINERFILE" .
elif [[ "$KIND" == package ]]; then
buildah bud \
  --platform "linux/${ARCH}" \
  --build-arg UPSTREAM_BASE="$BASE_IMG"     --build-arg UPSTREAM_DIGEST="$BASE_DIGEST" \
  --build-arg PACKAGE_REPO_ID="$PKG_REPO_ID" --build-arg PACKAGE_BASEURL="$PKG_BASEURL" \
  --build-arg PACKAGE_KEY="$PKG_KEY"        --build-arg PACKAGE_KEY_SHA256="$PKG_KEY_SHA" \
  --build-arg PACKAGE_KEY_ID="$PKG_KEY_ID"  --build-arg PACKAGE_NEVRAS="${PKG_NEVRAS[*]}" \
  --build-arg PACKAGE_VERSION="$PKG_VERSION" --build-arg PACKAGE_EVR="$PKG_EVR" \
  --build-arg GIT_COMMIT="${GITHUB_SHA:-unknown}" \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg TARGETARCH="$ARCH" \
  -t "${DEST_REPO}:${DEST_TAG}" -f "$CONTAINERFILE" .
else
# A first-party Containerfile has no crosscheck label to fill, and
# scripts/lint-containerfiles.sh forbids one, so the args are passed only for
# a vendor comparison.
XC_ARGS=()
if [[ "$XC_MODE" == "vendor-crosscheck" ]]; then
  XC_ARGS=(--build-arg CROSSCHECK_IMAGE="$XC_IMG" --build-arg CROSSCHECK_DIGEST="$XC_DIGEST")
fi

buildah bud \
  --platform "linux/${ARCH}" \
  --build-arg UPSTREAM_BASE="$BASE_IMG"     --build-arg UPSTREAM_DIGEST="$BASE_DIGEST" \
  --build-arg CA_BASE="$CA_IMG"             --build-arg CA_DIGEST="$CA_DIGEST" \
  --build-arg TOOLCHAIN_BASE="$TC_IMG"      --build-arg TOOLCHAIN_DIGEST="$TC_DIGEST" \
  --build-arg SOURCE_URL="$SRC_URL"         --build-arg SOURCE_VERSION="$SRC_VERSION" \
  --build-arg SOURCE_REF="$SRC_REF"         --build-arg SOURCE_SHORT_REF="$SRC_SHORT" \
  --build-arg SOURCE_DATE="$SOURCE_DATE"    --build-arg SOURCE_GIT_VERSION="$SOURCE_GIT_VERSION" \
  "${XC_ARGS[@]}" \
  --build-arg IMAGE_VERSION="$SRC_VERSION"  --build-arg GIT_COMMIT="${GITHUB_SHA:-unknown}" \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg TARGETARCH="$ARCH" \
  -t "${DEST_REPO}:${DEST_TAG}" -f "$CONTAINERFILE" .
fi

buildah push --digestfile /tmp/pushed-digest.txt "${DEST_REPO}:${DEST_TAG}"
PUSHED=$(cat /tmp/pushed-digest.txt)
buildah push "${DEST_REPO}:${DEST_TAG}" "oci:./oci-image"

# ---------------------------------------------------------------------------
# 5. Assert the five policy-required labels BEFORE anything depends on them.
#    An empty label here is the classic symptom of a pre-FROM ARG not
#    re-declared after FROM -- a real bug the reference repo had to fix.
# ---------------------------------------------------------------------------
LABELS=$(skopeo inspect "docker://${DEST_REPO}@${PUSHED}" | jq -c '.Labels // {}')
for L in org.opencontainers.image.source org.opencontainers.image.revision \
         org.opencontainers.image.version io.infrashift.image.upstream.digest \
         io.infrashift.image.upstream.source; do
  val=$(jq -r --arg l "$L" '.[$l] // ""' <<<"$LABELS")
  [[ -n "$val" ]] || { echo "::error::required label ${L} is missing or empty on ${DEST_REPO}@${PUSHED}"; exit 1; }
done
CONFIG_USER=$(skopeo inspect --config "docker://${DEST_REPO}@${PUSHED}" | jq -r '.config.User // ""')

# ---------------------------------------------------------------------------
# 6p. Package verification (package kind). Ask the image's own rpm database,
#     before anything is signed: every pinned NEVRA at exactly that NEVRA,
#     signed by the pinned key, and no unpinned package with that key. The
#     Containerfile checked the same inside the build; this checks the image
#     that was pushed. The review re-derives the installed set live from GHCR.
# ---------------------------------------------------------------------------
if [[ "$KIND" == package ]]; then
  ./scripts/package-verify.sh "${DEST_REPO}:${DEST_TAG}" "${PKG_NEVRAS[@]}" > /tmp/package-verify.json
  MISSING=$(jq -r '.missing | join(" ")' /tmp/package-verify.json)
  [[ -z "$MISSING" ]] || fail "rpm -q does not find the pinned NEVRA(s) in the image: ${MISSING}"
  for n in "${PKG_NEVRAS[@]}"; do
    jq -e --arg n "$n" --arg k "$PKG_KEY_ID" 'any(.signatures[]; .nevra == $n and .key_id == $k)' /tmp/package-verify.json >/dev/null \
      || fail "${n} is not signed by the pinned key ${PKG_KEY_ID}"
  done
  UNPINNED=$(jq -r --arg k "$PKG_KEY_ID" --argjson p "$(printf '%s\n' "${PKG_NEVRAS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
    '[.signatures[] | select(.key_id == $k and (.nevra as $n | $p | index($n) | not)) | .nevra] | join(" ")' /tmp/package-verify.json)
  [[ -z "$UNPINNED" ]] || fail "package(s) signed by ${PKG_KEY_ID} but not pinned: ${UNPINNED}"
  echo "package verification: ${#PKG_NEVRAS[@]} pinned NEVRA(s) installed and signed by ${PKG_KEY_ID}; $(jq '.signatures | length' /tmp/package-verify.json) package(s) recorded"

  jq -n --arg leg "$LEG" --arg arch "$ARCH" --arg repo "$PKG_REPO_ID" --arg url "$PKG_BASEURL" \
        --arg key "$PKG_KEY" --arg fpr "$PKG_KEY_FPR" --arg sha "$PKG_KEY_SHA" --arg kid "$PKG_KEY_ID" \
        --arg ver "$PKG_VERSION" --arg evr "$PKG_EVR" \
        --argjson pinned "$(printf '%s\n' "${PKG_NEVRAS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
        --slurpfile pv /tmp/package-verify.json \
    '{ schema: "https://infrashift.io/attestation/package-verification/v1",
       subject: { leg: $leg, arch: $arch },
       repository: { id: $repo, baseurl: $url, gpgcheck: true, repo_gpgcheck: true },
       key: { path: $key, fingerprint: $fpr, sha256: $sha, keyId: $kid },
       packages: { version: $ver, versionRelease: $evr, pinned: $pinned,
                   verified_nevras: $pv[0].verified_nevras, signatures: $pv[0].signatures },
       verification: { performed: true, tool: "rpm -q (inside the built image)" } }' \
    > "$EVIDENCE/package-verification.json"
fi

# ---------------------------------------------------------------------------
# 6n. Native verification (native kind). Hash our binary in the pushed image:
#     the change detector of ADR-004. There is no vendor comparison; see
#     ADR-010. The archive check ran before the build (step 2n).
# ---------------------------------------------------------------------------
if [[ "$KIND" == native && "$NATIVE_LANG" == python ]]; then
  # Ask the venv's own interpreter, inside the pushed image, which
  # distributions it sees, normalised as python-lock.sh normalises the lock.
  # The venv was created --without-pip, so the two sets must be equal.
  CTR=$(buildah from --pull=missing "${DEST_REPO}:${DEST_TAG}")
  VERIFIED=$(buildah run "$CTR" -- "${VENV}/bin/python" -I -c '
import importlib.metadata as m, json, re
print(json.dumps(sorted(re.sub(r"[-_.]+", "-", d.metadata["Name"]).lower() + "==" + d.version for d in m.distributions())))') \
    || { buildah rm "$CTR" >/dev/null 2>&1 || true; fail "the venv interpreter in the image could not list its distributions"; }
  IMG_LOCK_SHA=$(buildah run "$CTR" -- sha256sum "${VENV}/requirements.txt" | cut -d' ' -f1)
  buildah rm "$CTR" >/dev/null
  [[ "$IMG_LOCK_SHA" == "$LOCK_SHA" ]] || fail "the lock in the image has sha256 ${IMG_LOCK_SHA}; versions.json pins ${LOCK_SHA}"
  MISSING=$(jq -rn --argjson l "$LOCKED" --argjson v "$VERIFIED" '$l - $v | join(" ")')
  EXTRA=$(jq -rn --argjson l "$LOCKED" --argjson v "$VERIFIED" '$v - $l | join(" ")')
  [[ -z "$MISSING" ]] || fail "the venv does not hold the locked distribution(s): ${MISSING}"
  [[ -z "$EXTRA" ]]   || fail "the venv holds distribution(s) the lock does not pin: ${EXTRA}"
  echo "native python: ${LOCK_PATH} sha256=${LOCK_SHA}; the venv holds exactly its $(jq length <<<"$LOCKED") distributions"
  jq -n --arg leg "$LEG" --arg arch "$ARCH" \
        --arg path "$LOCK_PATH" --arg sha "$LOCK_SHA" --arg venv "$VENV" \
        --arg dist "$PY_DIST" --arg ver "$SRC_VERSION" --arg url "$SRC_URL" \
        --arg bimg "$BUILDER_IMG" --arg bdig "$BUILDER_DIGEST" \
        --argjson pkgs "$(printf '%s\n' "${BUILD_PKGS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
        --argjson rpkgs "$(printf '%s\n' "${RUNTIME_PKGS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
        --argjson locked "$LOCKED" --argjson verified "$VERIFIED" \
    '{ schema: "https://infrashift.io/attestation/native-verification/v1",
       subject: { leg: $leg, arch: $arch },
       language: "python",
       lock: { path: $path, sha256: $sha, distributions: $locked,
               install: "pip install --require-hashes --no-deps --only-binary=:all: into a venv created --without-pip" },
       release: { distribution: $dist, version: $ver, projectUrl: $url },
       venv: $venv,
       builder: { image: $bimg, digest: $bdig, packages: $pkgs,
                  note: "Installed by name from the Red Hat signed UBI repositories (gpgcheck=1). The builder stage is not shipped." },
       runtimePackages: $rpkgs,
       verified_distributions: $verified,
       comparison: { performed: false, gating: false,
                     note: "NATIVE BUILD, python. No vendor image comparison. The lock pins the bytes of every wheel; the wheels are binaries that their PyPI publishers built (ADR-010)." },
       verification: { performed: true, tool: "importlib.metadata of the venv interpreter, inside the pushed image" } }' \
    > "$EVIDENCE/native-verification.json"
elif [[ "$KIND" == native ]]; then
  OURS=$(./scripts/binary-crosscheck.sh --ours-only "${DEST_REPO}:${DEST_TAG}" "$INSTALL_PATH")
  [[ "$OURS" =~ ^[0-9a-f]{64}$ ]] || fail "native binary hash is malformed: '${OURS}'"
  echo "native: ${INSTALL_PATH} sha256=${OURS}; archive ${ARCHIVE_SHA:0:12} matches commit ${SRC_REF:0:12}"
  jq -n --arg leg "$LEG" --arg arch "$ARCH" --arg lang "$NATIVE_LANG" \
        --arg srcurl "$SRC_URL" --arg srcref "$SRC_REF" --arg srcver "$SRC_VERSION" \
        --arg bimg "$BUILDER_IMG" --arg bdig "$BUILDER_DIGEST" \
        --argjson pkgs "$(printf '%s\n' "${BUILD_PKGS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))')" \
        --arg hsrc "$ARCHIVE_SRC" --slurpfile ac /tmp/archive-check.json \
        --arg path "$INSTALL_PATH" --arg ours "$OURS" \
    '{ schema: "https://infrashift.io/attestation/native-verification/v1",
       subject: { leg: $leg, arch: $arch },
       language: $lang,
       source: { url: $srcurl, commit: $srcref, ref: $srcver },
       archive: { url: $ac[0].url, sha256: $ac[0].sha256, hashSource: $hsrc,
                  tree_match: $ac[0].tree_match, files: $ac[0].files },
       builder: { image: $bimg, digest: $bdig, packages: $pkgs,
                  note: "Installed by name from the Red Hat signed UBI repositories (gpgcheck=1). The builder stage is not shipped." },
       builtFromSource: { path: $path, sha256: $ours },
       comparison: { performed: false, gating: false,
                     note: "NATIVE BUILD. No vendor binary comparison: the vendor builds on another distribution with another compiler and glibc, so a mismatch is certain. The hash of our binary is a change detector over time (ADR-004, ADR-010)." },
       verification: { performed: true, tool: "scripts/fetch-archive.sh, scripts/binary-crosscheck.sh --ours-only" } }' \
    > "$EVIDENCE/native-verification.json"
fi

if [[ "$KIND" == build ]]; then
# ---------------------------------------------------------------------------
# 6. Dual-provenance cross-check.
#
# Mount, don't run: the vendor's distroless and Dapr images have no shell, so
# `buildah run` would fail on the reference side. One mechanism for both.
# The reference is pinned by PER-PLATFORM digest, never the index digest --
# Dapr's index contains windows/amd64 rows and extraction must not depend on
# how buildah resolves a manifest list on the runner.
#
# THE OUTCOME IS NOT A GATE. Go builds are rarely bit-reproducible; a mismatch
# is the expected result. See docs/build-track/dual-provenance.md.
#
# `mode` is written on BOTH paths. The review actor compares it with the mode
# versions.json declares (PROVENANCE_MODE_MISMATCH); an absent one denies.
# ---------------------------------------------------------------------------
if [[ "$XC_MODE" == "first-party" ]]; then
  # No vendor binary exists. Hash ours only, and record that no comparison
  # was made and why. The hash is still the ADR-004 change detector.
  OURS=$(./scripts/binary-crosscheck.sh --ours-only "${DEST_REPO}:${DEST_TAG}" "$INSTALL_PATH")
  [[ "$OURS" =~ ^[0-9a-f]{64}$ ]] || fail "first-party hash is malformed: '${OURS}'"
  echo "first-party: ours=${OURS} (no vendor binary exists)"

  jq -n --arg leg "$LEG" --arg arch "$ARCH" --arg ours "$OURS" \
        --arg reason "$FP_REASON" --arg src "$SRC_URL" \
    '{ schema: "https://infrashift.io/attestation/binary-crosscheck/v1",
       mode: "first-party",
       subject: { leg: $leg, arch: $arch },
       builtFromSource: { sha256: $ours },
       firstParty: { noVendorBinary: true, reason: $reason, sourceUrl: $src },
       comparison: { performed: false, gating: false,
                     note: "FIRST-PARTY BUILD. No vendor binary exists, so nothing was compared. versions.json declares this for a source under https://github.com/infrashift/, and the review actor re-derives the declaration from the checked-out versions.json. The hash of our binary is a change detector over time." } }' \
    > "$EVIDENCE/crosscheck.json"

  XC_DEPS='[]'
  XC_BYPRODUCTS=$(jq -cn --arg ours "$OURS" \
    '[ { name: "binary/built-from-source", digest: { sha256: $ours },
         annotations: { provenanceMode: "first-party", vendorReference: "none" } } ]')
else
read -r OURS THEIRS < <(./scripts/binary-crosscheck.sh \
  "${DEST_REPO}:${DEST_TAG}" "$INSTALL_PATH" "${XC_IMG}@${XC_DIGEST}" "$XC_BINPATH")

# Never compare unvalidated values: two empty strings are equal, and that would
# record a MATCH for a cross-check that never ran.
for v in "$OURS" "$THEIRS"; do
  [[ "$v" =~ ^[0-9a-f]{64}$ ]] || fail "cross-check returned a malformed sha256: '${v}'"
done
MATCH=false; [[ "$OURS" == "$THEIRS" ]] && MATCH=true
echo "cross-check: ours=${OURS} theirs=${THEIRS} match=${MATCH} tier=${XC_TIER}"

jq -n --arg leg "$LEG" --arg arch "$ARCH" --arg ours "$OURS" --arg theirs "$THEIRS" \
      --arg xcimg "$XC_IMG" --arg xcdig "$XC_DIGEST" --arg tier "$XC_TIER" \
      --argjson match "$MATCH" \
  '{ schema: "https://infrashift.io/attestation/binary-crosscheck/v1",
     mode: "vendor-crosscheck",
     subject: { leg: $leg, arch: $arch },
     builtFromSource: { sha256: $ours },
     upstreamReference: { uri: $xcimg, digest: $xcdig, sha256: $theirs, trustClass: "none",
                          trustNote: "Pinned by digest. The vendor signature is not verifiable (Cert:false/Chain:false, no published public key), so we do not claim to have verified it." },
     comparison: { match: $match, gating: false, reproducibilityTier: $tier,
                   note: "OBSERVATION, NOT A GATE. A mismatch is expected: Go embeds build paths, toolchain patch version and module resolution state, and only the flag-matched tier replicates upstream flags closely enough for a match to be realistic." } }' \
  > "$EVIDENCE/crosscheck.json"

XC_DEPS=$(jq -cn --arg xcimg "$XC_IMG" --arg xcdig "${XC_DIGEST#sha256:}" \
  '[ { uri: $xcimg, digest: { sha256: $xcdig },
       annotations: { role: "crosscheck-reference", trustClass: "none", verified: false,
                      note: "Pinned by digest; signature not verifiable. Contributes no bits to the output image." } } ]')
XC_BYPRODUCTS=$(jq -cn --arg ours "$OURS" --arg theirs "$THEIRS" --arg tier "$XC_TIER" --argjson match "$MATCH" \
  '[ { name: "binary/built-from-source",  digest: { sha256: $ours } },
     { name: "binary/upstream-reference", digest: { sha256: $theirs },
       annotations: { match: $match, gating: false, reproducibilityTier: $tier } } ]')
fi
fi

# ---------------------------------------------------------------------------
# 7. Scan the local OCI copy (identical bits to what was pushed).
# ---------------------------------------------------------------------------
SLUG="linux-${ARCH}"
syft  "oci-dir:./oci-image" -o "spdx-json=$EVIDENCE/sbom-${SLUG}.json" -q
grype "oci-dir:./oci-image" -o json > "$EVIDENCE/cve-${SLUG}.json" 2>/dev/null

# ---------------------------------------------------------------------------
# 8. subject.json -- same contract as the mirror track. is_index:false and a
#    single-element platforms[] let review.yml use ONE code path for both.
# ---------------------------------------------------------------------------
jq -n --arg leg "$LEG" --arg svc "$SERVICE" --arg var "$VARIANT" --arg tc "$TRUST_CLASS" \
      --arg repo "$DEST_REPO" --arg tag "$DEST_TAG" --arg dig "$PUSHED" \
      --arg enf "$ENFORCEMENT" --arg arch "$ARCH" --arg slug "$SLUG" --arg cu "$CONFIG_USER" \
      --argjson labels "$LABELS" \
  --arg kind "$KIND" \
  '{ kind: "build", image_kind: $kind, leg: $leg, service: $svc, variant: $var, trust_class: $tc,
     enforcement: $enf, config_user: $cu, labels: $labels,
     subject: { repository: $repo, tag: $tag, digest: $dig,
                media_type: "application/vnd.oci.image.manifest.v1+json", is_index: false },
     platforms: [ { platform: ("linux/" + $arch), slug: $slug, child_digest: $dig,
                    sbom: ("sbom-" + $slug + ".json"), cve: ("cve-" + $slug + ".json") } ],
     manifest_group: $leg }' > "$EVIDENCE/subject.json"

if [[ "$KIND" == native && "$NATIVE_LANG" == python ]]; then
# ---------------------------------------------------------------------------
# 9n-python. SLSA provenance, native python. The pinned input is the lock:
#     externalParameters.lock. Index 0 is the base by contract; the builder,
#     the lock and one entry per locked distribution follow, by role.
# ---------------------------------------------------------------------------
jq -n \
  --arg leg "$LEG" --arg arch "$ARCH" --arg cf "$CONTAINERFILE" \
  --arg recipe "git+${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}" \
  --arg recipesha "${GITHUB_SHA:-unknown}" \
  --arg out "${DEST_REPO}@${PUSHED}" --arg outdig "${PUSHED#sha256:}" \
  --arg baseimg "$BASE_IMG" --arg basedig "${BASE_DIGEST#sha256:}" \
  --arg bimg "$BUILDER_IMG" --arg bdig "${BUILDER_DIGEST#sha256:}" \
  --arg lpath "$LOCK_PATH" --arg lsha "$LOCK_SHA" \
  --arg dist "$PY_DIST" --arg ver "$SRC_VERSION" --arg url "$SRC_URL" \
  --arg run "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-0}" \
  --argjson native "$(jq -c '.native' <<<"$IMG")" \
  --argjson locked "$LOCKED" \
  '{ buildDefinition: {
       buildType: "https://github.com/infrashift/trusted-service-containers/build/native/v1",
       externalParameters: {
         lock: { uri: ($recipe + "#" + $lpath), digest: { sha256: $lsha },
                 annotations: { distribution: $dist, version: $ver, projectUrl: $url } },
         leg: $leg, arch: $arch },
       internalParameters: {
         recipe: { uri: $recipe, digest: { sha1: $recipesha } },
         containerfile: $cf, platform: ("linux/" + $arch),
         native: $native,
         output: { uri: $out, digest: { sha256: $outdig } } },
       resolvedDependencies: (
         [ { uri: $baseimg, digest: { sha256: $basedig }, annotations: { role: "runtime-base" } },
           { uri: $bimg,    digest: { sha256: $bdig },    annotations: { role: "builder" } },
           { uri: ($recipe + "#" + $lpath), digest: { sha256: $lsha }, annotations: { role: "python-lock" } } ]
         + [ $locked[] | split("==") | { uri: ("pkg:pypi/" + .[0] + "@" + .[1]),
                                          annotations: { role: "python-distribution", pinnedBy: "python-lock" } } ]) },
     runDetails: {
       builder: { id: $run },
       byproducts: [ { name: "python/venv", annotations: { distributions: ($locked | length) } } ] } }' \
  > "$EVIDENCE/provenance.json"
elif [[ "$KIND" == native ]]; then
# ---------------------------------------------------------------------------
# 9n. SLSA provenance, native kind. The source commit is
#     externalParameters.source, as on the build track. Index 0 is the base by
#     contract; the builder and the release archive follow, by role.
# ---------------------------------------------------------------------------
jq -n \
  --arg srcurl "$SRC_URL" --arg srcref "$SRC_REF" --arg srcver "$SRC_VERSION" \
  --arg leg "$LEG" --arg arch "$ARCH" --arg cf "$CONTAINERFILE" \
  --arg recipe "git+${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}" \
  --arg recipesha "${GITHUB_SHA:-unknown}" \
  --arg out "${DEST_REPO}@${PUSHED}" --arg outdig "${PUSHED#sha256:}" \
  --arg baseimg "$BASE_IMG" --arg basedig "${BASE_DIGEST#sha256:}" \
  --arg bimg "$BUILDER_IMG" --arg bdig "${BUILDER_DIGEST#sha256:}" \
  --arg aurl "$ARCHIVE_URL" --arg asha "$ARCHIVE_SHA" \
  --arg run "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-0}" \
  --argjson native "$(jq -c '.native' <<<"$IMG")" \
  --slurpfile nv "$EVIDENCE/native-verification.json" \
  '{ buildDefinition: {
       buildType: "https://github.com/infrashift/trusted-service-containers/build/native/v1",
       externalParameters: {
         source: { uri: ("git+" + $srcurl), digest: { gitCommit: $srcref },
                   annotations: { ref: $srcver } },
         leg: $leg, arch: $arch },
       internalParameters: {
         recipe: { uri: $recipe, digest: { sha1: $recipesha } },
         containerfile: $cf, platform: ("linux/" + $arch),
         native: $native,
         sourceDateBasis: "committer-date-of-pinned-commit",
         output: { uri: $out, digest: { sha256: $outdig } } },
       resolvedDependencies: [
         { uri: $baseimg, digest: { sha256: $basedig }, annotations: { role: "runtime-base" } },
         { uri: $bimg,    digest: { sha256: $bdig },    annotations: { role: "builder" } },
         { uri: $aurl,    digest: { sha256: $asha },
           annotations: { role: "source-archive", treeMatchesCommit: $nv[0].archive.tree_match } } ] },
     runDetails: {
       builder: { id: $run },
       byproducts: [ { name: "binary/built-from-source", digest: { sha256: $nv[0].builtFromSource.sha256 },
                       annotations: { path: $nv[0].builtFromSource.path, vendorReference: "none" } } ] } }' \
  > "$EVIDENCE/provenance.json"
elif [[ "$KIND" == package ]]; then
# ---------------------------------------------------------------------------
# 9p. SLSA provenance, package kind. The materials are the base image, the
#     repository and its key, and one entry per pinned RPM. Index 0 is the base
#     by contract, as on the build track.
# ---------------------------------------------------------------------------
jq -n \
  --arg leg "$LEG" --arg arch "$ARCH" --arg cf "$CONTAINERFILE" \
  --arg recipe "git+${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}" \
  --arg recipesha "${GITHUB_SHA:-unknown}" \
  --arg out "${DEST_REPO}@${PUSHED}" --arg outdig "${PUSHED#sha256:}" \
  --arg baseimg "$BASE_IMG" --arg basedig "${BASE_DIGEST#sha256:}" \
  --arg repo "$PKG_REPO_ID" --arg url "$PKG_BASEURL" --arg key "$PKG_KEY" \
  --arg fpr "$PKG_KEY_FPR" --arg sha "$PKG_KEY_SHA" --arg ver "$PKG_VERSION" --arg evr "$PKG_EVR" \
  --arg run "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-0}" \
  --slurpfile pv "$EVIDENCE/package-verification.json" \
  '{ buildDefinition: {
       buildType: "https://github.com/infrashift/trusted-service-containers/build/rpm-package/v1",
       externalParameters: {
         packages: { repository: { id: $repo, baseurl: $url },
                     version: $ver, versionRelease: $evr, nevras: $pv[0].packages.pinned },
         leg: $leg, arch: $arch },
       internalParameters: {
         recipe: { uri: $recipe, digest: { sha1: $recipesha } },
         containerfile: $cf, platform: ("linux/" + $arch),
         gpgcheck: true, repo_gpgcheck: true,
         output: { uri: $out, digest: { sha256: $outdig } } },
       resolvedDependencies: (
         [ { uri: $baseimg, digest: { sha256: $basedig }, annotations: { role: "runtime-base" } },
           { uri: $key, digest: { sha256: $sha },
             annotations: { role: "package-signing-key", fingerprint: $fpr } } ]
         + [ $pv[0].packages.pinned[] | { uri: ("rpm:" + $repo + "/" + .),
                                          annotations: { role: "package", signedBy: $fpr } } ]) },
     runDetails: {
       builder: { id: $run },
       byproducts: [ { name: "packages/rpm-database",
                       annotations: { packages: ($pv[0].packages.signatures | length),
                                      note: "Every installed package and the key ID of its header signature, from rpm -qa inside the image. See package-verification.json." } } ] } }' \
  > "$EVIDENCE/provenance.json"
else
# ---------------------------------------------------------------------------
# 9. SLSA provenance. Unlike the mirror track this has REAL materials: the
#    upstream project at a specific commit is externalParameters.source, our own
#    repo moves to internalParameters.recipe (which is what it is), and
#    resolvedDependencies grows to four role-annotated entries (three for a
#    first-party build, which has no crosscheck reference). Index 0 is the
#    base by contract; consume the rest by annotations.role, never by index.
#
#    The OIDC token is deliberately NOT embedded: the reference publishes a live
#    sigstore-audience token in internalParameters.oidcToken as a public
#    attestation, and the policy's ATTESTATION_PREDICATE_LEAK rule denies it.
# ---------------------------------------------------------------------------
jq -n \
  --arg srcurl "$SRC_URL" --arg srcref "$SRC_REF" --arg srcver "$SRC_VERSION" \
  --arg leg "$LEG" --arg arch "$ARCH" --arg cf "$CONTAINERFILE" \
  --arg recipe "git+${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}" \
  --arg recipesha "${GITHUB_SHA:-unknown}" \
  --arg out "${DEST_REPO}@${PUSHED}" --arg outdig "${PUSHED#sha256:}" \
  --arg baseimg "$BASE_IMG" --arg basedig "${BASE_DIGEST#sha256:}" \
  --arg caimg "$CA_IMG" --arg cadig "${CA_DIGEST#sha256:}" \
  --arg tcimg "$TC_IMG" --arg tcdig "${TC_DIGEST#sha256:}" \
  --arg mode "$XC_MODE" --argjson xcdeps "$XC_DEPS" --argjson byproducts "$XC_BYPRODUCTS" \
  --arg run "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-0}" \
  --argjson build "$(jq -c '.build' <<<"$IMG")" \
  '{ buildDefinition: {
       buildType: "https://github.com/infrashift/trusted-service-containers/build/go-service/v1",
       externalParameters: {
         source: { uri: ("git+" + $srcurl), digest: { gitCommit: $srcref },
                   annotations: { ref: $srcver } },
         leg: $leg, arch: $arch },
       internalParameters: {
         recipe: { uri: $recipe, digest: { sha1: $recipesha } },
         containerfile: $cf, platform: ("linux/" + $arch),
         goBuild: $build,
         provenanceMode: $mode,
         sourceDateBasis: "committer-date-of-pinned-commit",
         output: { uri: $out, digest: { sha256: $outdig } } },
       resolvedDependencies: ([
         { uri: $baseimg, digest: { sha256: $basedig }, annotations: { role: "runtime-base" } },
         { uri: $caimg,   digest: { sha256: $cadig },
           annotations: { role: "ca-trust-donor", paths: ["/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"] } },
         { uri: $tcimg,   digest: { sha256: $tcdig },
           annotations: { role: "toolchain", paths: ["/usr/share/zoneinfo"] } } ] + $xcdeps) },
     runDetails: {
       builder: { id: $run },
       byproducts: $byproducts } }' \
  > "$EVIDENCE/provenance.json"
fi

# ---------------------------------------------------------------------------
# 10. Sign, checksum, attest. No --replace, per the mirror-track rationale.
# ---------------------------------------------------------------------------
cd "$EVIDENCE"
for f in *.json; do
  cosign sign-blob --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY \
    --output-signature "${f}.sig" "$f" >/dev/null
done
sha256sum ./*.json ./*.sig > checksums.sha256
cosign sign-blob --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY \
  --output-signature checksums.sha256.sig checksums.sha256 >/dev/null
cd ..

attest() { cosign attest --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY "$@" >/dev/null; }
URI="${DEST_REPO}@${PUSHED}"
attest --type slsaprovenance1 --predicate "$EVIDENCE/provenance.json"            "$URI"
attest --type spdxjson       --predicate "$EVIDENCE/sbom-${SLUG}.json"           "$URI"
attest --type vuln           --predicate "$EVIDENCE/cve-${SLUG}.json"            "$URI"
attest --type https://infrashift.io/attestation/upstream-verification/v1 \
       --predicate "$EVIDENCE/upstream-verification.json" "$URI"
if [[ "$KIND" == build ]]; then
  attest --type https://infrashift.io/attestation/binary-crosscheck/v1 \
         --predicate "$EVIDENCE/crosscheck.json" "$URI"
elif [[ "$KIND" == native ]]; then
  attest --type https://infrashift.io/attestation/native-verification/v1 \
         --predicate "$EVIDENCE/native-verification.json" "$URI"
else
  attest --type https://infrashift.io/attestation/package-verification/v1 \
         --predicate "$EVIDENCE/package-verification.json" "$URI"
fi

echo "OK: ${LEG} (${ARCH}) built -> ${URI}"
