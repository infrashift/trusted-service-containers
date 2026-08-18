#!/usr/bin/env bash
# Build one {service, arch} leg from pinned source onto our trusted ubi9-micro,
# cross-check the binary against the vendor's official image, scan, sign, attest.
#
# Required env: SERVICE VARIANT LEG ARCH TRUST_CLASS PR_NUM GITHUB_REPOSITORY
#               GITHUB_SHA COSIGN_PRIVATE_KEY COSIGN_PASSWORD
set -euo pipefail

: "${SERVICE:?}" "${LEG:?}" "${ARCH:?}" "${PR_NUM:?}" "${GITHUB_REPOSITORY:?}"
VARIANT="${VARIANT:-runtime}"
TRUST_CLASS="${TRUST_CLASS:-internal}"

EVIDENCE=evidence
mkdir -p "$EVIDENCE"

# ---------------------------------------------------------------------------
# 1. Resolve every input from versions.json. jq --arg, never string concat.
# ---------------------------------------------------------------------------
IMG=$(jq -ce --arg s "$SERVICE" '.images[$s]' versions.json)
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

BASE_KEY=$(jq -r '.base'     <<<"$IMG")
CA_KEY=$(jq   -r '.caSource' <<<"$IMG")
TC_KEY=$(jq   -r '.toolchain' <<<"$IMG")
ENFORCEMENT=$(jq -r '.enforcement' <<<"$IMG")
CONTAINERFILE=$(jq -r '.containerfile' <<<"$IMG")

lookup() { jq -r --arg k "$1" --arg a "$ARCH" "$2" versions.json; }
BASE_IMG=$(lookup "$BASE_KEY" '.bases[$k].image')
BASE_DIGEST=$(lookup "$BASE_KEY" '.bases[$k][$a].digest')
BASE_KEYFILE=$(lookup "$BASE_KEY" '.bases[$k].verifyKey')
CA_IMG=$(lookup "$CA_KEY" '.bases[$k].image')
CA_DIGEST=$(lookup "$CA_KEY" '.bases[$k][$a].digest')
TC_IMG=$(lookup "$TC_KEY" '.toolchains[$k].image')
TC_DIGEST=$(lookup "$TC_KEY" '.toolchains[$k][$a].digest')

XC_IMG=$(jq -r '.crosscheck.image' <<<"$IMG")
XC_BINPATH=$(jq -r '.crosscheck.binaryPath' <<<"$IMG")
XC_TIER=$(jq -r '.crosscheck.reproducibilityTier' <<<"$IMG")
XC_DIGEST=$(jq -r --arg a "$ARCH" '.crosscheck[$a].digest' <<<"$IMG")

INSTALL_PATH=$(jq -r '.build.installPath' <<<"$IMG")

for v in SRC_URL SRC_REF BASE_IMG BASE_DIGEST CA_DIGEST TC_DIGEST XC_DIGEST INSTALL_PATH; do
  val="${!v}"
  [[ -n "$val" && "$val" != "null" ]] || { echo "::error::${v} unresolved for ${LEG}"; exit 1; }
done
for d in "$BASE_DIGEST" "$CA_DIGEST" "$TC_DIGEST" "$XC_DIGEST"; do
  [[ "$d" =~ ^sha256:[a-f0-9]{64}$ ]] || { echo "::error::malformed digest: ${d}"; exit 1; }
done

DEST_REPO="ghcr.io/${GITHUB_REPOSITORY}/development/${SERVICE}"
DEST_TAG="pr-${PR_NUM}-${SRC_VERSION}-${ARCH}"

# ---------------------------------------------------------------------------
# 2. Fetch the source at the pinned COMMIT.
# ---------------------------------------------------------------------------
./scripts/fetch-source.sh "$SERVICE" "$SRC_URL" "$SRC_REF" "$SRC_VERSION"

# Committer date, NOT `date -u`. Wall-clock time guarantees a different binary
# on every rerun, which destroys any chance of self-consistency and makes the
# cross-check meaningless even against ourselves.
SOURCE_DATE=$(cat "src/.meta/${SERVICE}.source-date")
SOURCE_GIT_VERSION=$(cat "src/.meta/${SERVICE}.source-git-version")

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
jq -n --arg tc "$TRUST_CLASS" --arg res "$UPSTREAM_RESULT" --arg reason "$UPSTREAM_REASON" \
      --arg uri "$BASE_IMG" --arg dig "$BASE_DIGEST" --arg key "$BASE_KEYFILE" --arg arch "$ARCH" \
  '{ trust_class: $tc, result: $res, reason: $reason,
     subject: ($uri + "@" + $dig),
     verified_with: $key,
     keyring: { path: $key, pinned_sha256: "", fetched_sha256: "" },
     upstream: { role: "base-image", uri: $uri, digest: $dig, arch: $arch,
                 pinned_in: "versions.json#/bases" },
     attestations: { sbom: "present", provenance: "present", vex: "absent" },
     ca_trust: { injected: true,
                 reason: "ubi9-micro ships no CA trust bundle (verified by layer listing); every service here makes outbound TLS calls" } }' \
  > "$EVIDENCE/upstream-verification.json"

