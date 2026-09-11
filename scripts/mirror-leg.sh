#!/usr/bin/env bash
# Mirror one {service, variant} leg: verify upstream trust, copy the whole
# index (or the bare single-platform manifest, for upstreams that publish no
# index) by digest, scan every platform, sign and attest.
#
# Required env: SERVICE VARIANT LEG TRUST_CLASS PR_NUM GITHUB_REPOSITORY
#               COSIGN_PRIVATE_KEY COSIGN_PASSWORD
set -euo pipefail

: "${SERVICE:?}" "${VARIANT:?}" "${LEG:?}" "${TRUST_CLASS:?}" "${PR_NUM:?}" "${GITHUB_REPOSITORY:?}"

EVIDENCE=evidence
mkdir -p "$EVIDENCE"

# ---------------------------------------------------------------------------
# 1. Load the pin. Untrusted keys go through jq --arg, never string concat.
# ---------------------------------------------------------------------------
IMG=$(jq -ce --arg s "$SERVICE" '.images[$s]' versions.json)
VAR=$(jq -ce --arg v "$VARIANT" '.variants[$v]' <<<"$IMG")

SRC_REPO=$(jq -r '.upstreamRepo' <<<"$IMG")
KEYRING=$(jq -r '.keyring // ""' <<<"$IMG")
REQ_PREDS=$(jq -c '.requiredPredicates // []' <<<"$IMG")
DECLARED_PLATFORMS=$(jq -c '.platforms' <<<"$IMG")
ENFORCEMENT=$(jq -r '.enforcement' <<<"$IMG")

SRC_TAG=$(jq -r '.tag' <<<"$VAR")
TRACK=$(jq -r '.track' <<<"$VAR")
PIN=$(jq -r '.digest' <<<"$VAR")

# The one field concatenated into a registry reference. Assert it hard.
[[ "$PIN" =~ ^sha256:[a-f0-9]{64}$ ]] || { echo "::error::malformed pin for ${LEG}: ${PIN}"; exit 1; }

if [[ "$PIN" == "sha256:$(printf '0%.0s' {1..64})" ]]; then
  echo "::error::${LEG} still carries a placeholder digest. Resolve it with an authenticated dhi.io login -- see SETUP-ENVIRONMENTS.md step 7."
  exit 1
fi

DEST_REPO="ghcr.io/${GITHUB_REPOSITORY}/development/${SERVICE}"
DEST_TAG="pr-${PR_NUM}-${SRC_TAG}"

echo "leg=${LEG} src=${SRC_REPO}:${SRC_TAG} pin=${PIN} dest=${DEST_REPO}:${DEST_TAG}"

# ---------------------------------------------------------------------------
# 2. Upstream trust verification.
#
# This step runs on EVERY path and writes its JSON unconditionally -- there is
# no `if:` guarding it in the workflow. A skipped step writes nothing; an
# always-run step with a case statement cannot forget. The file is then covered
# by checksums.sha256, so deleting it breaks the evidence chain rather than
# silently passing.
#
# It deliberately does NOT exit non-zero on FAILED. The review actor decides,
# not the build actor: a FAILED result flows into signed evidence, OPA denies
# it, and the image lands in quarantine WITH a permanent signed record of why.
# Exiting here would give a red X and no artifact at all.
# ---------------------------------------------------------------------------
RESULT=failed; REASON=UNSET; VERIFIED=0; PRED_TYPES='[]'
KEYRING_PINNED_SHA=""; KEYRING_FETCHED_SHA=""

