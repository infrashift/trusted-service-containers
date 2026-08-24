#!/usr/bin/env bash
# Mirror one {service, variant} leg: verify upstream trust, copy the whole
# multi-arch index by digest, scan every platform, sign and attest.
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
# 4. Copy the whole index BY DIGEST.
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

# ---------------------------------------------------------------------------
# 6. Enumerate platforms.
#
# MUST filter unknown/unknown and vnd.docker.reference.type: both nexus3 3.90.1
# and 3.90.5 carry BuildKit attestation manifests as extra index entries, and
# handing one to syft produces a confusing failure. Attestation shape varies
# between patch releases of the same upstream, so nothing may be assumed.
# ---------------------------------------------------------------------------
regctl manifest get --format '{{jsonPretty .}}' "${DEST_REPO}@${DEST_DIGEST}" > "$EVIDENCE/index.json"

mapfile -t PLATFORMS < <(jq -r '
  .manifests[]
  | select((.annotations // {})["vnd.docker.reference.type"] == null)
  | select(.platform.os != null and .platform.os != "unknown")
  | select(.platform.architecture != null and .platform.architecture != "unknown")
  | "\(.platform.os)/\(.platform.architecture)"' "$EVIDENCE/index.json" | sort -u)

ACTUAL=$(printf '%s\n' "${PLATFORMS[@]}" | jq -R -s -c 'split("\n")|map(select(length>0))|sort')
DECLARED=$(jq -c 'sort' <<<"$DECLARED_PLATFORMS")
if [[ "$ACTUAL" != "$DECLARED" ]]; then
  echo "::error::Platform drift: versions.json declares ${DECLARED}, mirrored index carries ${ACTUAL}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 7. Per-platform scan, against the CHILD manifest digest.
#    Resolving the child ourselves removes all ambiguity about how syft/grype
#    pick from an index, and puts the exact digest scanned into the evidence.
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
      --arg cu "$CONFIG_USER" \
      --argjson platforms "$PLATFORM_JSON" \
  '{ kind: "mirror", leg: $leg, service: $svc, variant: $var, trust_class: $tc,
     enforcement: $enf, upstream_tag: $srctag, track: $track,
     config_user: $cu, labels: {},
     subject: { repository: $repo, tag: $tag, digest: $dig,
                media_type: "application/vnd.oci.image.index.v1+json", is_index: true },
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
