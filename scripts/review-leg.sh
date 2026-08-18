#!/usr/bin/env bash
# Review one leg: verify the build actor's evidence, independently re-derive the
# facts that matter, evaluate the policy per platform, and emit a signed verdict.
#
# The review actor does NOT take the build actor's word for anything material.
# Digests are re-resolved live from GHCR; trust class is re-read from the
# checked-out versions.json, never from the evidence bundle. That is what makes
# downgrading an image's verification require a CODEOWNERS-reviewed commit
# rather than a workflow edit.
#
# Required env: LEG SERVICE VARIANT KIND [ARCH] HEAD_SHA PR_NUM
#               BUILD_RUN_ID REVIEW_RUN_ID GITHUB_REPOSITORY
#               COSIGN_PRIVATE_KEY COSIGN_PASSWORD
set -euo pipefail

: "${LEG:?}" "${SERVICE:?}" "${VARIANT:?}" "${KIND:?}" "${HEAD_SHA:?}" "${GITHUB_REPOSITORY:?}"
ARCH="${ARCH:-}"
EV=evidence
BUILD_PUB=.github/pdp/public-keys/build.pub

fail() { echo "::error::$*"; exit 1; }
check() { printf '  %-34s %s\n' "$1" "$2"; }

CHECKS='{}'
record() { CHECKS=$(jq -c --arg k "$1" --arg r "$2" --arg d "$3" '. + {($k): {result:$r, detail:$d}}' <<<"$CHECKS"); }

# ===========================================================================
# 1. Evidence integrity, BEFORE reading a single byte of its content.
# ===========================================================================
[[ -f "$EV/checksums.sha256" ]] || fail "evidence bundle has no checksums.sha256"

( cd "$EV" && sha256sum --check --quiet checksums.sha256 ) \
  || fail "checksums.sha256 does not match the evidence bundle"
check "evidence checksums" "OK"

# The checksum file itself, and every blob, must carry the build actor's
# signature. Verifying the manifest before trusting the manifest.
cosign verify-blob --key "$BUILD_PUB" --insecure-ignore-tlog \
  --signature "$EV/checksums.sha256.sig" "$EV/checksums.sha256" >/dev/null 2>&1 \
  || fail "checksums.sha256 signature does not verify against build.pub"