case "$TRUST_CLASS" in
  none)
    RESULT=not-applicable
    # nexus3's index DOES carry BuildKit attestation manifests, but they are
    # unsigned in-toto statements: evidence, not trust. Distinct from a vendor
    # who signs with a key they never publish. The reason code preserves that.
    REASON=UNSIGNED_ATTESTATIONS_ONLY
    regctl artifact list --format '{{jsonPretty .}}' "${SRC_REPO}@${PIN}" \
      > "$EVIDENCE/upstream-referrers.json" 2>/dev/null || echo '{}' > "$EVIDENCE/upstream-referrers.json"
    ;;

  dhi)
    [[ -n "$KEYRING" && -f "$KEYRING" ]] || { echo "::error::trust_class=dhi but keyring $KEYRING is missing"; exit 1; }
    KEYRING_PINNED_SHA=$(sha256sum "$KEYRING" | cut -d' ' -f1)
    # Retried: a blip here aborts the leg under `set -e` before the comparison
    # below can run, so a transient failure looks like a mirror failure rather
    # than a network one. Not --retry-all-errors -- a 404 would mean Docker moved
    # the keyring endpoint, which must surface rather than be retried away.
    curl -sSfL --retry 3 --retry-delay 2 --retry-connrefused --max-time 30 \
      -o /tmp/dhi-fetched.pub https://registry.scout.docker.com/keyring/dhi/latest.pub
    KEYRING_FETCHED_SHA=$(sha256sum /tmp/dhi-fetched.pub | cut -d' ' -f1)

    if [[ "$KEYRING_PINNED_SHA" != "$KEYRING_FETCHED_SHA" ]]; then
      # Verify against the COMMITTED copy, always. Reporting the rotation turns
      # a silent trust transfer into a reviewable pull request.
      RESULT=failed; REASON=KEYRING_ROTATED
      echo "::warning::DHI keyring rotated: pinned=${KEYRING_PINNED_SHA} fetched=${KEYRING_FETCHED_SHA}"

    # --- the index signature ------------------------------------------------
    # DHI attaches cosign signatures as OCI 1.1 REFERRERS, not as the legacy
    # sha256-<digest>.sig tag cosign looks for by default, so --experimental-oci11
    # is load-bearing: without it cosign reports "no signatures found" against a
    # correctly signed image. Verified against dhi.io on 2026-08-24; the key
    # embedded in the signature's Rekor bundle is byte-identical to the keyring
    # committed here.
    elif ! cosign verify --key "$KEYRING" --insecure-ignore-tlog=true \
             --experimental-oci11=true "${SRC_REPO}@${PIN}" >/dev/null 2>/tmp/idx.err; then
      RESULT=failed; REASON="INDEX_SIGNATURE_INVALID: $(head -c 300 /tmp/idx.err)"
    else
      VERIFIED=$((VERIFIED + 1))

      # --- the attestations, PER PLATFORM ----------------------------------
      # They hang off the per-platform manifests, not off the index we pin, and
      # they live in the image's own repository -- there is no separate
      # attestation registry, which is what attestationRepo used to assert.
      #
      # Per platform, not once: a predicate present on amd64 and missing on
      # arm64 used to pass, because nothing looked below the index.
      : > /tmp/all-descriptors.json
      FAILED=0
      MISSING_ANY="[]"
      # A dedicated flag, NOT a test of RESULT. RESULT is initialised to
      # "failed" at the top of this script so that any path which forgets to set
      # it denies; that makes `[[ "$RESULT" == failed ]]` true on entry and, used
      # as a guard here, unreachable-success. It shipped that way once: every DHI
      # leg reported result=failed reason=UNSET while every signature verified.
      LEG_ERR=""
      for plat in $(jq -r '.[]' <<<"$DECLARED_PLATFORMS"); do
        child=$(regctl manifest get "${SRC_REPO}@${PIN}" --format '{{json .}}' 2>/dev/null \
          | jq -r --arg p "$plat" '
              [.manifests[]? | select((.platform.os + "/" + .platform.architecture) == $p)][0].digest // empty')
        if [[ -z "$child" ]]; then
          LEG_ERR="PLATFORM_MISSING ${plat}"; FAILED=$((FAILED + 1)); continue
        fi

        # regctl emits `.descriptors[]`. Confirmed against the live registry --
        # it is neither `.manifests` nor `.Manifests`, which an earlier version
        # of this script guessed at and which silently yielded an empty list.
        if ! regctl artifact list "${SRC_REPO}@${child}" --format '{{jsonPretty .}}' \
               > "/tmp/refs-${plat//\//-}.json" 2>/tmp/refs.err; then
          LEG_ERR="REFERRER_LIST_FAILED ${plat}: $(head -c 200 /tmp/refs.err)"
          FAILED=$((FAILED + 1)); continue
        fi

        jq -c --arg p "$plat" '.descriptors[]? | {platform: $p, digest, artifactType,
          predicate: ((.annotations // {})["in-toto.io/predicate-type"] // "")}' \
          "/tmp/refs-${plat//\//-}.json" >> /tmp/all-descriptors.json

        # Every attestation carries its own cosign signature referrer, signed by
        # the same key. Verifying the index alone would leave the attestations
        # unauthenticated.
        while IFS= read -r d; do
          [[ -n "$d" ]] || continue
          if cosign verify --key "$KEYRING" --insecure-ignore-tlog=true \
               --experimental-oci11=true "${SRC_REPO}@${d}" >/dev/null 2>&1; then
            VERIFIED=$((VERIFIED + 1))
          else
            FAILED=$((FAILED + 1))
          fi
        done < <(jq -r '.descriptors[]?.digest // empty' "/tmp/refs-${plat//\//-}.json")

        have=$(jq -c '[.descriptors[]? | (.annotations // {})["in-toto.io/predicate-type"] // .artifactType]
                      | map(select(. != null)) | unique' "/tmp/refs-${plat//\//-}.json")
        miss=$(jq -cn --argjson have "$have" --argjson req "$REQ_PREDS" '$req - $have')
        if [[ "$miss" != "[]" ]]; then
          MISSING_ANY=$(jq -cn --argjson a "$MISSING_ANY" --argjson b "$miss" --arg p "$plat" \
            '$a + ($b | map({platform: $p, predicate: .}))')
        fi
      done

      jq -s '{descriptors: .}' /tmp/all-descriptors.json > "$EVIDENCE/upstream-referrers.json"
      PRED_TYPES=$(jq -c '[.descriptors[]?.predicate] | map(select(. != "")) | unique' "$EVIDENCE/upstream-referrers.json")

      if   [[ -n "$LEG_ERR" ]];         then RESULT=failed; REASON="$LEG_ERR"
      elif [[ "$FAILED" -gt 0 ]];       then RESULT=failed; REASON="SIGNATURE_INVALID (${FAILED} attestation signature(s))"
      elif [[ "$MISSING_ANY" != "[]" ]]; then RESULT=failed; REASON="MISSING_PREDICATES ${MISSING_ANY}"
      elif [[ "$VERIFIED" -le 1 ]];     then RESULT=failed; REASON=NO_ATTESTATIONS
      else RESULT=verified; REASON=OK
      fi
    fi
    ;;

  notation)
    # Notary Project signature (mssql). Verified with `notation` against the
    # COMMITTED root CA, with the signing identity pinned to the vendor's leaf
    # subject: a root alone would trust every certificate Microsoft ever issued
    # under it. The live root is fetched from the vendor's PKI endpoint and
    # compared, exactly as the DHI keyring is, so a rotation arrives as a PR.
    [[ -n "$KEYRING" && -f "$KEYRING" ]] || { echo "::error::trust_class=notation but keyring $KEYRING is missing"; exit 1; }
    NOTATION_IDENTITY=$(jq -r '.notation.trustedIdentity // ""' <<<"$IMG")
    NOTATION_ROOT_URL=$(jq -r '.notation.rootUrl // ""' <<<"$IMG")
    # CN is mandatory: Notary matches x509.subject as an attribute subset, so a
    # CN-less identity admits every leaf the root's CA ever issues.
    [[ "$NOTATION_IDENTITY" == "x509.subject: "* && "$NOTATION_IDENTITY" =~ (^|[\ ,])CN=[^,]+ ]] \
      || { echo "::error::trust_class=notation needs notation.trustedIdentity of the form 'x509.subject: CN=...,O=...'"; exit 1; }
    [[ -n "$NOTATION_ROOT_URL" ]] || { echo "::error::trust_class=notation needs notation.rootUrl"; exit 1; }
    KEYRING_PINNED_SHA=$(sha256sum "$KEYRING" | cut -d' ' -f1)

    regctl artifact list --format '{{jsonPretty .}}' "${SRC_REPO}@${PIN}" \
      > "$EVIDENCE/upstream-referrers.json" 2>/dev/null || echo '{}' > "$EVIDENCE/upstream-referrers.json"

    # Vendors serve roots as DER; the committed copy is PEM. Normalise before
    # comparing so the digest compares like with like. Retried like the DHI
    # keyring fetch, and for the same reason; a 404 still surfaces.
    # Unlike the DHI branch, a fetch failure is named as such and does NOT
    # skip verification: the image is still verified against the committed
    # root (which is what trust rests on), and the policy's NOTATION_ROOT_DRIFT
    # rule still denies on the digest mismatch -- but the evidence then says
    # "endpoint unreachable", not "vendor rotated its root".
    DRIFT=""
    if curl -sSfL --retry 3 --retry-delay 2 --retry-connrefused --max-time 30 \
         -o /tmp/notation-root.bin "$NOTATION_ROOT_URL" \
       && { openssl x509 -inform DER -in /tmp/notation-root.bin -out /tmp/notation-root.pem 2>/dev/null \
            || openssl x509 -inform PEM -in /tmp/notation-root.bin -out /tmp/notation-root.pem; }; then
      KEYRING_FETCHED_SHA=$(sha256sum /tmp/notation-root.pem | cut -d' ' -f1)
      [[ "$KEYRING_PINNED_SHA" == "$KEYRING_FETCHED_SHA" ]] || DRIFT=KEYRING_ROTATED
    else
      KEYRING_FETCHED_SHA="<fetch-failed>"
      DRIFT=ROOT_FETCH_FAILED
    fi
    [[ -z "$DRIFT" ]] || echo "::warning::${DRIFT}: pinned=${KEYRING_PINNED_SHA} fetched=${KEYRING_FETCHED_SHA}"

    {
      # A throwaway notation home: trust store holds ONLY the committed root,
      # and the trust policy is scoped to this one upstream repository.
      NOTATION_HOME=$(mktemp -d)
      mkdir -p "$NOTATION_HOME/notation/truststore/x509/ca/pinned"
      cp "$KEYRING" "$NOTATION_HOME/notation/truststore/x509/ca/pinned/root.pem"
      jq -n --arg scope "$SRC_REPO" --arg id "$NOTATION_IDENTITY" \
        '{version:"1.0", trustPolicies:[{name:"pinned", registryScopes:[$scope],
          signatureVerification:{level:"strict"}, trustStores:["ca:pinned"],
          trustedIdentities:[$id]}]}' > "$NOTATION_HOME/notation/trustpolicy.json"
      cp "$NOTATION_HOME/notation/trustpolicy.json" "$EVIDENCE/notation-trustpolicy.json"
      # Three attempts: a registry connection reset mid-verify was observed
      # against mcr.microsoft.com and would otherwise quarantine the image for
      # a network blip. A genuine signature failure simply fails three times.
      NOTATION_OK=0
      for attempt in 1 2 3; do
        if XDG_CONFIG_HOME="$NOTATION_HOME" notation verify "${SRC_REPO}@${PIN}" > /tmp/notation.out 2>&1; then
          NOTATION_OK=1; break
        fi
        echo "notation verify attempt ${attempt} failed: $(tail -c 200 /tmp/notation.out | tr '\n' ' ')"
        sleep 2
      done
      if [[ "$NOTATION_OK" -eq 1 ]]; then
        RESULT=verified; REASON="OK${DRIFT:+; $DRIFT}"; VERIFIED=1
      else
        RESULT=failed; REASON="NOTATION_VERIFY_FAILED${DRIFT:+ ($DRIFT)}: $(tail -c 300 /tmp/notation.out | tr '\n' ' ')"
      fi
      jq -n --arg out "$(cat /tmp/notation.out)" --arg res "$RESULT" --arg id "$NOTATION_IDENTITY" \
            --arg ver "$(notation version 2>/dev/null | tr '\n' ' ')" \
        '{result:$res, trustedIdentity:$id, notation:$ver, output:$out}' > "$EVIDENCE/notation-verify.json"
      rm -rf "$NOTATION_HOME"
    }
    ;;

  *)
    echo "::error::unknown trust_class '${TRUST_CLASS}' for ${LEG}"; exit 1 ;;