# ---------------------------------------------------------------------------
# 4. Build.
# ---------------------------------------------------------------------------
buildah bud \
  --platform "linux/${ARCH}" \
  --build-arg UPSTREAM_BASE="$BASE_IMG"     --build-arg UPSTREAM_DIGEST="$BASE_DIGEST" \
  --build-arg CA_BASE="$CA_IMG"             --build-arg CA_DIGEST="$CA_DIGEST" \
  --build-arg TOOLCHAIN_BASE="$TC_IMG"      --build-arg TOOLCHAIN_DIGEST="$TC_DIGEST" \
  --build-arg SOURCE_URL="$SRC_URL"         --build-arg SOURCE_VERSION="$SRC_VERSION" \
  --build-arg SOURCE_REF="$SRC_REF"         --build-arg SOURCE_SHORT_REF="$SRC_SHORT" \
  --build-arg SOURCE_DATE="$SOURCE_DATE"    --build-arg SOURCE_GIT_VERSION="$SOURCE_GIT_VERSION" \
  --build-arg CROSSCHECK_IMAGE="$XC_IMG"    --build-arg CROSSCHECK_DIGEST="$XC_DIGEST" \
  --build-arg IMAGE_VERSION="$SRC_VERSION"  --build-arg GIT_COMMIT="${GITHUB_SHA:-unknown}" \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --build-arg TARGETARCH="$ARCH" \
  -t "${DEST_REPO}:${DEST_TAG}" -f "$CONTAINERFILE" .

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
# ---------------------------------------------------------------------------
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
     subject: { leg: $leg, arch: $arch },
     builtFromSource: { sha256: $ours },
     upstreamReference: { uri: $xcimg, digest: $xcdig, sha256: $theirs, trustClass: "none",
                          trustNote: "Pinned by digest. The vendor signature is not verifiable (Cert:false/Chain:false, no published public key), so we do not claim to have verified it." },
     comparison: { match: $match, gating: false, reproducibilityTier: $tier,
                   note: "OBSERVATION, NOT A GATE. A mismatch is expected: Go embeds build paths, toolchain patch version and module resolution state, and only the flag-matched tier replicates upstream flags closely enough for a match to be realistic." } }' \
  > "$EVIDENCE/crosscheck.json"

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
  '{ kind: "build", leg: $leg, service: $svc, variant: $var, trust_class: $tc,
     enforcement: $enf, config_user: $cu, labels: $labels,
     subject: { repository: $repo, tag: $tag, digest: $dig,
                media_type: "application/vnd.oci.image.manifest.v1+json", is_index: false },
     platforms: [ { platform: ("linux/" + $arch), slug: $slug, child_digest: $dig,
                    sbom: ("sbom-" + $slug + ".json"), cve: ("cve-" + $slug + ".json") } ],
     manifest_group: $leg }' > "$EVIDENCE/subject.json"

# ---------------------------------------------------------------------------
# 9. SLSA provenance. Unlike the mirror track this has REAL materials: the
#    upstream project at a specific commit is externalParameters.source, our own
#    repo moves to internalParameters.recipe (which is what it is), and
#    resolvedDependencies grows to four role-annotated entries. Index 0 is the
#    base by contract; consume 1..3 by annotations.role, never by index.
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
  --arg xcimg "$XC_IMG" --arg xcdig "${XC_DIGEST#sha256:}" \
  --arg ours "$OURS" --arg theirs "$THEIRS" --arg tier "$XC_TIER" --argjson match "$MATCH" \
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
         sourceDateBasis: "committer-date-of-pinned-commit",
         output: { uri: $out, digest: { sha256: $outdig } } },
       resolvedDependencies: [
         { uri: $baseimg, digest: { sha256: $basedig }, annotations: { role: "runtime-base" } },
         { uri: $caimg,   digest: { sha256: $cadig },
           annotations: { role: "ca-trust-donor", paths: ["/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"] } },
         { uri: $tcimg,   digest: { sha256: $tcdig },
           annotations: { role: "toolchain", paths: ["/usr/share/zoneinfo"] } },
         { uri: $xcimg,   digest: { sha256: $xcdig },
           annotations: { role: "crosscheck-reference", trustClass: "none", verified: false,
                          note: "Pinned by digest; signature not verifiable. Contributes no bits to the output image." } } ] },
     runDetails: {
       builder: { id: $run },
       byproducts: [
         { name: "binary/built-from-source",  digest: { sha256: $ours } },
         { name: "binary/upstream-reference", digest: { sha256: $theirs },
           annotations: { match: $match, gating: false, reproducibilityTier: $tier } } ] } }' \
  > "$EVIDENCE/provenance.json"

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
attest --type https://infrashift.io/attestation/binary-crosscheck/v1 \
       --predicate "$EVIDENCE/crosscheck.json" "$URI"

echo "OK: ${LEG} (${ARCH}) built -> ${URI}"