BLOB_COUNT=0
for f in "$EV"/*.json; do
  [[ -f "${f}.sig" ]] || fail "missing signature for $(basename "$f")"
  cosign verify-blob --key "$BUILD_PUB" --insecure-ignore-tlog \
    --signature "${f}.sig" "$f" >/dev/null 2>&1 \
    || fail "signature does not verify for $(basename "$f")"
  BLOB_COUNT=$((BLOB_COUNT + 1))
done
check "blob signatures (${BLOB_COUNT})" "OK"
record evidence_blob_signatures PASS "${BLOB_COUNT} blob(s) verified against build.pub"

# ===========================================================================
# 2. Normalised subject. ONE code path for both tracks: is_index / platforms[]
#    absorbs the shape difference, so nothing below branches on kind except the
#    two genuinely kind-specific assertions.
# ===========================================================================
SUBJ="$EV/subject.json"
S_KIND=$(jq -r '.kind' "$SUBJ")
[[ "$S_KIND" == "$KIND" ]] || fail "subject.json says kind=${S_KIND} but the matrix says ${KIND}"

DEST_REPO=$(jq -r '.subject.repository' "$SUBJ")
DEST_TAG=$(jq -r '.subject.tag' "$SUBJ")
CLAIMED_DIGEST=$(jq -r '.subject.digest' "$SUBJ")
ENFORCEMENT=$(jq -r '.enforcement' "$SUBJ")
CONFIG_USER=$(jq -r '.config_user // ""' "$SUBJ")
LABELS=$(jq -c '.labels // {}' "$SUBJ")
PLATFORMS=$(jq -c '.platforms' "$SUBJ")

# Live, independent re-resolve. This is the check the build actor cannot fake.
LIVE_DIGEST=$(regctl manifest head --format '{{.GetDescriptor.Digest}}' "${DEST_REPO}:${DEST_TAG}") \
  || fail "cannot resolve ${DEST_REPO}:${DEST_TAG} from GHCR"
[[ "$LIVE_DIGEST" == "$CLAIMED_DIGEST" ]] \
  || fail "evidence claims ${CLAIMED_DIGEST} but GHCR currently serves ${LIVE_DIGEST}"

# ===========================================================================
# 3. Attestation signatures.
#
# Iterate rather than assume one: --replace is banned repo-wide, so a rerun of
# an unchanged input produces the same content-addressed digest and the
# attestations accumulate. cosign verify-attestation succeeds if ANY attached
# attestation of that type verifies, which is the behaviour we want.
# ===========================================================================
verify_att() {
  cosign verify-attestation --key "$BUILD_PUB" --type "$1" --insecure-ignore-tlog \
    --certificate-identity-regexp='.*' --certificate-oidc-issuer-regexp='.*' \
    "$2" >/dev/null 2>&1
}

verify_att slsaprovenance1 "${DEST_REPO}@${LIVE_DIGEST}" \
  || fail "SLSA provenance attestation does not verify against build.pub"
verify_att https://infrashift.io/attestation/upstream-verification/v1 "${DEST_REPO}@${LIVE_DIGEST}" \
  || fail "upstream-verification attestation does not verify against build.pub"

while read -r child; do
  verify_att spdxjson "${DEST_REPO}@${child}" || fail "SBOM attestation does not verify for ${child}"
  verify_att vuln     "${DEST_REPO}@${child}" || fail "CVE attestation does not verify for ${child}"
done < <(jq -r '.[].child_digest' <<<"$PLATFORMS")
check "build attestations" "OK"
record build_attestations PASS "provenance, upstream-verification and per-platform SBOM/CVE verified"

# ===========================================================================
# 4. Anti-downgrade: trust class comes from the REPO, never the evidence.
# ===========================================================================
IMG=$(jq -ce --arg s "$SERVICE" '.images[$s]' versions.json)
REPO_TRUST=$(jq -r '.upstreamTrust' <<<"$IMG")
EV_TRUST=$(jq -r '.trust_class' "$EV/upstream-verification.json")
[[ "$EV_TRUST" == "$REPO_TRUST" ]] \
  || fail "evidence claims trust_class=${EV_TRUST} but versions.json declares ${REPO_TRUST}"
check "trust class agrees with repo" "$REPO_TRUST"

UV="$EV/upstream-verification.json"
SIG_STATE=$(jq -r '.result' "$UV")
VERIFIED_WITH=$(jq -r '.verified_with // .keyring.path // ""' "$UV")
KEYRING_PINNED=$(jq -r '.keyring.pinned_sha256 // ""' "$UV")
KEYRING_FETCHED=$(jq -r '.keyring.fetched_sha256 // ""' "$UV")
ATT_SBOM=$(jq -r '.attestations.sbom // "not-applicable"' "$UV")
ATT_PROV=$(jq -r '.attestations.provenance // "not-applicable"' "$UV")
ATT_VEX=$(jq -r '.attestations.vex // "not-applicable"' "$UV")
record upstream_verification "$(tr '[:lower:]' '[:upper:]' <<<"${SIG_STATE:0:1}")${SIG_STATE:1}" \
  "$(jq -r '.reason' "$UV")"

# ===========================================================================
# 5. Kind-specific integrity blocks for the policy input.
# ===========================================================================
PROV="$EV/provenance.json"
MIRROR_BLOCK='{}'; BUILD_BLOCK='{}'

if [[ "$KIND" == "mirror" ]]; then
  VAR=$(jq -ce --arg v "$VARIANT" '.variants[$v]' <<<"$IMG")
  PIN=$(jq -r '.digest' <<<"$VAR")
  # Live platform set, re-derived now rather than read from the evidence, with
  # the unknown/unknown attestation manifests filtered out.
  regctl manifest get --format '{{jsonPretty .}}' "${DEST_REPO}@${LIVE_DIGEST}" > /tmp/live-index.json
  LIVE_PLATFORMS=$(jq -c '[ .manifests[]
      | select((.annotations // {})["vnd.docker.reference.type"] == null)
      | select(.platform.os != null and .platform.os != "unknown")
      | select(.platform.architecture != null and .platform.architecture != "unknown")
      | "\(.platform.os)/\(.platform.architecture)" ] | unique' /tmp/live-index.json)

  MIRROR_BLOCK=$(jq -n \
    --arg pinrepo "$(jq -r '.upstreamRepo' <<<"$IMG")" \
    --arg srcrepo "$(jq -r '.buildDefinition.externalParameters.upstream.uri' "$PROV")" \
    --arg pin "$PIN" \
    --arg srcdig "sha256:$(jq -r '.buildDefinition.externalParameters.upstream.digest.sha256' "$PROV")" \
    --arg tag "$(jq -r '.tag' <<<"$VAR")" \
    --arg track "$(jq -r '.track' <<<"$VAR")" \
    --argjson declared "$(jq -c '.platforms' <<<"$IMG")" \
    --argjson observed "$(jq -c '[.[].platform] | unique' <<<"$PLATFORMS")" \
    --argjson live "$LIVE_PLATFORMS" \
    '{ pinned_source_repo:$pinrepo, source_repo:$srcrepo,
       pinned_digest:$pin, source_digest:$srcdig,
       resolved_tag:$tag, track_constraint:$track,
       declared_platforms:$declared, source_platforms:$observed,
       destination_platforms:$live }')
  check "digest pin (live from GHCR)" "$( [[ "$LIVE_DIGEST" == "$PIN" ]] && echo OK || echo MISMATCH )"
  record digest_pin_match "$( [[ "$LIVE_DIGEST" == "$PIN" ]] && echo PASS || echo FAIL )" \
    "expected ${PIN}, GHCR serves ${LIVE_DIGEST}"
else
  SRC_KEY=$(jq -r '.source' <<<"$IMG")
  REPO_KEY=$(jq -r '.repo // empty' <<<"$IMG")
  if [[ -n "$REPO_KEY" ]]; then
    PINNED_REF=$(jq -r --arg s "$SRC_KEY" --arg r "$REPO_KEY" '.sources[$s].repos[$r].commit' versions.json)
  else
    PINNED_REF=$(jq -r --arg s "$SRC_KEY" '.sources[$s].commit' versions.json)
  fi
  BASE_KEY=$(jq -r '.base' <<<"$IMG")
  BUILD_BLOCK=$(jq -n \
    --arg pinbaserepo "$(jq -r --arg k "$BASE_KEY" '.bases[$k].image' versions.json)" \
    --arg baserepo "$(jq -r '.buildDefinition.resolvedDependencies[0].uri' "$PROV")" \
    --arg pinbasedig "$(jq -r --arg k "$BASE_KEY" --arg a "$ARCH" '.bases[$k][$a].digest' versions.json)" \
    --arg basedig "sha256:$(jq -r '.buildDefinition.resolvedDependencies[0].digest.sha256' "$PROV")" \
    --arg pinref "$PINNED_REF" \
    --arg ref "$(jq -r '.buildDefinition.externalParameters.source.digest.gitCommit' "$PROV")" \
    --arg pinxc "$(jq -r --arg a "$ARCH" '.crosscheck[$a].digest' <<<"$IMG")" \
    --argjson dp "$(jq -c '{performed:true,
                            from_source_sha256:.builtFromSource.sha256,
                            official_image_sha256:.upstreamReference.sha256,
                            official_image_digest:.upstreamReference.digest,
                            reproducibility_tier:.comparison.reproducibilityTier}' "$EV/crosscheck.json")" \
    '{ pinned_base_repo:$pinbaserepo, base_image_repo:$baserepo,
       pinned_base_digest:$pinbasedig, base_image_digest:$basedig,
       pinned_source_ref:$pinref, source_revision:$ref,
       pinned_crosscheck_digest:$pinxc, dual_provenance:$dp }')
  SRC_OK=$([[ "$(jq -r '.source_revision' <<<"$BUILD_BLOCK")" == "$PINNED_REF" ]] && echo PASS || echo FAIL)
  check "source commit == versions.json pin" "$SRC_OK"
  record source_pin_match "$SRC_OK" "pinned ${PINNED_REF}"
fi

# Credential-shaped keys in anything we publish.
PUB_KEYS=$(jq -c '[paths(scalars) | map(tostring) | join(".")] | map({key:., value:true}) | from_entries' "$PROV" 2>/dev/null || echo '{}')

# ===========================================================================
# 6. Policy evaluation, ONE call per platform. Leg verdict = AND.
# ===========================================================================
EVALUATED_AT="${EVALUATED_AT:-$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"
PER_PLATFORM='{}'
LEG_VERDICT=PASS
ALL_WAIVED='[]'
ALL_VIOLATIONS='[]'

while read -r slug cve_file; do
  # The policy classifies; the input must therefore carry EVERY Critical and
  # High unfiltered. INPUT_FINDINGS_INCONSISTENT catches a pre-filtered list.
  FINDINGS=$(jq -c '[ .matches[]?
    | select(.vulnerability.severity == "Critical" or .vulnerability.severity == "High")
    | { id: .vulnerability.id, severity: .vulnerability.severity,
        fix_state: (.vulnerability.fix.state // "unknown"),
        package: .artifact.name, version: .artifact.version } ]' "$EV/$cve_file")

  counts() { jq --arg s "$1" '[.matches[]? | select(.vulnerability.severity == $s)] | length' "$EV/$cve_file"; }
  fixable() { jq --arg s "$1" '[.matches[]? | select(.vulnerability.severity == $s and .vulnerability.fix.state == "fixed")] | length' "$EV/$cve_file"; }

  jq -n \
    --arg track "$KIND" --arg now "$EVALUATED_AT" \
    --arg key "$SERVICE" --arg var "$VARIANT" --arg enf "$ENFORCEMENT" \
    --arg drepo "$DEST_REPO" --arg ddig "$LIVE_DIGEST" --arg cu "$CONFIG_USER" \
    --argjson labels "$LABELS" \
    --arg tc "$REPO_TRUST" --arg sig "$SIG_STATE" --arg vw "$VERIFIED_WITH" \
    --arg kp "$KEYRING_PINNED" --arg kf "$KEYRING_FETCHED" \
    --arg asbom "$ATT_SBOM" --arg aprov "$ATT_PROV" --arg avex "$ATT_VEX" \
    --argjson mirror "$MIRROR_BLOCK" --argjson build "$BUILD_BLOCK" \
    --argjson findings "$FINDINGS" \
    --argjson c "$(counts Critical)" --argjson h "$(counts High)" \
    --argjson m "$(counts Medium)" --argjson l "$(counts Low)" \
    --argjson fc "$(fixable Critical)" --argjson fh "$(fixable High)" \
    --argjson pubkeys "$PUB_KEYS" \
    '{ track: $track, evaluated_at: $now,
       image: { key:$key, variant:$var, enforcement:$enf,
                destination_repo:$drepo, destination_digest:$ddig,
                config_user:$cu, labels:$labels },
       upstream: { trust_class:$tc, signature:$sig, verified_with:$vw,
                   keyring_pinned_sha256:$kp, keyring_fetched_sha256:$kf,
                   attestations: { sbom:$asbom, provenance:$aprov, vex:$avex } },
       mirror: $mirror, build: $build,
       scan_results: { critical_count:$c, high_count:$h, medium_count:$m, low_count:$l,
                       fixable_critical_count:$fc, fixable_high_count:$fh,
                       findings:$findings },
       published_attestation_keys: $pubkeys }' > "/tmp/opa-input-${slug}.json"

  opa eval --data .github/pdp/policies.rego --data .github/pdp/exceptions.yaml \
    --input "/tmp/opa-input-${slug}.json" --format json 'data.tsc.pdp.decision' \
  | jq -e '.result[0].expressions[0].value' > "/tmp/decision-${slug}.json" \
  || fail "policy did not evaluate for ${slug} (a null/false result is a hard failure, never a pass)"

  ALLOW=$(jq -r '.allow' "/tmp/decision-${slug}.json")
  [[ "$ALLOW" == "true" ]] || LEG_VERDICT=FAIL

  PER_PLATFORM=$(jq -c --arg s "$slug" --slurpfile d "/tmp/decision-${slug}.json" \
    '. + {($s): {allow:$d[0].allow, namespace:$d[0].namespace, counts:$d[0].counts,
                 violations:$d[0].violations, warnings:$d[0].warnings,
                 findings:$d[0].findings, observations:$d[0].observations}}' <<<"$PER_PLATFORM")
  ALL_WAIVED=$(jq -c --slurpfile d "/tmp/decision-${slug}.json" '. + $d[0].waived' <<<"$ALL_WAIVED")
  ALL_VIOLATIONS=$(jq -c --slurpfile d "/tmp/decision-${slug}.json" '. + $d[0].violations' <<<"$ALL_VIOLATIONS")

  printf '  %-18s allow=%-5s blocking=%s waived=%s recorded=%s\n' "$slug" "$ALLOW" \
    "$(jq -r '.counts.blocking' "/tmp/decision-${slug}.json")" \
    "$(jq -r '.counts.waived'   "/tmp/decision-${slug}.json")" \
    "$(jq -r '.counts.recorded' "/tmp/decision-${slug}.json")"
done < <(jq -r '.[] | "\(.slug) \(.cve)"' <<<"$PLATFORMS")

record cve_policy "$LEG_VERDICT" "evaluated per platform against data.tsc.pdp.decision"

# ===========================================================================
# 7. The signed verdict.
# ===========================================================================
jq -n \
  --arg leg "$LEG" --arg svc "$SERVICE" --arg var "$VARIANT" --arg kind "$KIND" \
  --arg repo "$DEST_REPO" --arg tag "$DEST_TAG" --arg dig "$LIVE_DIGEST" \
  --arg verdict "$LEG_VERDICT" --arg tc "$REPO_TRUST" --arg enf "$ENFORCEMENT" \
  --arg now "$EVALUATED_AT" --arg head "$HEAD_SHA" --arg pr "${PR_NUM:-}" \
  --arg brun "${BUILD_RUN_ID:-}" --arg rrun "${REVIEW_RUN_ID:-}" \
  --argjson platforms "$PLATFORMS" --argjson checks "$CHECKS" \
  --argjson perplat "$PER_PLATFORM" --argjson waived "$ALL_WAIVED" \
  '{ metadata: { timestamp:$now, evaluatedAt:$now, reviewer:"review-actor",
                 reviewRunId:$rrun, buildRunId:$brun, pullRequest:$pr, commitSha:$head },
     subject: { leg:$leg, service:$svc, variant:$var, kind:$kind, trustClass:$tc,
                enforcement:$enf, repository:$repo, tag:$tag, digest:$dig,
                platforms:$platforms },
     checks: $checks,
     cve_policy: { result:$verdict, policy:"data.tsc.pdp.decision",
                   per_platform:$perplat, exceptions_applied:$waived },
     verdict: $verdict }' > review-verdict.json

cosign sign-blob --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY \
  --output-signature review-verdict.json.sig review-verdict.json >/dev/null

# Attached to the image so release.yml reads the verdict from a SIGNED
# attestation, never from a mutable artifact.
cosign attest --yes --tlog-upload=false --key env://COSIGN_PRIVATE_KEY \
  --type https://infrashift.io/attestation/review/v1 \
  --predicate review-verdict.json "${DEST_REPO}@${LIVE_DIGEST}" >/dev/null

echo "verdict: ${LEG_VERDICT} for ${LEG}"
[[ "$LEG_VERDICT" == "PASS" ]] || echo "::warning::${LEG} FAILED review; it will be promoted to quarantine, not trusted"