esac

# Attestation presence, as the policy's three-state enum.
att_state() {
  local want="$1"
  if [[ "$TRUST_CLASS" == "none" ]]; then echo "not-applicable"; return; fi
  if jq -e --arg w "$want" '[.descriptors[]? | (.predicate // .artifactType // "")] | any(test($w; "i"))' \
       "$EVIDENCE/upstream-referrers.json" >/dev/null 2>&1; then echo present; else echo absent; fi
}

jq -n --arg tc "$TRUST_CLASS" --arg res "$RESULT" --arg reason "$REASON" \
      --arg src "${SRC_REPO}@${PIN}" --arg attrepo "$SRC_REPO" --arg keyring "$KEYRING" \
      --arg kp "$KEYRING_PINNED_SHA" --arg kf "$KEYRING_FETCHED_SHA" \
      --argjson verified "$VERIFIED" --argjson preds "$PRED_TYPES" --argjson req "$REQ_PREDS" \
      --arg sbom "$(att_state 'cyclonedx|spdx|sbom')" \
      --arg prov "$(att_state 'slsa|provenance')" \
      --arg vex "$(att_state 'openvex|vex')" \
  '{ trust_class: $tc, result: $res, reason: $reason,
     subject: $src,
     keyring: { path: $keyring, pinned_sha256: $kp, fetched_sha256: $kf },
     attestations: { repository: $attrepo, colocated: true, verified: $verified,
                     predicate_types_found: $preds, predicate_types_required: $req,
                     sbom: $sbom, provenance: $prov, vex: $vex } }' \
  > "$EVIDENCE/upstream-verification.json"

cat "$EVIDENCE/upstream-verification.json"

# ---------------------------------------------------------------------------
# 3. Pre-copy tag check. The PIN wins -- that is what a pin is for -- but a
#    moved tag is recorded so a reviewer can see it. drift.yml proposes bumps.
# ---------------------------------------------------------------------------
LIVE=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${SRC_REPO}:${SRC_TAG}" 2>/dev/null || echo "<unresolvable>")
[[ "$LIVE" == "$PIN" ]] || echo "::warning::${SRC_REPO}:${SRC_TAG} now resolves to ${LIVE}; pin is ${PIN}. Mirroring the PIN."

# ---------------------------------------------------------------------------
# 4. Copy the whole index BY DIGEST. A single-manifest upstream (mssql) has no
#    index; the manifest digest is then the claim and the same copy applies.
#
# --referrers carries OCI 1.1 referrers; --digest-tags carries the legacy
# sha256-<digest>.sig/.att tags that cosign v2 writes. BOTH are passed so the
# mirror is correct regardless of which cosign generation produced any given
# upstream signature, and regardless of whether GHCR implements /referrers.
# ---------------------------------------------------------------------------
#
# No --referrers-src/--referrers-tgt. Those redirect referrer lookup to a
# SEPARATE repository, which is what the old attestationRepo field assumed.
# DHI keeps its referrers in the image's own repository, so plain --referrers
# already carries them and the redirection pointed somewhere that does not exist.
COPY_ARGS=(--referrers --digest-tags --force-recursive)

regctl image copy "${SRC_REPO}@${PIN}" "${DEST_REPO}:${DEST_TAG}" "${COPY_ARGS[@]}"

# ---------------------------------------------------------------------------
# 5. THE invariant. A content-addressed copy preserves the digest; if it did
#    not, the copy mutated the image. This is the replacement for the reference
#    repo's upstream-digest LABEL -- stronger, because it is a fact anyone can
#    re-derive rather than a claim we assert.
# ---------------------------------------------------------------------------
DEST_DIGEST=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${DEST_REPO}:${DEST_TAG}")
if [[ "$DEST_DIGEST" != "$PIN" ]]; then
  echo "::error::Copy was not content-preserving: source ${PIN}, destination ${DEST_DIGEST}"
  exit 1
fi

# The digest invariant cannot see referrers. For a Notary-signed image the
# signature IS the trust artifact, and regclient turns an unsupported referrers
# API into an empty list rather than an error, so assert it landed.
if [[ "$TRUST_CLASS" == "notation" ]]; then
  regctl artifact list --format '{{jsonPretty .}}' "${DEST_REPO}@${DEST_DIGEST}" 2>/dev/null \
    | jq -e '[.descriptors[]?.artifactType] | any(. == "application/vnd.cncf.notary.signature")' >/dev/null \
    || { echo "::error::the Notary signature referrer did not survive the copy to ${DEST_REPO}@${DEST_DIGEST}"; exit 1; }
  echo "  notary signature referrer present on ${DEST_REPO}@${DEST_DIGEST}"
fi

# ---------------------------------------------------------------------------
# 6. Enumerate platforms.
#
# scripts/manifest-platforms.sh handles both upstream shapes -- a multi-arch
# index (filtering the BuildKit attestation manifests nexus3 carries) and a bare
# single-platform manifest (mssql) -- and exits non-zero rather than print an
# empty set. review-leg.sh re-derives the same set live from GHCR through the
# same helper, so the build actor cannot fake it.
# ---------------------------------------------------------------------------
regctl manifest get --format '{{jsonPretty .}}' "${DEST_REPO}@${DEST_DIGEST}" > "$EVIDENCE/index.json"

SHAPE=$(scripts/manifest-platforms.sh "${DEST_REPO}@${DEST_DIGEST}")
MEDIA_TYPE=$(jq -r '.media_type' <<<"$SHAPE")
IS_INDEX=$(jq -r '.is_index' <<<"$SHAPE")
mapfile -t PLATFORMS < <(jq -r '.platforms[]' <<<"$SHAPE")

ACTUAL=$(jq -c '.platforms | sort' <<<"$SHAPE")
DECLARED=$(jq -c 'sort' <<<"$DECLARED_PLATFORMS")
if [[ "$ACTUAL" != "$DECLARED" ]]; then
  echo "::error::Platform drift: versions.json declares ${DECLARED}, mirrored index carries ${ACTUAL}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 7. Per-platform scan, against the CHILD manifest digest.
#    Resolving the child ourselves removes all ambiguity about how syft/grype
#    pick from an index, and puts the exact digest scanned into the evidence.
#    For a bare manifest regctl resolves --platform to the manifest itself, so
#    child_digest == the pinned digest and the same loop applies.
# ---------------------------------------------------------------------------
PLATFORM_JSON='[]'
for p in "${PLATFORMS[@]}"; do
  slug="${p//\//-}"
  child=$(regctl manifest head --platform "$p" --format '{{.GetDescriptor.Digest}}' "${DEST_REPO}@${DEST_DIGEST}")
  echo "  scanning ${p} -> ${child}"
  syft  "registry:${DEST_REPO}@${child}" -o "spdx-json=$EVIDENCE/sbom-${slug}.json" -q
  grype "registry:${DEST_REPO}@${child}" -o json > "$EVIDENCE/cve-${slug}.json" 2>/dev/null
  PLATFORM_JSON=$(jq -c --arg p "$p" --arg s "$slug" --arg d "$child" \
    '. + [{platform:$p, slug:$s, child_digest:$d, sbom:("sbom-"+$s+".json"), cve:("cve-"+$s+".json")}]' <<<"$PLATFORM_JSON")
done

# Runtime config user, read from the first platform's child config. Mirrored
# images carry the vendor's config; we never alter it, but the policy still
# checks that a runtime variant is not root.
FIRST_CHILD=$(jq -r '.[0].child_digest' <<<"$PLATFORM_JSON")
CONFIG_USER=$(regctl image config "${DEST_REPO}@${FIRST_CHILD}" --format '{{.Config.User}}' 2>/dev/null || echo "")

# ---------------------------------------------------------------------------
# 8. subject.json -- the normalising layer. review.yml loops .platforms[] for
#    every leg regardless of kind, so no `if kind == mirror` branch exists in
#    the consumer's verification logic.
# ---------------------------------------------------------------------------
jq -n --arg leg "$LEG" --arg svc "$SERVICE" --arg var "$VARIANT" --arg tc "$TRUST_CLASS" \
      --arg repo "$DEST_REPO" --arg tag "$DEST_TAG" --arg dig "$DEST_DIGEST" \
      --arg enf "$ENFORCEMENT" --arg srctag "$SRC_TAG" --arg track "$TRACK" \
      --arg cu "$CONFIG_USER" --arg mt "$MEDIA_TYPE" --argjson idx "$IS_INDEX" \
      --argjson platforms "$PLATFORM_JSON" \
  '{ kind: "mirror", leg: $leg, service: $svc, variant: $var, trust_class: $tc,
     enforcement: $enf, upstream_tag: $srctag, track: $track,
     config_user: $cu, labels: {},
     subject: { repository: $repo, tag: $tag, digest: $dig,
                media_type: $mt, is_index: $idx },
     platforms: $platforms,
     manifest_group: null }' > "$EVIDENCE/subject.json"

# ---------------------------------------------------------------------------
# 9. Mirror provenance. `rebuilt: false` is the whole point of this track.
# ---------------------------------------------------------------------------
jq -n --arg srcrepo "$SRC_REPO" --arg srctag "$SRC_TAG" --arg pin "${PIN#sha256:}" \
      --arg live "$LIVE" --arg tc "$TRUST_CLASS" \
      --arg destrepo "$DEST_REPO" --arg destdig "${DEST_DIGEST#sha256:}" \
      --arg run "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-0}" \
      --arg regctl "$(regctl version --format '{{.VCSTag}}' 2>/dev/null || echo unknown)" \
  '{ buildDefinition: {
       buildType: "https://github.com/infrashift/trusted-service-containers/mirror/v1",
       externalParameters: { upstream: { uri: $srcrepo, tag: $srctag, digest: {sha256: $pin}, trustClass: $tc } },
       internalParameters: { rebuilt: false, tool: "regctl", referrers: true, digestTags: true,
                             tagResolvedDigest: $live, attestationsColocated: true },
       resolvedDependencies: [ { uri: $srcrepo, digest: {sha256: $pin},
                                 annotations: {role: "mirror-source", tag: $srctag, trustClass: $tc} } ] },
     runDetails: { builder: { id: $run, version: { regctl: $regctl } } },
     mirror: { destination: { repository: $destrepo, digest: {sha256: $destdig} },
               digestPreserved: true,
               assertion: "destination.digest == upstream.digest" } }' \
  > "$EVIDENCE/provenance.json"

# ---------------------------------------------------------------------------
# 10. Sign every evidence blob, then checksum the lot and sign that.
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

# ---------------------------------------------------------------------------
# 11. Attest.
#
# NEVER pass --replace. It was safe in the reference repo; here it would DELETE
# the DHI SBOM and provenance we just went to great lengths to mirror, and would
# clobber the amd64 SBOM when writing the arm64 one. Per-platform SBOM/CVE
# attach to the CHILD digest (the amd64 SBOM describes the amd64 manifest);
# provenance and upstream-verification attach to the INDEX.
# ---------------------------------------------------------------------------
attest() { cosign attest --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY "$@" >/dev/null; }

attest --type slsaprovenance1 --predicate "$EVIDENCE/provenance.json" "${DEST_REPO}@${DEST_DIGEST}"
attest --type https://infrashift.io/attestation/upstream-verification/v1 \
       --predicate "$EVIDENCE/upstream-verification.json" "${DEST_REPO}@${DEST_DIGEST}"

while read -r slug child; do
  attest --type spdxjson --predicate "$EVIDENCE/sbom-${slug}.json" "${DEST_REPO}@${child}"
  attest --type vuln     --predicate "$EVIDENCE/cve-${slug}.json"  "${DEST_REPO}@${child}"
done < <(jq -r '.[] | "\(.slug) \(.child_digest)"' <<<"$PLATFORM_JSON")

echo "OK: ${LEG} mirrored to ${DEST_REPO}:${DEST_TAG} (${DEST_DIGEST}), ${#PLATFORMS[@]} platform(s) scanned"
