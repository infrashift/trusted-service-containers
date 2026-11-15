package tsc.pdp_test

import data.tsc.pdp

# ===========================================================================
# Every test here corresponds to a real fail-open hole. The reference repo's
# policy was never exercised by anything; two of its six .rego files would have
# denied every image and nobody noticed. Keep this suite green before touching
# a workflow.
#
# Overrides use json.patch so each test states only its delta from a known-good
# baseline, and a baseline change cannot silently make a test vacuous.
# ===========================================================================

D := "sha256:3d6454ebafb3e807782c15dc9a500b83013107128e35db5da219fda05c07b68c"

D2 := "sha256:9c59d3f4b8ac60180e5f8f17aff0e4d5800ec13dd9613cfe4d06327f23fda1e0"

NOW := "2026-08-18T12:00:00Z"

COMMIT := "9d7085948039ffb8960160d4979f71527b5cf4d5"

# --- Known-good MIRROR leg (nexus3, trust class none) -----------------------
base_mirror := {
	"track": "mirror",
	"evaluated_at": NOW,
	"image": {
		"key": "nexus3", "variant": "runtime", "enforcement": "enforce",
		"destination_repo": "ghcr.io/infrashift/trusted-service-containers/development/nexus3",
		"destination_digest": D, "config_user": "nexus", "labels": {},
	},
	"upstream": {
		"trust_class": "none", "signature": "not-applicable", "verified_with": "<missing>",
		"attestations": {"sbom": "not-applicable", "provenance": "not-applicable", "vex": "not-applicable"},
	},
	"mirror": {
		"pinned_source_repo": "docker.io/sonatype/nexus3", "source_repo": "docker.io/sonatype/nexus3",
		"pinned_digest": D, "source_digest": D,
		"resolved_tag": "3.90.5-ubi", "track_constraint": "^3\\.90\\.[0-9]+-ubi$",
		"declared_platforms": ["linux/amd64", "linux/arm64"],
		"source_platforms": ["linux/amd64", "linux/arm64"],
		"destination_platforms": ["linux/amd64", "linux/arm64"],
	},
	"scan_results": {
		"critical_count": 0, "high_count": 0, "medium_count": 0, "low_count": 0,
		"fixable_critical_count": 0, "fixable_high_count": 0, "findings": [],
	},
	"published_attestation_keys": {},
}

# --- Known-good BUILD leg (kratos, trust class internal) --------------------
base_build := {
	"track": "build",
	"evaluated_at": NOW,
	"image": {
		"key": "kratos", "variant": "runtime", "enforcement": "enforce",
		"destination_repo": "ghcr.io/infrashift/trusted-service-containers/development/kratos",
		"destination_digest": D, "config_user": "1001",
		"labels": {
			"org.opencontainers.image.source": "https://github.com/ory/kratos",
			"org.opencontainers.image.revision": COMMIT,
			"org.opencontainers.image.version": "v26.2.0",
			"io.infrashift.image.upstream.digest": D2,
			"io.infrashift.image.upstream.source": "ghcr.io/infrashift/trusted-base-images/trusted/ubi9-micro",
		},
	},
	"upstream": {
		"trust_class": "internal", "signature": "verified",
		"verified_with": ".github/pdp/public-keys/upstream/trusted-base-images-release.pub",
		"attestations": {"sbom": "present", "provenance": "present", "vex": "absent"},
	},
	"build": {
		"pinned_base_repo": "ghcr.io/infrashift/trusted-base-images/trusted/ubi9-micro",
		"base_image_repo": "ghcr.io/infrashift/trusted-base-images/trusted/ubi9-micro",
		"pinned_base_digest": D2, "base_image_digest": D2,
		"pinned_source_ref": COMMIT, "source_revision": COMMIT,
		"pinned_crosscheck_digest": D,
		"dual_provenance": {
			"performed": true,
			"from_source_sha256": "aaaa000000000000000000000000000000000000000000000000000000000000",
			"official_image_sha256": "bbbb000000000000000000000000000000000000000000000000000000000000",
			"official_image_digest": D,
			"reproducibility_tier": "best-effort",
		},
		"first_party": {
			"declared": false,
			"crosscheck_pinned": true,
			"reason": "",
			"source_url": "https://github.com/ory/kratos",
			"built_source_url": "https://github.com/ory/kratos",
			"evidence_mode": "vendor-crosscheck",
		},
	},
	"scan_results": {
		"critical_count": 0, "high_count": 0, "medium_count": 0, "low_count": 0,
		"fixable_critical_count": 0, "fixable_high_count": 0, "findings": [],
	},
	"published_attestation_keys": {},
}

patch(base, ops) := json.patch(base, ops)

codes(dec) := {v.code | some v in dec.violations}

# ===========================================================================
# Baselines must PASS. If these break, every negative test below is vacuous.
# ===========================================================================

test_base_mirror_allows if {
	d := pdp.decision with input as base_mirror
	d.allow
	d.namespace == "trusted"
}

test_base_build_allows if {
	d := pdp.decision with input as base_build
	d.allow
	d.namespace == "trusted"
}

# ===========================================================================
# Fail-closed input handling
# ===========================================================================

test_empty_input_denies if {
	d := pdp.decision with input as {}
	not d.allow
	d.namespace == "quarantine"
}

test_missing_critical_count_denies if {
	i := patch(base_mirror, [{"op": "remove", "path": "/scan_results/critical_count"}])
	d := pdp.decision with input as i
	"INPUT_SCAN_FIELD_MALFORMED" in codes(d)
	not d.allow
}

# "0" is not 0. A `> 0` comparison against a string is undefined, i.e. silently
# non-violating, which is exactly the hole is_number() closes.
test_string_count_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/scan_results/critical_count", "value": "0"}])
	d := pdp.decision with input as i
	"INPUT_SCAN_FIELD_MALFORMED" in codes(d)
}

test_unknown_trust_class_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/upstream/trust_class", "value": "mirrr"}])
	d := pdp.decision with input as i
	"INPUT_TRUST_CLASS_UNKNOWN" in codes(d)
}

test_missing_trust_class_denies if {
	i := patch(base_mirror, [{"op": "remove", "path": "/upstream/trust_class"}])
	d := pdp.decision with input as i
	"INPUT_TRUST_CLASS_UNKNOWN" in codes(d)
}

test_unknown_track_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/track", "value": "copy"}])
	d := pdp.decision with input as i
	"INPUT_TRACK_UNKNOWN" in codes(d)
}

test_findings_inconsistent_with_counts_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/scan_results/critical_count", "value": 3}])
	d := pdp.decision with input as i
	"INPUT_FINDINGS_INCONSISTENT" in codes(d)
}

test_malformed_finding_denies if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/scan_results/findings", "value": [{"id": "CVE-1", "severity": "Critical"}]},
		{"op": "replace", "path": "/scan_results/critical_count", "value": 1},
	])
	d := pdp.decision with input as i
	"INPUT_FINDING_MALFORMED" in codes(d)
}

test_bad_destination_namespace_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/image/destination_repo", "value": "docker.io/evil/nexus3"}])
	d := pdp.decision with input as i
	"DESTINATION_NAMESPACE_INVALID" in codes(d)
}

test_credential_shaped_predicate_key_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/published_attestation_keys", "value": {"internalParameters.oidcToken": true}}])
	d := pdp.decision with input as i
	"ATTESTATION_PREDICATE_LEAK" in codes(d)
}

# ===========================================================================
# Upstream trust. THE core regression test is the first one.
# ===========================================================================

# One gate for every image: identical findings under `dhi` and under `none`
# must produce an identical CVE verdict. If this ever fails, someone has
# reintroduced a per-trust-class threshold.
test_dhi_and_none_have_identical_cve_verdict if {
	finding := {"id": "CVE-2026-1", "severity": "Critical", "fix_state": "fixed", "package": "libfoo"}
	as_none := patch(base_mirror, [
		{"op": "replace", "path": "/scan_results/findings", "value": [finding]},
		{"op": "replace", "path": "/scan_results/critical_count", "value": 1},
		{"op": "replace", "path": "/scan_results/fixable_critical_count", "value": 1},
	])
	as_dhi := json.patch(as_none, [
		{"op": "replace", "path": "/upstream/trust_class", "value": "dhi"},
		{"op": "replace", "path": "/upstream/signature", "value": "verified"},
		{"op": "replace", "path": "/upstream/verified_with", "value": ".github/pdp/keyring/dhi-latest.pub"},
		{"op": "replace", "path": "/upstream/attestations", "value": {"sbom": "present", "provenance": "present", "vex": "present"}},
		{"op": "add", "path": "/upstream/keyring_fetched_sha256", "value": "abc"},
		{"op": "add", "path": "/upstream/keyring_pinned_sha256", "value": "abc"},
	])
	dn := pdp.decision with input as as_none
	dd := pdp.decision with input as as_dhi
	dn.counts.blocking == dd.counts.blocking
	"CVE_CRITICAL" in codes(dn)
	"CVE_CRITICAL" in codes(dd)
}

test_none_may_skip_signature if {
	d := pdp.decision with input as base_mirror
	d.allow
}

# The fail-open hole `none` could otherwise open, closed.
test_dhi_cannot_claim_not_applicable if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/upstream/trust_class", "value": "dhi"},
		{"op": "add", "path": "/upstream/keyring_fetched_sha256", "value": "abc"},
		{"op": "add", "path": "/upstream/keyring_pinned_sha256", "value": "abc"},
	])
	d := pdp.decision with input as i
	"UPSTREAM_SIGNATURE_REQUIRED" in codes(d)
}

# A class may decline to verify; it may not verify and lose.
test_failed_signature_denies_even_for_none if {
	i := patch(base_mirror, [{"op": "replace", "path": "/upstream/signature", "value": "failed"}])
	d := pdp.decision with input as i
	"UPSTREAM_SIGNATURE_FAILED" in codes(d)
}

test_none_cannot_claim_verified if {
	i := patch(base_mirror, [{"op": "replace", "path": "/upstream/signature", "value": "verified"}])
	d := pdp.decision with input as i
	"UPSTREAM_TRUST_CLASS_CONTRADICTION" in codes(d)
}

# Verified against a key the attacker chose is not verified.
test_wrong_keyring_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/upstream/verified_with", "value": "/tmp/attacker.pub"}])
	d := pdp.decision with input as i
	"UPSTREAM_KEYRING_MISMATCH" in codes(d)
}

test_keyring_drift_denies if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/upstream/trust_class", "value": "dhi"},
		{"op": "replace", "path": "/upstream/signature", "value": "verified"},
		{"op": "replace", "path": "/upstream/verified_with", "value": ".github/pdp/keyring/dhi-latest.pub"},
		{"op": "replace", "path": "/upstream/attestations", "value": {"sbom": "present", "provenance": "present", "vex": "present"}},
		{"op": "add", "path": "/upstream/keyring_fetched_sha256", "value": "NEWKEY"},
		{"op": "add", "path": "/upstream/keyring_pinned_sha256", "value": "OLDKEY"},
	])
	d := pdp.decision with input as i
	"DHI_KEYRING_DRIFT" in codes(d)
}

# The different-sentinel trick: "both absent" must compare UNEQUAL and deny.
test_both_keyring_shas_absent_denies if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/upstream/trust_class", "value": "dhi"},
		{"op": "replace", "path": "/upstream/signature", "value": "verified"},
		{"op": "replace", "path": "/upstream/verified_with", "value": ".github/pdp/keyring/dhi-latest.pub"},
		{"op": "replace", "path": "/upstream/attestations", "value": {"sbom": "present", "provenance": "present", "vex": "present"}},
	])
	d := pdp.decision with input as i
	"DHI_KEYRING_DRIFT" in codes(d)
}

# --- notation (Notary Project) class: mssql -------------------------------
# Verified against the vendored Microsoft root, no attestations required.
notation_verified := patch(single_platform_mirror, [
	{"op": "replace", "path": "/upstream/trust_class", "value": "notation"},
	{"op": "add", "path": "/image/keyring", "value": ".github/pdp/keyring/microsoft-supply-chain-rsa-root-ca-2022.crt"},
	{"op": "replace", "path": "/upstream/signature", "value": "verified"},
	{"op": "replace", "path": "/upstream/verified_with", "value": ".github/pdp/keyring/microsoft-supply-chain-rsa-root-ca-2022.crt"},
	{"op": "add", "path": "/upstream/keyring_fetched_sha256", "value": "ba402b4b"},
	{"op": "add", "path": "/upstream/keyring_pinned_sha256", "value": "ba402b4b"},
])

test_notation_verified_allows if {
	d := pdp.decision with input as notation_verified
	d.allow
	d.namespace == "trusted"
	not "UPSTREAM_ATTESTATION_MISSING" in codes(d)
}

# The `none` escape hatch must not carry over: notation REQUIRES a signature.
test_notation_cannot_claim_not_applicable if {
	i := patch(notation_verified, [{"op": "replace", "path": "/upstream/signature", "value": "not-applicable"}])
	d := pdp.decision with input as i
	"UPSTREAM_SIGNATURE_REQUIRED" in codes(d)
}

test_notation_failed_denies if {
	i := patch(notation_verified, [{"op": "replace", "path": "/upstream/signature", "value": "failed"}])
	d := pdp.decision with input as i
	"UPSTREAM_SIGNATURE_FAILED" in codes(d)
}

# Verified against a root the attacker controls is not verified.
test_notation_wrong_root_denies if {
	i := patch(notation_verified, [{"op": "replace", "path": "/upstream/verified_with", "value": ".github/pdp/keyring/dhi-latest.pub"}])
	d := pdp.decision with input as i
	"UPSTREAM_KEYRING_MISMATCH" in codes(d)
}

# The keyring comes from versions.json via the review actor; if it is absent the
# sentinel can never equal a recorded verified_with, so the leg denies.
test_notation_without_declared_keyring_denies if {
	i := patch(notation_verified, [{"op": "remove", "path": "/image/keyring"}])
	d := pdp.decision with input as i
	"UPSTREAM_KEYRING_MISMATCH" in codes(d)
	"NOTATION_KEYRING_PATH_INVALID" in codes(d)
}

# A keyring outside the vendored directory is not a pin, even if it "verifies".
test_notation_keyring_outside_dir_denies if {
	i := patch(notation_verified, [
		{"op": "replace", "path": "/image/keyring", "value": "/tmp/attacker-root.crt"},
		{"op": "replace", "path": "/upstream/verified_with", "value": "/tmp/attacker-root.crt"},
	])
	d := pdp.decision with input as i
	"NOTATION_KEYRING_PATH_INVALID" in codes(d)
}

test_notation_root_drift_denies if {
	i := patch(notation_verified, [{"op": "replace", "path": "/upstream/keyring_fetched_sha256", "value": "ROTATED"}])
	d := pdp.decision with input as i
	"NOTATION_ROOT_DRIFT" in codes(d)
}

# Different sentinels: both digests absent must compare UNEQUAL and deny.
test_notation_root_shas_absent_denies if {
	i := patch(notation_verified, [
		{"op": "remove", "path": "/upstream/keyring_fetched_sha256"},
		{"op": "remove", "path": "/upstream/keyring_pinned_sha256"},
	])
	d := pdp.decision with input as i
	"NOTATION_ROOT_DRIFT" in codes(d)
}

test_dhi_missing_attestation_denies if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/upstream/trust_class", "value": "dhi"},
		{"op": "replace", "path": "/upstream/signature", "value": "verified"},
		{"op": "replace", "path": "/upstream/verified_with", "value": ".github/pdp/keyring/dhi-latest.pub"},
		{"op": "replace", "path": "/upstream/attestations", "value": {"sbom": "absent", "provenance": "present", "vex": "present"}},
		{"op": "add", "path": "/upstream/keyring_fetched_sha256", "value": "abc"},
		{"op": "add", "path": "/upstream/keyring_pinned_sha256", "value": "abc"},
	])
	d := pdp.decision with input as i
	"UPSTREAM_ATTESTATION_MISSING" in codes(d)
}

# ===========================================================================
# Mirror integrity
# ===========================================================================

test_pin_mismatch_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/mirror/source_digest", "value": D2}])
	d := pdp.decision with input as i
	"PIN_MISMATCH" in codes(d)
}

test_mirror_digest_drift_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/image/destination_digest", "value": D2}])
	d := pdp.decision with input as i
	"MIRROR_DIGEST_DRIFT" in codes(d)
}

test_both_mirror_digests_absent_denies if {
	i := patch(base_mirror, [
		{"op": "remove", "path": "/mirror/source_digest"},
		{"op": "remove", "path": "/image/destination_digest"},
	])
	d := pdp.decision with input as i
	"MIRROR_DIGEST_DRIFT" in codes(d)
}

test_dropped_architecture_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/mirror/destination_platforms", "value": ["linux/amd64"]}])
	d := pdp.decision with input as i
	"INDEX_PLATFORM_DRIFT" in codes(d)
	"PLATFORM_SET_MISMATCH" in codes(d)
}

# mssql is amd64-only and a bare manifest: the platform set has exactly one
# element. Every other mirror test hardcodes the two-element list, so without
# this the single-platform path is never exercised.
single_platform_mirror := patch(base_mirror, [
	{"op": "replace", "path": "/image/key", "value": "mssql"},
	{"op": "replace", "path": "/image/destination_repo", "value": "ghcr.io/infrashift/trusted-service-containers/development/mssql"},
	{"op": "replace", "path": "/image/config_user", "value": "mssql"},
	{"op": "replace", "path": "/mirror/pinned_source_repo", "value": "mcr.microsoft.com/mssql/rhel/server"},
	{"op": "replace", "path": "/mirror/source_repo", "value": "mcr.microsoft.com/mssql/rhel/server"},
	{"op": "replace", "path": "/mirror/resolved_tag", "value": "2025-latest"},
	{"op": "replace", "path": "/mirror/track_constraint", "value": "^2025-latest$"},
	{"op": "replace", "path": "/mirror/declared_platforms", "value": ["linux/amd64"]},
	{"op": "replace", "path": "/mirror/source_platforms", "value": ["linux/amd64"]},
	{"op": "replace", "path": "/mirror/destination_platforms", "value": ["linux/amd64"]},
])

test_single_platform_mirror_allows if {
	d := pdp.decision with input as single_platform_mirror
	d.allow
	d.namespace == "trusted"
	not "PLATFORM_SET_MISMATCH" in codes(d)
	not "INDEX_PLATFORM_DRIFT" in codes(d)
}

# The amd64-only entry must not be allowed to claim arm64: declaring a platform
# the manifest does not carry is exactly the drift the rule exists to catch.
test_single_platform_declared_two_denies if {
	i := patch(single_platform_mirror, [{"op": "replace", "path": "/mirror/declared_platforms", "value": ["linux/amd64", "linux/arm64"]}])
	d := pdp.decision with input as i
	not d.allow
	"PLATFORM_SET_MISMATCH" in codes(d)
	not "INDEX_PLATFORM_DRIFT" in codes(d)
}

test_upstream_repo_mismatch_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/mirror/source_repo", "value": "docker.io/evil/nexus3"}])
	d := pdp.decision with input as i
	"UPSTREAM_REPO_MISMATCH" in codes(d)
}

# 3.91.0-ubi exists upstream today; the track is what stops it entering.
test_tag_outside_track_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/mirror/resolved_tag", "value": "3.91.0-ubi"}])
	d := pdp.decision with input as i
	"TRACK_VIOLATION" in codes(d)
}

test_missing_track_constraint_denies if {
	i := patch(base_mirror, [{"op": "remove", "path": "/mirror/track_constraint"}])
	d := pdp.decision with input as i
	"TRACK_VIOLATION" in codes(d)
}

# ===========================================================================
# Build track
# ===========================================================================

test_missing_build_label_denies if {
	i := patch(base_build, [{"op": "remove", "path": "/image/labels/org.opencontainers.image.source"}])
	d := pdp.decision with input as i
	"BUILD_LABEL_MISSING" in codes(d)
}

# The classic symptom of a pre-FROM ARG not re-declared after FROM.
test_empty_build_label_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/image/labels/org.opencontainers.image.version", "value": "  "}])
	d := pdp.decision with input as i
	"BUILD_LABEL_EMPTY" in codes(d)
}

test_base_digest_mismatch_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/build/base_image_digest", "value": D}])
	d := pdp.decision with input as i
	"BUILD_BASE_DIGEST_MISMATCH" in codes(d)
}

test_label_disagrees_with_observed_base_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/image/labels/io.infrashift.image.upstream.digest", "value": D}])
	d := pdp.decision with input as i
	"BUILD_LABEL_DIGEST_DISAGREES" in codes(d)
}

test_source_ref_mismatch_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/build/source_revision", "value": "0000000000000000000000000000000000000000"}])
	d := pdp.decision with input as i
	"BUILD_SOURCE_REF_MISMATCH" in codes(d)
}

# A tag is not a pin -- it can be moved or force-pushed.
test_source_ref_as_tag_denies if {
	i := patch(base_build, [
		{"op": "replace", "path": "/build/source_revision", "value": "v26.2.0"},
		{"op": "replace", "path": "/build/pinned_source_ref", "value": "v26.2.0"},
		{"op": "replace", "path": "/image/labels/org.opencontainers.image.revision", "value": "v26.2.0"},
	])
	d := pdp.decision with input as i
	"BUILD_SOURCE_REF_NOT_PINNED" in codes(d)
}

test_dual_provenance_not_recorded_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/build/dual_provenance/performed", "value": false}])
	d := pdp.decision with input as i
	"DUAL_PROVENANCE_NOT_RECORDED" in codes(d)
}

test_dual_provenance_malformed_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/build/dual_provenance/from_source_sha256", "value": "nothex"}])
	d := pdp.decision with input as i
	"DUAL_PROVENANCE_MALFORMED" in codes(d)
}

test_dual_provenance_unpinned_reference_denies if {
	i := patch(base_build, [{"op": "replace", "path": "/build/dual_provenance/official_image_digest", "value": D2}])
	d := pdp.decision with input as i
	"DUAL_PROVENANCE_REFERENCE_UNPINNED" in codes(d)
}

# THE load-bearing test for dual provenance: the baseline already has
# mismatched hashes and still allows. Go builds are not bit-reproducible; if
# anyone promotes this to a gate, this test fails and points at the skill card.
test_dual_provenance_mismatch_does_not_gate if {
	d := pdp.decision with input as base_build
	d.allow
	some o in d.observations
	o.code == "DUAL_PROVENANCE"
	o.match == false
	o.gating == false
}

test_dual_provenance_match_is_recorded if {
	i := patch(base_build, [{"op": "replace", "path": "/build/dual_provenance/official_image_sha256", "value": "aaaa000000000000000000000000000000000000000000000000000000000000"}])
	d := pdp.decision with input as i
	d.allow
	some o in d.observations
	o.match == true
}

# ===========================================================================
# First-party build mode (ADR-008)
#
# Our own infrashift/* services have no vendor binary. The mode is an explicit,
# reasoned declaration in versions.json that the review actor re-derives from
# the checkout. Every test below that expects a specific code ALSO expects
# DUAL_PROVENANCE_NOT_RECORDED: the specific rule says why, the backstop is
# what denies if a specific rule is ever deleted.
# ===========================================================================

FP_REASON := "keto-cue is an infrashift fork of Ory Keto; infrashift is the only publisher, so no vendor binary exists."

FP_HASH := "aaaa000000000000000000000000000000000000000000000000000000000000"

base_first_party := patch(base_build, [
	{"op": "replace", "path": "/image/key", "value": "keto-cue"},
	{"op": "replace", "path": "/image/labels/org.opencontainers.image.source", "value": "https://github.com/infrashift/keto-cue"},
	{"op": "remove", "path": "/build/pinned_crosscheck_digest"},
	{"op": "replace", "path": "/build/dual_provenance", "value": {"performed": false, "from_source_sha256": FP_HASH}},
	{"op": "replace", "path": "/build/first_party", "value": {
		"declared": true,
		"crosscheck_pinned": false,
		"reason": FP_REASON,
		"source_url": "https://github.com/infrashift/keto-cue",
		"built_source_url": "https://github.com/infrashift/keto-cue",
		"evidence_mode": "first-party",
	}},
])

fp_denied_with(i, code) if {
	d := pdp.decision with input as i
	not d.allow
	d.namespace == "quarantine"
	code in codes(d)
	"DUAL_PROVENANCE_NOT_RECORDED" in codes(d)
}

# The baseline must pass, or every negative test below is vacuous.
test_base_first_party_allows if {
	d := pdp.decision with input as base_first_party
	d.allow
	d.namespace == "trusted"
	some o in d.observations
	o.code == "FIRST_PARTY_BUILD"
	o.gating == false
	o.from_source_sha256 == FP_HASH
	not "DUAL_PROVENANCE" in {x.code | some x in d.observations}
}

# A vendor build gets no first-party observation.
test_vendor_build_has_no_first_party_observation if {
	d := pdp.decision with input as base_build
	not "FIRST_PARTY_BUILD" in {x.code | some x in d.observations}
}

# Nor does a declaration that fails a condition: the signed verdict must not
# record "first-party build" for an image the mode does not cover.
test_invalid_first_party_has_no_first_party_observation if {
	i := patch(base_first_party, [
		{"op": "replace", "path": "/build/first_party/source_url", "value": "https://github.com/ory/keto"},
		{"op": "replace", "path": "/build/first_party/built_source_url", "value": "https://github.com/ory/keto"},
	])
	d := pdp.decision with input as i
	not "FIRST_PARTY_BUILD" in {x.code | some x in d.observations}
}

# Absence never means first-party: a build with no comparison and no
# first-party block at all is denied.
test_absent_first_party_block_is_not_first_party if {
	i := patch(base_first_party, [{"op": "remove", "path": "/build/first_party"}])
	fp_denied_with(i, "PROVENANCE_MODE_MISMATCH")
}

# The build actor cannot choose the mode: evidence that claims first-party for
# an image versions.json does not declare first-party is denied.
test_build_actor_cannot_claim_first_party if {
	i := patch(base_first_party, [{"op": "replace", "path": "/build/first_party/declared", "value": false}])
	fp_denied_with(i, "PROVENANCE_MODE_MISMATCH")
}

# A string is not a boolean declaration.
test_first_party_declared_as_string_is_not_declared if {
	i := patch(base_first_party, [{"op": "replace", "path": "/build/first_party/declared", "value": "true"}])
	fp_denied_with(i, "PROVENANCE_MODE_MISMATCH")
}

test_first_party_evidence_mode_absent_denies if {
	i := patch(base_first_party, [{"op": "remove", "path": "/build/first_party/evidence_mode"}])
	fp_denied_with(i, "PROVENANCE_MODE_MISMATCH")
}

# The other direction: versions.json declares first-party, the build reports
# that it ran a vendor comparison.
test_vendor_evidence_for_first_party_entry_denies if {
	i := patch(base_first_party, [{"op": "replace", "path": "/build/first_party/evidence_mode", "value": "vendor-crosscheck"}])
	fp_denied_with(i, "PROVENANCE_MODE_MISMATCH")
}

# On a vendor build the reported mode must also be present and agree.
test_vendor_build_with_absent_evidence_mode_denies if {
	i := patch(base_build, [{"op": "remove", "path": "/build/first_party/evidence_mode"}])
	d := pdp.decision with input as i
	not d.allow
	"PROVENANCE_MODE_MISMATCH" in codes(d)
}

# Only github.com/infrashift/* may be first-party. Look-alikes too.
test_first_party_vendor_source_denies if {
	every url in [
		"https://github.com/ory/keto",
		"https://github.com/infrashift.evil/keto-cue",
		"https://github.com/infrashiftx/keto-cue",
		"https://github.com/infrashift/../ory/keto",
		"https://github.com/infrashift/keto-cue/../../ory/keto",
		"https://github.com/infrashift/",
		"https://github.com/infrashift/.hidden",
		"http://github.com/infrashift/keto-cue",
		"git+https://github.com/infrashift/keto-cue",
		"https://gitlab.com/infrashift/keto-cue",
	] {
		i := patch(base_first_party, [
			{"op": "replace", "path": "/build/first_party/source_url", "value": url},
			{"op": "replace", "path": "/build/first_party/built_source_url", "value": url},
		])
		fp_denied_with(i, "FIRST_PARTY_SOURCE_NOT_INFRASHIFT")
	}
}

test_first_party_source_absent_denies if {
	i := patch(base_first_party, [
		{"op": "remove", "path": "/build/first_party/source_url"},
		{"op": "remove", "path": "/build/first_party/built_source_url"},
	])
	fp_denied_with(i, "FIRST_PARTY_SOURCE_NOT_INFRASHIFT")
}

test_first_party_reason_missing_denies if {
	every r in [null, "", "own image", "                                                    ", 42] {
		i := patch(base_first_party, [{"op": "replace", "path": "/build/first_party/reason", "value": r}])
		fp_denied_with(i, "FIRST_PARTY_REASON_MISSING")
	}
}

test_first_party_with_crosscheck_pin_denies if {
	i := patch(base_first_party, [{"op": "replace", "path": "/build/first_party/crosscheck_pinned", "value": true}])
	fp_denied_with(i, "FIRST_PARTY_WITH_CROSSCHECK")
}

# The review must STATE that no crosscheck is pinned; silence is not "none".
test_first_party_crosscheck_pinned_absent_denies if {
	i := patch(base_first_party, [{"op": "remove", "path": "/build/first_party/crosscheck_pinned"}])
	fp_denied_with(i, "FIRST_PARTY_WITH_CROSSCHECK")
}

test_first_party_built_from_other_source_denies if {
	i := patch(base_first_party, [{"op": "replace", "path": "/build/first_party/built_source_url", "value": "https://github.com/ory/keto"}])
	fp_denied_with(i, "FIRST_PARTY_SOURCE_URL_DISAGREES")
}

test_first_party_built_source_absent_denies if {
	i := patch(base_first_party, [{"op": "remove", "path": "/build/first_party/built_source_url"}])
	fp_denied_with(i, "FIRST_PARTY_SOURCE_URL_DISAGREES")
}

# No vendor hash, but our own hash is still mandatory and well-formed.
test_first_party_own_hash_malformed_denies if {
	every h in ["", "nothex", "AAAA000000000000000000000000000000000000000000000000000000000000"] {
		i := patch(base_first_party, [{"op": "replace", "path": "/build/dual_provenance/from_source_sha256", "value": h}])
		fp_denied_with(i, "DUAL_PROVENANCE_MALFORMED")
	}
}

test_first_party_own_hash_absent_denies if {
	i := patch(base_first_party, [{"op": "remove", "path": "/build/dual_provenance/from_source_sha256"}])
	fp_denied_with(i, "DUAL_PROVENANCE_MALFORMED")
}

# `performed` must be an explicit false. Absent is not "first-party, no
# comparison"; it is "nobody said".
test_first_party_performed_absent_denies if {
	i := patch(base_first_party, [{"op": "remove", "path": "/build/dual_provenance/performed"}])
	d := pdp.decision with input as i
	not d.allow
	"DUAL_PROVENANCE_NOT_RECORDED" in codes(d)
}

# First-party is a provenance mode, not CVE relief. The gate is unchanged.
test_first_party_gets_no_cve_relief if {
	i := patch(base_first_party, [
		{"op": "replace", "path": "/scan_results/critical_count", "value": 1},
		{"op": "replace", "path": "/scan_results/findings", "value": [{"id": "CVE-2026-0001", "severity": "Critical", "fix_state": "not-fixed", "package": "stdlib", "version": "1.26.10"}]},
	])
	d := pdp.decision with input as i
	not d.allow
	"CVE_CRITICAL" in codes(d)
}

# ===========================================================================
# The CVE gate
# ===========================================================================

crit := {"id": "CVE-2026-100", "severity": "Critical", "fix_state": "not-fixed", "package": "libcrit"}

high_fixed := {"id": "CVE-2026-200", "severity": "High", "fix_state": "fixed", "package": "libhigh"}

high_unfixed := {"id": "CVE-2026-300", "severity": "High", "fix_state": "not-fixed", "package": "libstuck"}

with_findings(base, fs, c, h) := json.patch(base, [
	{"op": "replace", "path": "/scan_results/findings", "value": fs},
	{"op": "replace", "path": "/scan_results/critical_count", "value": c},
	{"op": "replace", "path": "/scan_results/high_count", "value": h},
])

# Criticals block unconditionally, fix available or not.
test_unfixable_critical_still_denies if {
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
	"CVE_CRITICAL" in codes(d)
	not d.allow
	d.namespace == "quarantine"
}

test_fixable_high_denies if {
	d := pdp.decision with input as with_findings(base_mirror, [high_fixed], 0, 1)
	"CVE_HIGH_FIXABLE" in codes(d)
	not d.allow
}

# A stdlib finding on the build track is our compiler's, so the hint must
# point at the toolchain pin -- the generic build hint names only the base and
# the source, neither of which clears it. Every other package keeps that hint.
stdlib_crit := {"id": "GO-2026-6612", "severity": "Critical", "fix_state": "fixed", "package": "stdlib"}

hints(dec, code) := {v.package: v.remediation_hint | some v in dec.violations; v.code == code}

test_build_stdlib_finding_hints_at_the_toolchain if {
	d := pdp.decision with input as with_findings(base_build, [stdlib_crit, crit], 2, 0)
	h := hints(d, "CVE_CRITICAL")
	contains(h.stdlib, "toolchain")
	not contains(h.libcrit, "toolchain")
	contains(h.libcrit, "current base")
}

# On the mirror track stdlib is the vendor's, so the toolchain hint would be
# wrong advice.
test_mirror_stdlib_finding_keeps_the_track_hint if {
	d := pdp.decision with input as with_findings(base_mirror, [stdlib_crit], 1, 0)
	h := hints(d, "CVE_CRITICAL")
	not contains(h.stdlib, "toolchain")
}

# No action we control clears these, so blocking would gate every image on a
# vendor's backport schedule.
test_unfixable_high_is_recorded_not_blocking if {
	d := pdp.decision with input as with_findings(base_mirror, [high_unfixed], 0, 1)
	d.allow
	d.counts.recorded == 1
	d.counts.blocking == 0
	some f in d.findings
	f.state == "recorded"
}

# ===========================================================================
# Exceptions
# ===========================================================================

good_exc := {
	"id": "EXC-2026-0001", "image": "nexus3", "variant": "*", "package": "*",
	"cves": ["CVE-2026-100"],
	"issued": "2026-08-01T00:00:00Z", "expires": "2026-10-01T00:00:00Z",
	"owner": "@ryancraig", "ticket": "https://example.invalid/1",
	"justification": "Not reachable in our deployment topology; upstream fix expected next release.",
}

test_valid_exception_produces_waived_state if {
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [good_exc]
	d.allow
	d.counts.waived == 1
	d.counts.blocking == 0
	some f in d.findings
	f.state == "waived"
	f.waiver_id == "EXC-2026-0001"
	f.waiver_expires == "2026-10-01T00:00:00Z"
}

# Waived is never silently dropped: it must also surface as a warning.
test_waived_finding_surfaces_in_warnings if {
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [good_exc]
	some w in d.warnings
	w.code == "CVE_WAIVED"
	w.cve == "CVE-2026-100"
}

test_exception_missing_expires_waives_nothing if {
	e := object.remove(good_exc, {"expires"})
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [e]
	not d.allow
	"CVE_CRITICAL" in codes(d)
	"EXCEPTION_INVALID" in codes(d)
}

test_exception_missing_justification_waives_nothing if {
	e := object.remove(good_exc, {"justification"})
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [e]
	not d.allow
	"EXCEPTION_INVALID" in codes(d)
}

# "n/a" is not a justification.
test_exception_perfunctory_justification_waives_nothing if {
	e := object.union(good_exc, {"justification": "n/a"})
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [e]
	not d.allow
	"EXCEPTION_INVALID" in codes(d)
}

# Expiry judged against evaluated_at, never a wall clock.
test_expired_exception_waives_nothing if {
	e := object.union(good_exc, {"issued": "2026-05-01T00:00:00Z", "expires": "2026-07-01T00:00:00Z"})
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [e]
	not d.allow
	"CVE_CRITICAL" in codes(d)
}

# Longer than the 90-day cap: enforced in policy, not reviewer discipline.
test_overlong_exception_window_waives_nothing if {
	e := object.union(good_exc, {"issued": "2026-01-01T00:00:00Z", "expires": "2026-12-01T00:00:00Z"})
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [e]
	not d.allow
	"EXCEPTION_INVALID" in codes(d)
}

# Same input + same evaluated_at at two different real times => identical result.
test_expiry_is_deterministic if {
	i := with_findings(base_mirror, [crit], 1, 0)
	a := pdp.decision with input as i with data.exceptions as [good_exc]
	b := pdp.decision with input as i with data.exceptions as [good_exc]
	a == b
}

# Without a parseable clock, NOTHING is waived and the leg denies.
test_missing_evaluated_at_disables_all_waivers if {
	i := json.patch(with_findings(base_mirror, [crit], 1, 0), [{"op": "remove", "path": "/evaluated_at"}])
	d := pdp.decision with input as i with data.exceptions as [good_exc]
	not d.allow
	"INPUT_TIMESTAMP_INVALID" in codes(d)
	d.counts.waived == 0
}

test_exception_for_other_image_does_not_waive if {
	e := object.union(good_exc, {"image": "traefik"})
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [e]
	not d.allow
	"CVE_CRITICAL" in codes(d)
}

test_exception_for_other_package_does_not_waive if {
	e := object.union(good_exc, {"package": "something-else"})
	d := pdp.decision with input as with_findings(base_mirror, [crit], 1, 0)
		with data.exceptions as [e]
	not d.allow
}

# The structural guarantee: exceptions touch CVEs and nothing else.
test_exception_cannot_waive_signature_violation if {
	e := object.union(good_exc, {"cves": ["UPSTREAM_SIGNATURE_FAILED", "CVE-2026-100"]})
	i := json.patch(base_mirror, [{"op": "replace", "path": "/upstream/signature", "value": "failed"}])
	d := pdp.decision with input as i with data.exceptions as [e]
	not d.allow
	"UPSTREAM_SIGNATURE_FAILED" in codes(d)
}

test_exception_cannot_waive_mirror_drift if {
	i := json.patch(base_mirror, [{"op": "replace", "path": "/image/destination_digest", "value": D2}])
	d := pdp.decision with input as i with data.exceptions as [good_exc]
	not d.allow
	"MIRROR_DIGEST_DRIFT" in codes(d)
}

# ===========================================================================
# Enforcement mode
# ===========================================================================

# `observe` still computes and publishes every violation and still routes to
# quarantine. It is NOT a route into trusted/.
test_observe_allows_but_still_quarantines if {
	i := json.patch(with_findings(base_mirror, [crit], 1, 0), [{"op": "replace", "path": "/image/enforcement", "value": "observe"}])
	d := pdp.decision with input as i
	d.allow
	d.namespace == "quarantine"
	"CVE_CRITICAL" in codes(d)
}

test_unknown_enforcement_denies if {
	i := patch(base_mirror, [{"op": "replace", "path": "/image/enforcement", "value": "off"}])
	d := pdp.decision with input as i
	"INPUT_ENFORCEMENT_UNKNOWN" in codes(d)
}

# ===========================================================================
# Repo gate
# ===========================================================================

base_repo := {
	"evaluated_at": NOW,
	"gitleaks": {"status": "ran", "findings": [], "config_bytes": 2994, "uses_default_ruleset": true},
	"versions": {
		"sources": {
			"ory": {"track": "^v26\\.[0-9]+\\.[0-9]+$", "repos": {"kratos": {"url": "https://github.com/ory/kratos", "commit": COMMIT}}},
			"keto-cue": {"track": "^v0\\.0\\.0-[0-9]{14}-[0-9a-f]{12}$", "url": "https://github.com/infrashift/keto-cue", "commit": COMMIT},
		},
		"bases": {"ubi9-micro": {}},
		"images": {
			"nexus3": {
				"kind": "mirror", "upstreamTrust": "none", "upstreamRepo": "docker.io/sonatype/nexus3",
				"platforms": ["linux/amd64", "linux/arm64"],
				"variants": {"runtime": {"tag": "3.90.5-ubi", "track": "^3\\.90\\.[0-9]+-ubi$", "digest": D}},
			},
			"mssql": {
				"kind": "mirror", "upstreamTrust": "notation", "upstreamRepo": "mcr.microsoft.com/mssql/rhel/server",
				"keyring": ".github/pdp/keyring/microsoft-supply-chain-rsa-root-ca-2022.crt",
				"notation": {"trustedIdentity": "x509.subject: CN=Microsoft SCD Products RSA Signing,O=Microsoft Corporation,L=Redmond,ST=Washington,C=US"},
				"platforms": ["linux/amd64"],
				"variants": {"runtime": {"tag": "2025-latest", "track": "^2025-latest$", "digest": D2}},
			},
			"kratos": {
				"kind": "build", "upstreamTrust": "internal", "source": "ory",
				"toolchain": "go1.26", "base": "ubi9-micro", "caSource": "ubi9-minimal",
				"containerfile": "Containerfiles/kratos.Containerfile",
				"arches": ["amd64"], "crosscheck": {"amd64": {"digest": D}},
			},
			"keto-cue": {
				"kind": "build", "upstreamTrust": "internal", "source": "keto-cue",
				"toolchain": "go1.26", "base": "ubi9-micro", "caSource": "ubi9-minimal",
				"containerfile": "Containerfiles/keto-cue.Containerfile",
				"arches": ["amd64", "arm64"],
				"firstParty": {"noVendorBinary": true, "reason": FP_REASON},
			},
		},
	},
}

repo_codes(dec) := {v.code | some v in dec.violations}

test_base_repo_allows if {
	d := pdp.repo_decision with input as base_repo with data.exceptions as []
	d.allow
}

# A single-platform mirror entry passes the repo gate unchanged: platforms is
# checked for shape only, arity is a leg-time comparison against the manifest.
test_single_platform_repo_entry_allows if {
	d := pdp.repo_decision with input as base_repo with data.exceptions as []
	d.allow
	i := json.patch(base_repo, [{"op": "replace", "path": "/versions/images/mssql/platforms", "value": "linux/amd64"}])
	d2 := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_PLATFORMS_MISSING" in repo_codes(d2)
}

test_empty_repo_input_denies if {
	d := pdp.repo_decision with input as {} with data.exceptions as []
	not d.allow
}

# The 0-byte-config defect that let the reference attest to a scan finding
# nothing because every rule was disabled.
test_empty_gitleaks_config_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/gitleaks/config_bytes", "value": 0}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"GITLEAKS_CONFIG_EMPTY" in repo_codes(d)
}

test_gitleaks_not_run_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/gitleaks/status", "value": "skipped"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"GITLEAKS_DID_NOT_RUN" in repo_codes(d)
}

test_gitleaks_defaults_disabled_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/gitleaks/uses_default_ruleset", "value": false}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"GITLEAKS_DEFAULTS_DISABLED" in repo_codes(d)
}

test_secret_detected_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/gitleaks/findings", "value": [{"File": "a.key", "RuleID": "pem-private-key-block"}]}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"SECRET_DETECTED" in repo_codes(d)
}

# `3\.90\.` without anchors also matches `13.90.7`.
test_unanchored_track_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/nexus3/variants/runtime/track", "value": "3\\.90\\."}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_TRACK_UNANCHORED" in repo_codes(d)
}

# A track that does not contain its own pin is decorative.
test_track_not_matching_own_pin_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/nexus3/variants/runtime/tag", "value": "3.91.0-ubi"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_TRACK_MISMATCH" in repo_codes(d)
}

test_unpinned_digest_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/nexus3/variants/runtime/digest", "value": "3.90.5-ubi"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_DIGEST_INVALID" in repo_codes(d)
}

test_notation_entry_wrong_keyring_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/mssql/keyring", "value": ".github/pdp/keyring/dhi-latest.pub"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_NOTATION_KEYRING_INVALID" in repo_codes(d)
}

test_notation_entry_without_identity_denies if {
	i := patch(base_repo, [{"op": "remove", "path": "/versions/images/mssql/notation"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_NOTATION_IDENTITY_MISSING" in repo_codes(d)
}

# CN-less identity: well-formed for notation, but it matches every leaf.
test_notation_entry_cnless_identity_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/mssql/notation/trustedIdentity", "value": "x509.subject: O=Microsoft Corporation,ST=Washington,C=US"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_NOTATION_IDENTITY_MISSING" in repo_codes(d)
}

test_dhi_class_on_non_dhi_repo_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/nexus3/upstreamTrust", "value": "dhi"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_DHI_REPO_INVALID" in repo_codes(d)
}

test_source_commit_as_tag_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/sources/ory/repos/kratos/commit", "value": "v26.2.0"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_SOURCE_REF_NOT_PINNED" in repo_codes(d)
}

test_build_entry_dangling_source_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/kratos/source", "value": "nope"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_BUILD_SOURCE_DANGLING" in repo_codes(d)
}

test_build_entry_wrong_trust_class_denies if {
	i := patch(base_repo, [{"op": "replace", "path": "/versions/images/kratos/upstreamTrust", "value": "none"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_BUILD_TRUST_CLASS_INVALID" in repo_codes(d)
}

# --- First-party entries at the repo gate (ADR-008) -------------------------

repo_denied_with(i, code) if {
	d := pdp.repo_decision with input as i with data.exceptions as []
	not d.allow
	code in repo_codes(d)
}

# The baseline carries a valid first-party entry and allows (test_base_repo_allows);
# this makes the dependency explicit.
test_first_party_entry_without_crosscheck_allows if {
	d := pdp.repo_decision with input as base_repo with data.exceptions as []
	d.allow
	not "VERSIONS_CROSSCHECK_DIGEST_INVALID" in repo_codes(d)
}

# Absence of crosscheck is not a first-party claim.
test_build_entry_with_neither_mode_denies if {
	i := patch(base_repo, [{"op": "remove", "path": "/versions/images/keto-cue/firstParty"}])
	repo_denied_with(i, "VERSIONS_PROVENANCE_MODE_MISSING")
	repo_denied_with(i, "VERSIONS_CROSSCHECK_DIGEST_INVALID")
}

test_build_entry_with_both_modes_denies if {
	i := patch(base_repo, [{"op": "add", "path": "/versions/images/keto-cue/crosscheck", "value": {"amd64": {"digest": D}, "arm64": {"digest": D}}}])
	repo_denied_with(i, "VERSIONS_FIRST_PARTY_CONFLICT")
}

# Both modes, but with a broken crosscheck: the first-party declaration must
# not excuse it.
test_first_party_does_not_excuse_a_present_crosscheck if {
	i := patch(base_repo, [{"op": "add", "path": "/versions/images/keto-cue/crosscheck", "value": {}}])
	repo_denied_with(i, "VERSIONS_CROSSCHECK_DIGEST_INVALID")
}

test_first_party_declaration_malformed_denies if {
	every fp in [
		{"noVendorBinary": false, "reason": FP_REASON},
		{"noVendorBinary": "true", "reason": FP_REASON},
		{"reason": FP_REASON},
		{"noVendorBinary": true},
		{"noVendorBinary": true, "reason": "ours"},
		true,
	] {
		i := patch(base_repo, [{"op": "replace", "path": "/versions/images/keto-cue/firstParty", "value": fp}])
		repo_denied_with(i, "VERSIONS_FIRST_PARTY_MALFORMED")
		repo_denied_with(i, "VERSIONS_CROSSCHECK_DIGEST_INVALID")
	}
}

# The hole the mode would open without this rule: mark a vendor image
# first-party to skip its cross-check.
test_first_party_on_vendor_source_denies if {
	every url in [
		"https://github.com/ory/keto",
		"https://github.com/infrashift.evil/keto-cue",
		"https://github.com/infrashift/../ory/keto",
		"http://github.com/infrashift/keto-cue",
	] {
		i := patch(base_repo, [{"op": "replace", "path": "/versions/sources/keto-cue/url", "value": url}])
		repo_denied_with(i, "VERSIONS_FIRST_PARTY_SOURCE_NOT_INFRASHIFT")
		repo_denied_with(i, "VERSIONS_CROSSCHECK_DIGEST_INVALID")
	}
}

test_first_party_source_without_url_denies if {
	i := patch(base_repo, [{"op": "remove", "path": "/versions/sources/keto-cue/url"}])
	repo_denied_with(i, "VERSIONS_FIRST_PARTY_SOURCE_NOT_INFRASHIFT")
}

# A repo-keyed source (Ory) resolves through sources.<s>.repos.<r>.url: kratos
# swapping its crosscheck for a firstParty block is denied.
test_first_party_on_repo_keyed_vendor_source_denies if {
	i := patch(base_repo, [
		# A decoy top-level url under infrashift: the repo key must win.
		{"op": "add", "path": "/versions/sources/ory/url", "value": "https://github.com/infrashift/keto-cue"},
		{"op": "add", "path": "/versions/images/kratos/repo", "value": "kratos"},
		{"op": "remove", "path": "/versions/images/kratos/crosscheck"},
		{"op": "add", "path": "/versions/images/kratos/firstParty", "value": {"noVendorBinary": true, "reason": FP_REASON}},
	])
	repo_denied_with(i, "VERSIONS_FIRST_PARTY_SOURCE_NOT_INFRASHIFT")
	repo_denied_with(i, "VERSIONS_CROSSCHECK_DIGEST_INVALID")
}

# ...and the same entry is accepted when the repo key resolves to infrashift,
# which proves the lookup follows `repo` rather than `sources.<s>.url`.
test_first_party_on_repo_keyed_infrashift_source_allows if {
	i := patch(base_repo, [
		{"op": "add", "path": "/versions/sources/ory/url", "value": "https://github.com/ory/kratos"},
		{"op": "replace", "path": "/versions/sources/ory/repos/kratos/url", "value": "https://github.com/infrashift/kratos-fork"},
		{"op": "add", "path": "/versions/images/kratos/repo", "value": "kratos"},
		{"op": "remove", "path": "/versions/images/kratos/crosscheck"},
		{"op": "add", "path": "/versions/images/kratos/firstParty", "value": {"noVendorBinary": true, "reason": FP_REASON}},
	])
	d := pdp.repo_decision with input as i with data.exceptions as []
	d.allow
}

# What makes Dapr's three images structurally incapable of drifting apart.
test_lockstep_mismatch_denies if {
	i := patch(base_repo, [{"op": "add", "path": "/versions/sources/ory/lockstep", "value": ["kratos", "hydra"]}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_LOCKSTEP_MISMATCH" in repo_codes(d)
}

test_lockstep_exact_match_allows if {
	i := patch(base_repo, [{"op": "add", "path": "/versions/sources/ory/lockstep", "value": ["kratos"]}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	d.allow
}

test_orphaned_exception_denies if {
	e := object.union(good_exc, {"image": "no-such-image"})
	d := pdp.repo_decision with input as base_repo with data.exceptions as [e]
	"EXCEPTION_ORPHANED" in repo_codes(d)
}

test_duplicate_exception_id_denies if {
	d := pdp.repo_decision with input as base_repo with data.exceptions as [good_exc, good_exc]
	"EXCEPTION_DUPLICATE_ID" in repo_codes(d)
}

# ===========================================================================
# Dev variants are recognised by SHAPE, not by the literal string "dev".
#
# `variant != "dev"` was correct while the only variants were runtime and dev.
# The postgres 17 pair added dev17, and the literal stopped covering it: the
# same upstream dev image warned on 17 and not on 16. These tests fail against
# that version of the rule.
# ===========================================================================
warn_codes(dec) := {w.code | some w in dec.warnings}

# The baseline case that always worked, kept so a fix cannot regress it.
test_dev_variant_root_is_not_warned if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/image/variant", "value": "dev"},
		{"op": "replace", "path": "/image/config_user", "value": "root"},
	])
	d := pdp.decision with input as i
	not "RUNTIME_RUNS_AS_ROOT" in warn_codes(d)
	d.dev_variant == true
}

# The bug: dev17 is a dev variant and must be exempt exactly as dev is.
test_dev_major_suffixed_variant_root_is_not_warned if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/image/variant", "value": "dev17"},
		{"op": "replace", "path": "/image/config_user", "value": "root"},
	])
	d := pdp.decision with input as i
	not "RUNTIME_RUNS_AS_ROOT" in warn_codes(d)
	d.dev_variant == true
}

# The exemption must not leak the other way: a runtime variant still warns,
# with or without a major suffix.
test_runtime_variant_root_is_warned if {
	i := patch(base_mirror, [{"op": "replace", "path": "/image/config_user", "value": "root"}])
	d := pdp.decision with input as i
	"RUNTIME_RUNS_AS_ROOT" in warn_codes(d)
	d.dev_variant == false
}

test_runtime_major_suffixed_variant_root_is_warned if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/image/variant", "value": "runtime17"},
		{"op": "replace", "path": "/image/config_user", "value": "root"},
	])
	d := pdp.decision with input as i
	"RUNTIME_RUNS_AS_ROOT" in warn_codes(d)
	d.dev_variant == false
}

# "devel" is not "dev<major>". It must NOT pick up the exemption by prefix --
# an unrecognised name lands on the conservative side and still warns.
test_devlike_variant_does_not_inherit_the_exemption if {
	i := patch(base_mirror, [
		{"op": "replace", "path": "/image/variant", "value": "devel"},
		{"op": "replace", "path": "/image/config_user", "value": "root"},
	])
	d := pdp.decision with input as i
	"RUNTIME_RUNS_AS_ROOT" in warn_codes(d)
	d.dev_variant == false
}

# A missing variant must not become a dev variant by accident, and must not
# make the decision object undefined -- that is what `default false` buys.
test_absent_variant_is_not_a_dev_variant if {
	i := patch(base_mirror, [
		{"op": "remove", "path": "/image/variant"},
		{"op": "replace", "path": "/image/config_user", "value": "root"},
	])
	d := pdp.decision with input as i
	d.dev_variant == false
	"RUNTIME_RUNS_AS_ROOT" in warn_codes(d)
}

# --- The convention itself, enforced at the repo gate ----------------------

test_variant_names_in_versions_are_conventional if {
	d := pdp.repo_decision with input as base_repo with data.exceptions as []
	not "VERSIONS_VARIANT_NAME_INVALID" in repo_codes(d)
}

test_unconventional_variant_name_denies if {
	i := patch(base_repo, [{"op": "add", "path": "/versions/images/nexus3/variants/devel", "value": {"tag": "3.90.5-ubi", "track": "^3\\.90\\.[0-9]+-ubi$", "digest": D}}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	"VERSIONS_VARIANT_NAME_INVALID" in repo_codes(d)
}

test_dev_major_variant_name_is_accepted if {
	i := patch(base_repo, [{"op": "add", "path": "/versions/images/nexus3/variants/dev17", "value": {"tag": "3.90.5-ubi", "track": "^3\\.90\\.[0-9]+-ubi$", "digest": D}}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	not "VERSIONS_VARIANT_NAME_INVALID" in repo_codes(d)
}

# ===========================================================================
# Package track (ADR-009)
#
# Each test below breaks ONE fact of a known-good package leg and expects the
# specific code AND the catch-all PACKAGE_VERIFICATION_NOT_RECORDED. A deleted
# specific rule fails the first assertion; a predicate that loses a condition
# fails the second.
# ===========================================================================

PG_KEY_FPR := "D4BF08AE67A0B4C7A1DBCCD240BCA2B408B40D20"

PG_KEY_ID := "40bca2b408b40d20"

PG_KEY_SHA := "a70c9527426017d00fa4e6f9d2941d515357a27a7be82e155248ece53bbe5453"

PG_URL := "https://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-x86_64"

PG_N1 := "postgresql17-17.12-1PGDG.rhel9.8.x86_64"

PG_N2 := "postgresql17-libs-17.12-1PGDG.rhel9.8.x86_64"

PG_N3 := "postgresql17-server-17.12-1PGDG.rhel9.8.x86_64"

UBI_N := "krb5-libs-1.21.1-10.el9_8.1.x86_64"

base_package := {
	"track": "package",
	"evaluated_at": NOW,
	"image": {
		"key": "postgresql17", "variant": "runtime", "enforcement": "enforce",
		"destination_repo": "ghcr.io/infrashift/trusted-service-containers/development/postgresql17",
		"destination_digest": D, "config_user": "26",
		"labels": {
			"org.opencontainers.image.source": PG_URL,
			"org.opencontainers.image.revision": "17.12-1PGDG.rhel9.8",
			"org.opencontainers.image.version": "17.12",
			"io.infrashift.image.upstream.digest": D2,
			"io.infrashift.image.upstream.source": "ghcr.io/infrashift/trusted-base-images/trusted/ubi9-minimal",
		},
	},
	"upstream": {
		"trust_class": "internal", "signature": "verified",
		"verified_with": ".github/pdp/public-keys/upstream/trusted-base-images-release.pub",
		"attestations": {"sbom": "present", "provenance": "present", "vex": "absent"},
	},
	"package": {
		"pinned_base_repo": "ghcr.io/infrashift/trusted-base-images/trusted/ubi9-minimal",
		"base_image_repo": "ghcr.io/infrashift/trusted-base-images/trusted/ubi9-minimal",
		"pinned_base_digest": D2, "base_image_digest": D2,
		"pinned_repo_url": PG_URL, "repo_url": PG_URL,
		"gpgcheck": "1", "repo_gpgcheck": "1",
		"pinned_key_fingerprint": PG_KEY_FPR, "key_fingerprint": PG_KEY_FPR,
		"pinned_key_sha256": PG_KEY_SHA, "key_sha256": PG_KEY_SHA,
		"pinned_version": "17.12",
		"pinned_nevras": [PG_N1, PG_N2, PG_N3],
		"installed_nevras": [PG_N1, PG_N2, PG_N3, UBI_N],
		"verified_nevras": [PG_N1, PG_N2, PG_N3],
		"signatures": [
			{"nevra": PG_N1, "key_id": PG_KEY_ID},
			{"nevra": PG_N2, "key_id": PG_KEY_ID},
			{"nevra": PG_N3, "key_id": PG_KEY_ID},
			{"nevra": UBI_N, "key_id": "199e2f91fd431d51"},
		],
		"verification": {"performed": true},
	},
	"scan_results": {
		"critical_count": 0, "high_count": 0, "medium_count": 0, "low_count": 0,
		"fixable_critical_count": 0, "fixable_high_count": 0, "findings": [],
	},
	"published_attestation_keys": {},
}

package_denies(ops, code) if {
	d := pdp.decision with input as patch(base_package, ops)
	not d.allow
	d.namespace == "quarantine"
	code in codes(d)
	"PACKAGE_VERIFICATION_NOT_RECORDED" in codes(d)
}

test_base_package_allows if {
	d := pdp.decision with input as base_package
	d.allow
	d.namespace == "trusted"
	some o in d.observations
	o.code == "PACKAGE_PROVENANCE"
	o.gating == false
}

# A package leg is not a build leg: no source commit and no cross-check are
# asked of it, and none of their codes fire.
test_package_needs_no_source_or_crosscheck if {
	d := pdp.decision with input as base_package
	not "BUILD_SOURCE_REF_MISMATCH" in codes(d)
	not "DUAL_PROVENANCE_NOT_RECORDED" in codes(d)
}

# ...and a build leg cannot pass as a package leg by carrying a package block.
test_build_leg_with_package_block_still_needs_crosscheck if {
	i := patch(base_build, [
		{"op": "add", "path": "/package", "value": base_package.package},
		{"op": "replace", "path": "/build/dual_provenance/performed", "value": false},
	])
	d := pdp.decision with input as i
	"DUAL_PROVENANCE_NOT_RECORDED" in codes(d)
}

test_package_absent_block_denies if {
	d := pdp.decision with input as json.remove(base_package, ["package"])
	not d.allow
	"PACKAGE_VERIFICATION_NOT_RECORDED" in codes(d)
	"PACKAGE_PIN_MALFORMED" in codes(d)
	"PACKAGE_EVIDENCE_MALFORMED" in codes(d)
	"BUILD_BASE_DIGEST_MISMATCH" in codes(d)
}

test_package_verification_not_performed_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/package/verification/performed", "value": "true"}])
	not d.allow
	"PACKAGE_VERIFICATION_NOT_RECORDED" in codes(d)
}

test_package_label_missing_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "remove", "path": "/image/labels/org.opencontainers.image.revision"}])
	not d.allow
	"BUILD_LABEL_MISSING" in codes(d)
	"PACKAGE_REVISION_LABEL_DISAGREES" in codes(d)
}

test_package_label_empty_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/image/labels/io.infrashift.image.upstream.source", "value": ""}])
	not d.allow
	"BUILD_LABEL_EMPTY" in codes(d)
}

test_package_base_digest_mismatch_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/package/base_image_digest", "value": D}])
	"BUILD_BASE_DIGEST_MISMATCH" in codes(d)
	"BUILD_LABEL_DIGEST_DISAGREES" in codes(d)
}

test_package_base_repo_mismatch_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/package/base_image_repo", "value": "ghcr.io/evil/ubi9-minimal"}])
	"BUILD_BASE_REPO_MISMATCH" in codes(d)
}

test_package_base_digest_malformed_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "remove", "path": "/package/base_image_digest"}])
	some v in d.violations
	v.code == "INPUT_DIGEST_MALFORMED"
	v.field == "package.base_image_digest"
}

test_package_pin_malformed_denies if {
	package_denies([{"op": "replace", "path": "/package/pinned_nevras", "value": ["postgresql17-server"]}], "PACKAGE_PIN_MALFORMED")
}

test_package_empty_pins_deny if {
	package_denies([{"op": "replace", "path": "/package/pinned_nevras", "value": []}], "PACKAGE_PIN_MALFORMED")
}

test_package_pinned_fingerprint_malformed_denies if {
	package_denies(
		[
			{"op": "replace", "path": "/package/pinned_key_fingerprint", "value": "40BCA2B408B40D20"},
			{"op": "replace", "path": "/package/key_fingerprint", "value": "40BCA2B408B40D20"},
		],
		"PACKAGE_PIN_MALFORMED",
	)
}

test_package_evidence_malformed_denies if {
	package_denies([{"op": "replace", "path": "/package/signatures", "value": [{"nevra": PG_N1}]}], "PACKAGE_EVIDENCE_MALFORMED")
}

# Every other fact holds: one extra signature record has a numeric key_id.
# Only the shape check sees it.
test_package_signature_record_malformed_denies if {
	package_denies([{"op": "add", "path": "/package/signatures/-", "value": {"nevra": PG_N1, "key_id": 40}}], "PACKAGE_EVIDENCE_MALFORMED")
}

test_package_verified_list_not_a_list_denies if {
	package_denies([{"op": "replace", "path": "/package/verified_nevras", "value": PG_N1}], "PACKAGE_EVIDENCE_MALFORMED")
}

# The pinned and the observed sha256 agree, but neither is a sha256. Only the
# shape check of the pins sees it.
test_package_key_sha_not_a_sha_denies if {
	package_denies(
		[
			{"op": "replace", "path": "/package/pinned_key_sha256", "value": "unknown"},
			{"op": "replace", "path": "/package/key_sha256", "value": "unknown"},
		],
		"PACKAGE_PIN_MALFORMED",
	)
}

test_package_pinned_version_absent_denies if {
	package_denies([{"op": "remove", "path": "/package/pinned_version"}], "PACKAGE_PIN_MALFORMED")
}

test_package_repo_mismatch_denies if {
	package_denies([{"op": "replace", "path": "/package/repo_url", "value": "https://evil.example/rhel-9-x86_64"}], "PACKAGE_REPO_MISMATCH")
}

test_package_repo_both_absent_denies if {
	package_denies(
		[
			{"op": "remove", "path": "/package/repo_url"},
			{"op": "remove", "path": "/package/pinned_repo_url"},
		],
		"PACKAGE_REPO_MISMATCH",
	)
}

test_package_gpgcheck_off_denies if {
	package_denies([{"op": "replace", "path": "/package/gpgcheck", "value": "0"}], "PACKAGE_GPGCHECK_DISABLED")
}

test_package_repo_gpgcheck_absent_denies if {
	package_denies([{"op": "remove", "path": "/package/repo_gpgcheck"}], "PACKAGE_GPGCHECK_DISABLED")
}

test_package_key_fingerprint_mismatch_denies if {
	package_denies([{"op": "replace", "path": "/package/key_fingerprint", "value": "B031F89FC983E98262906B6E177B343BB9738825"}], "PACKAGE_KEY_FINGERPRINT_MISMATCH")
}

test_package_key_sha256_mismatch_denies if {
	package_denies([{"op": "replace", "path": "/package/key_sha256", "value": "cc506fa92aa97e8e58f88551a2ec99a61d9d603f7f2c1ae0c06191f58c29979f"}], "PACKAGE_KEY_SHA256_MISMATCH")
}

test_package_key_sha256_both_absent_denies if {
	package_denies(
		[
			{"op": "remove", "path": "/package/key_sha256"},
			{"op": "remove", "path": "/package/pinned_key_sha256"},
		],
		"PACKAGE_KEY_SHA256_MISMATCH",
	)
}

# The pinned server is missing from the live image: the review saw a
# different package set than versions.json pins.
test_package_nevra_not_installed_denies if {
	package_denies([{"op": "replace", "path": "/package/installed_nevras", "value": [PG_N1, PG_N2, UBI_N]}], "PACKAGE_NEVRA_NOT_INSTALLED")
}

# A newer release in the repository is not the pinned NEVRA.
test_package_other_release_installed_denies if {
	package_denies([{"op": "replace", "path": "/package/installed_nevras/2", "value": "postgresql17-server-17.12-2PGDG.rhel9.8.x86_64"}], "PACKAGE_NEVRA_NOT_INSTALLED")
}

test_package_nevra_not_verified_denies if {
	package_denies([{"op": "replace", "path": "/package/verified_nevras", "value": [PG_N1, PG_N2]}], "PACKAGE_NEVRA_NOT_VERIFIED")
}

test_package_signature_by_other_key_denies if {
	package_denies([{"op": "replace", "path": "/package/signatures/2/key_id", "value": "177b343bb9738825"}], "PACKAGE_SIGNATURE_UNVERIFIED")
}

test_package_unsigned_denies if {
	package_denies([{"op": "replace", "path": "/package/signatures/2/key_id", "value": "(none)"}], "PACKAGE_SIGNATURE_UNVERIFIED")
}

# rpm prints the key ID in lower case; a fingerprint pin in upper case must
# still match it, and an upper-case recording must too.
test_package_signature_key_id_case_insensitive if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/package/signatures/0/key_id", "value": "40BCA2B408B40D20"}])
	d.allow
}

test_package_unpinned_package_from_repo_denies if {
	extra := "postgresql17-contrib-17.12-1PGDG.rhel9.8.x86_64"
	package_denies(
		[
			{"op": "add", "path": "/package/installed_nevras/-", "value": extra},
			{"op": "add", "path": "/package/signatures/-", "value": {"nevra": extra, "key_id": PG_KEY_ID}},
		],
		"PACKAGE_UNPINNED_FROM_REPO",
	)
}

# The build leaves the extra package out of its signature list. The review
# sees it in the live image, so the list is incomplete.
test_package_signature_list_omits_a_package_denies if {
	package_denies([{"op": "add", "path": "/package/installed_nevras/-", "value": "postgresql17-contrib-17.12-1PGDG.rhel9.8.x86_64"}], "PACKAGE_SIGNATURE_SET_INCOMPLETE")
}

test_package_both_sets_empty_denies if {
	package_denies(
		[
			{"op": "replace", "path": "/package/installed_nevras", "value": []},
			{"op": "replace", "path": "/package/signatures", "value": []},
		],
		"PACKAGE_SIGNATURE_SET_INCOMPLETE",
	)
}

test_package_version_label_disagrees_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/image/labels/org.opencontainers.image.version", "value": "17.11"}])
	not d.allow
	"PACKAGE_VERSION_LABEL_DISAGREES" in codes(d)
}

test_package_revision_label_disagrees_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/image/labels/org.opencontainers.image.revision", "value": "17.12-2PGDG.rhel9.8"}])
	not d.allow
	"PACKAGE_REVISION_LABEL_DISAGREES" in codes(d)
}

test_package_source_label_disagrees_denies if {
	d := pdp.decision with input as patch(base_package, [{"op": "replace", "path": "/image/labels/org.opencontainers.image.source", "value": "https://github.com/postgres/postgres"}])
	not d.allow
	"PACKAGE_SOURCE_LABEL_DISAGREES" in codes(d)
}

# One CVE gate: the package track gets no relief, and a waiver still applies
# only through the register.
test_package_track_has_the_same_cve_gate if {
	i := with_findings(base_package, [crit], 1, 0)
	d := pdp.decision with input as i
	not d.allow
	"CVE_CRITICAL" in codes(d)
	some v in d.violations
	v.code == "CVE_CRITICAL"
	contains(v.remediation_hint, "UBI repositories")
}

test_package_observe_still_quarantines if {
	i := patch(base_package, [
		{"op": "replace", "path": "/image/enforcement", "value": "observe"},
		{"op": "replace", "path": "/package/gpgcheck", "value": "0"},
	])
	d := pdp.decision with input as i
	d.allow
	d.namespace == "quarantine"
}

# --- Repo gate: package entries --------------------------------------------

base_repo_package := patch(base_repo, [
	{"op": "add", "path": "/versions/bases/ubi9-minimal", "value": {}},
	{"op": "add", "path": "/versions/packageRepos", "value": {"pgdg17-el9": {
		"amd64": {"baseurl": PG_URL, "key": ".github/pdp/keyring/pgdg-rpm-gpg-key-rhel.asc", "signerFingerprint": PG_KEY_FPR, "signerFileSha256": PG_KEY_SHA},
		"arm64": {"baseurl": "https://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-aarch64", "key": ".github/pdp/keyring/pgdg-rpm-gpg-key-aarch64-rhel.asc", "signerFingerprint": "B031F89FC983E98262906B6E177B343BB9738825", "signerFileSha256": "cc506fa92aa97e8e58f88551a2ec99a61d9d603f7f2c1ae0c06191f58c29979f"},
	}}},
	{"op": "add", "path": "/versions/images/postgresql17", "value": {
		"kind": "package", "upstreamTrust": "internal", "base": "ubi9-minimal",
		"containerfile": "Containerfiles/postgresql17.Containerfile", "arches": ["amd64", "arm64"],
		"packages": {
			"repo": "pgdg17-el9", "version": "17.12",
			"track": "^17\\.[0-9]+-[0-9]+PGDG\\.rhel9(\\.[0-9]+)?$",
			"amd64": [PG_N1, PG_N2, PG_N3],
			"arm64": ["postgresql17-17.12-1PGDG.rhel9.8.aarch64", "postgresql17-libs-17.12-1PGDG.rhel9.8.aarch64", "postgresql17-server-17.12-1PGDG.rhel9.8.aarch64"],
		},
	}},
])

repo_package_denies(ops, code) if {
	d := pdp.repo_decision with input as patch(base_repo_package, ops) with data.exceptions as []
	not d.allow
	code in repo_codes(d)
}

test_base_repo_package_allows if {
	d := pdp.repo_decision with input as base_repo_package with data.exceptions as []
	d.allow
}

test_repo_package_field_missing_denies if {
	repo_package_denies([{"op": "remove", "path": "/versions/images/postgresql17/packages/version"}], "VERSIONS_PACKAGE_FIELD_MISSING")
}

test_repo_package_trust_class_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/upstreamTrust", "value": "none"}], "VERSIONS_PACKAGE_TRUST_CLASS_INVALID")
}

test_repo_package_with_crosscheck_denies if {
	repo_package_denies([{"op": "add", "path": "/versions/images/postgresql17/crosscheck", "value": {"amd64": {"digest": D}}}], "VERSIONS_PACKAGE_KIND_CONFLICT")
}

test_repo_package_base_dangling_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/base", "value": "ubi9-standard"}], "VERSIONS_PACKAGE_BASE_DANGLING")
}

test_repo_package_repo_dangling_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/packages/repo", "value": "pgdg18-el9"}], "VERSIONS_PACKAGE_REPO_DANGLING")
}

test_repo_package_repo_basearch_url_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/packageRepos/pgdg17-el9/amd64/baseurl", "value": "https://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-$basearch"}], "VERSIONS_PACKAGE_REPO_INVALID")
}

test_repo_package_repo_http_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/packageRepos/pgdg17-el9/arm64/baseurl", "value": "http://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-aarch64"}], "VERSIONS_PACKAGE_REPO_INVALID")
}

test_repo_package_key_outside_keyring_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/packageRepos/pgdg17-el9/amd64/key", "value": "/tmp/key.asc"}], "VERSIONS_PACKAGE_REPO_INVALID")
}

test_repo_package_short_key_id_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/packageRepos/pgdg17-el9/amd64/signerFingerprint", "value": "40BCA2B408B40D20"}], "VERSIONS_PACKAGE_REPO_INVALID")
}

test_repo_package_key_sha_missing_denies if {
	repo_package_denies([{"op": "remove", "path": "/versions/packageRepos/pgdg17-el9/arm64/signerFileSha256"}], "VERSIONS_PACKAGE_REPO_INVALID")
}

test_repo_package_repo_arch_missing_denies if {
	repo_package_denies([{"op": "remove", "path": "/versions/packageRepos/pgdg17-el9/arm64"}], "VERSIONS_PACKAGE_REPO_INVALID")
}

test_repo_package_track_unanchored_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/packages/track", "value": "17\\.[0-9]+-"}], "VERSIONS_TRACK_UNANCHORED")
}

test_repo_package_nevras_missing_denies if {
	repo_package_denies([{"op": "remove", "path": "/versions/images/postgresql17/packages/arm64"}], "VERSIONS_PACKAGE_NEVRAS_MISSING")
}

test_repo_package_bare_name_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/packages/amd64/2", "value": "postgresql17-server"}], "VERSIONS_PACKAGE_NEVRA_INVALID")
}

test_repo_package_wrong_arch_suffix_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/packages/arm64/2", "value": "postgresql17-server-17.12-1PGDG.rhel9.8.x86_64"}], "VERSIONS_PACKAGE_NEVRA_INVALID")
}

test_repo_package_version_disagrees_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/packages/amd64/0", "value": "postgresql17-17.11-1PGDG.rhel9.8.x86_64"}], "VERSIONS_PACKAGE_VERSION_DISAGREES")
}

# 18 is a new major: a dump and restore, never a drift bump.
test_repo_package_off_track_denies if {
	repo_package_denies(
		[
			{"op": "replace", "path": "/versions/images/postgresql17/packages/version", "value": "18.1"},
			{"op": "replace", "path": "/versions/images/postgresql17/packages/amd64", "value": ["postgresql17-18.1-1PGDG.rhel9.8.x86_64", "postgresql17-libs-18.1-1PGDG.rhel9.8.x86_64", "postgresql17-server-18.1-1PGDG.rhel9.8.x86_64"]},
			{"op": "replace", "path": "/versions/images/postgresql17/packages/arm64", "value": ["postgresql17-18.1-1PGDG.rhel9.8.aarch64", "postgresql17-libs-18.1-1PGDG.rhel9.8.aarch64", "postgresql17-server-18.1-1PGDG.rhel9.8.aarch64"]},
		],
		"VERSIONS_PACKAGE_TRACK_MISMATCH",
	)
}

test_repo_package_el8_build_off_track_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/packages/amd64/1", "value": "postgresql17-libs-17.12-1PGDG.rhel8.x86_64"}], "VERSIONS_PACKAGE_TRACK_MISMATCH")
}

test_repo_package_arch_skew_denies if {
	repo_package_denies([{"op": "remove", "path": "/versions/images/postgresql17/packages/arm64/0"}], "VERSIONS_PACKAGE_ARCH_SKEW")
}

test_repo_package_duplicate_name_denies if {
	repo_package_denies([{"op": "add", "path": "/versions/images/postgresql17/packages/amd64/-", "value": "postgresql17-17.12-2PGDG.rhel9.8.x86_64"}], "VERSIONS_PACKAGE_NAME_DUPLICATE")
}

test_repo_unknown_kind_still_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/kind", "value": "rpm"}], "VERSIONS_KIND_INVALID")
}

# Pin and observation agree, and the label agrees too, but the repository is
# plain http. Only the shape check of the pins sees it.
test_package_http_repository_denies if {
	u := "http://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-x86_64"
	package_denies(
		[
			{"op": "replace", "path": "/package/pinned_repo_url", "value": u},
			{"op": "replace", "path": "/package/repo_url", "value": u},
			{"op": "replace", "path": "/image/labels/org.opencontainers.image.source", "value": u},
		],
		"PACKAGE_PIN_MALFORMED",
	)
}

test_package_signatures_not_a_list_denies if {
	package_denies([{"op": "replace", "path": "/package/signatures", "value": {"nevra": PG_N1, "key_id": PG_KEY_ID}}], "PACKAGE_EVIDENCE_MALFORMED")
}

test_repo_package_nevra_trailing_text_denies if {
	repo_package_denies([{"op": "replace", "path": "/versions/images/postgresql17/packages/amd64/2", "value": "postgresql17-server-17.12-1PGDG.rhel9.8.x86_64.evil"}], "VERSIONS_PACKAGE_NEVRA_INVALID")
}

# 117.12 contains the 17 line as a substring. Only an anchored match refuses
# it, which is the whole reason anchors are mandatory.
test_repo_package_track_is_matched_anchored if {
	n := ["postgresql17-117.12-1PGDG.rhel9.8", "postgresql17-libs-117.12-1PGDG.rhel9.8", "postgresql17-server-117.12-1PGDG.rhel9.8"]
	repo_package_denies(
		[
			{"op": "replace", "path": "/versions/images/postgresql17/packages/version", "value": "117.12"},
			{"op": "replace", "path": "/versions/images/postgresql17/packages/amd64", "value": [concat("", [x, ".x86_64"]) | some x in n]},
			{"op": "replace", "path": "/versions/images/postgresql17/packages/arm64", "value": [concat("", [x, ".aarch64"]) | some x in n]},
		],
		"VERSIONS_PACKAGE_TRACK_MISMATCH",
	)
}

# ===========================================================================
# Native track (ADR-010)
#
# Each test below breaks ONE fact of a known-good native leg and expects the
# specific code AND the catch-all NATIVE_PROVENANCE_NOT_RECORDED where the
# fact is part of the provenance. A deleted specific rule fails the first
# assertion; a predicate that loses a condition fails the second.
# ===========================================================================

VK_COMMIT := "29173b67508b2de4c0f0ed551f3b47cf19fc3ca8"

VK_URL := "https://github.com/valkey-io/valkey"

VK_ARCHIVE := "https://github.com/valkey-io/valkey/archive/refs/tags/9.1.3.tar.gz"

VK_ARCHIVE_SHA := "184e34ed2d9b51879b682b5b15205e2b9d677c60280e3cb453be8f520d04e293"

UBI_MINIMAL := "ghcr.io/infrashift/trusted-base-images/trusted/ubi9-minimal"

D3 := "sha256:419f18caf8425f5c95c8f5aadd7b05dc947a85e4ae9c41ac9299dcd80036fc24"

base_native := {
	"track": "native",
	"evaluated_at": NOW,
	"image": {
		"key": "valkey", "variant": "runtime", "enforcement": "enforce",
		"destination_repo": "ghcr.io/infrashift/trusted-service-containers/development/valkey",
		"destination_digest": D, "config_user": "1001",
		"labels": {
			"org.opencontainers.image.source": VK_URL,
			"org.opencontainers.image.revision": VK_COMMIT,
			"org.opencontainers.image.version": "9.1.3",
			"io.infrashift.image.upstream.digest": D2,
			"io.infrashift.image.upstream.source": UBI_MINIMAL,
		},
	},
	"upstream": {
		"trust_class": "internal", "signature": "verified",
		"verified_with": ".github/pdp/public-keys/upstream/trusted-base-images-release.pub",
		"attestations": {"sbom": "present", "provenance": "present", "vex": "absent"},
	},
	"native": {
		"pinned_base_repo": UBI_MINIMAL, "base_image_repo": UBI_MINIMAL,
		"pinned_base_digest": D2, "base_image_digest": D2,
		"pinned_builder_repo": UBI_MINIMAL, "builder_image_repo": UBI_MINIMAL,
		"pinned_builder_digest": D3, "builder_image_digest": D3,
		"language": "c",
		"pinned_source_ref": VK_COMMIT, "source_revision": VK_COMMIT,
		"pinned_source_url": VK_URL, "source_url": VK_URL,
		"pinned_version": "9.1.3",
		"pinned_archive_url": VK_ARCHIVE, "archive_url": VK_ARCHIVE,
		"pinned_archive_sha256": VK_ARCHIVE_SHA, "archive_sha256": VK_ARCHIVE_SHA,
		"archive_tree_match": true,
		"from_source_sha256": "cccc000000000000000000000000000000000000000000000000000000000000",
		"verification": {"performed": true},
	},
	"scan_results": {
		"critical_count": 0, "high_count": 0, "medium_count": 0, "low_count": 0,
		"fixable_critical_count": 0, "fixable_high_count": 0, "findings": [],
	},
	"published_attestation_keys": {},
}

native_denies(ops, code) if {
	d := pdp.decision with input as patch(base_native, ops)
	not d.allow
	d.namespace == "quarantine"
	code in codes(d)
}

native_provenance_denies(ops, code) if {
	native_denies(ops, code)
	d := pdp.decision with input as patch(base_native, ops)
	"NATIVE_PROVENANCE_NOT_RECORDED" in codes(d)
}

test_base_native_allows if {
	d := pdp.decision with input as base_native
	d.allow
	d.namespace == "trusted"
	d.track == "native"
	some o in d.observations
	o.code == "NATIVE_BUILD"
	o.gating == false
	o.from_source_sha256 == base_native.native.from_source_sha256
}

# A native leg is not a build leg: it needs no crosscheck and no first-party
# declaration, and the build-track dual-provenance rules do not apply.
test_native_needs_no_crosscheck if {
	d := pdp.decision with input as base_native
	not "DUAL_PROVENANCE_NOT_RECORDED" in codes(d)
	not "PROVENANCE_MODE_MISMATCH" in codes(d)
}

# ...and a build leg that carries a native block is still a build leg.
test_build_leg_with_native_block_still_needs_crosscheck if {
	i := patch(base_build, [
		{"op": "add", "path": "/native", "value": base_native.native},
		{"op": "replace", "path": "/build/dual_provenance/performed", "value": false},
	])
	d := pdp.decision with input as i
	"DUAL_PROVENANCE_NOT_RECORDED" in codes(d)
}

test_native_absent_block_denies if {
	native_provenance_denies([{"op": "remove", "path": "/native"}], "NATIVE_PIN_MALFORMED")
}

test_native_verification_not_performed_denies if {
	d := pdp.decision with input as patch(base_native, [{"op": "replace", "path": "/native/verification/performed", "value": false}])
	not d.allow
	"NATIVE_PROVENANCE_NOT_RECORDED" in codes(d)
}

test_native_language_unknown_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/language", "value": "rust"}], "NATIVE_LANGUAGE_INVALID")
}

test_native_language_absent_denies if {
	native_provenance_denies([{"op": "remove", "path": "/native/language"}], "NATIVE_LANGUAGE_INVALID")
}

test_native_label_missing_denies if {
	native_denies([{"op": "remove", "path": "/image/labels/io.infrashift.image.upstream.digest"}], "BUILD_LABEL_MISSING")
}

test_native_label_empty_denies if {
	native_denies([{"op": "replace", "path": "/image/labels/org.opencontainers.image.version", "value": " "}], "BUILD_LABEL_EMPTY")
}

test_native_base_digest_mismatch_denies if {
	native_denies([{"op": "replace", "path": "/native/base_image_digest", "value": D}], "BUILD_BASE_DIGEST_MISMATCH")
}

test_native_base_repo_mismatch_denies if {
	native_denies([{"op": "replace", "path": "/native/base_image_repo", "value": "ghcr.io/evil/ubi9-minimal"}], "BUILD_BASE_REPO_MISMATCH")
}

test_native_source_ref_mismatch_denies if {
	native_denies([{"op": "replace", "path": "/native/source_revision", "value": COMMIT}], "BUILD_SOURCE_REF_MISMATCH")
}

test_native_source_ref_tag_denies if {
	native_denies(
		[
			{"op": "replace", "path": "/native/source_revision", "value": "9.1.3"},
			{"op": "replace", "path": "/native/pinned_source_ref", "value": "9.1.3"},
			{"op": "replace", "path": "/image/labels/org.opencontainers.image.revision", "value": "9.1.3"},
		],
		"BUILD_SOURCE_REF_NOT_PINNED",
	)
}

test_native_revision_label_disagrees_denies if {
	native_denies([{"op": "replace", "path": "/image/labels/org.opencontainers.image.revision", "value": COMMIT}], "BUILD_REVISION_LABEL_DISAGREES")
}

test_native_pinned_ref_malformed_denies if {
	native_provenance_denies(
		[
			{"op": "replace", "path": "/native/pinned_source_ref", "value": "29173b67"},
			{"op": "replace", "path": "/native/source_revision", "value": "29173b67"},
			{"op": "replace", "path": "/image/labels/org.opencontainers.image.revision", "value": "29173b67"},
		],
		"NATIVE_PIN_MALFORMED",
	)
}

test_native_builder_digest_mismatch_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/builder_image_digest", "value": D}], "NATIVE_BUILDER_DIGEST_MISMATCH")
}

test_native_builder_digest_both_absent_denies if {
	native_provenance_denies(
		[
			{"op": "remove", "path": "/native/builder_image_digest"},
			{"op": "remove", "path": "/native/pinned_builder_digest"},
		],
		"NATIVE_BUILDER_DIGEST_MISMATCH",
	)
}

test_native_builder_digest_malformed_denies if {
	native_provenance_denies(
		[
			{"op": "replace", "path": "/native/builder_image_digest", "value": "latest"},
			{"op": "replace", "path": "/native/pinned_builder_digest", "value": "latest"},
		],
		"INPUT_DIGEST_MALFORMED",
	)
}

test_native_builder_repo_mismatch_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/builder_image_repo", "value": "registry.access.redhat.com/ubi9/ubi"}], "NATIVE_BUILDER_REPO_MISMATCH")
}

test_native_source_url_mismatch_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/source_url", "value": "https://github.com/evil/valkey"}], "NATIVE_SOURCE_URL_MISMATCH")
}

test_native_source_label_disagrees_denies if {
	native_denies([{"op": "replace", "path": "/image/labels/org.opencontainers.image.source", "value": "https://github.com/evil/valkey"}], "NATIVE_SOURCE_LABEL_DISAGREES")
}

test_native_version_label_disagrees_denies if {
	native_denies([{"op": "replace", "path": "/image/labels/org.opencontainers.image.version", "value": "9.1.2"}], "NATIVE_VERSION_LABEL_DISAGREES")
}

test_native_pinned_version_absent_denies if {
	native_provenance_denies([{"op": "remove", "path": "/native/pinned_version"}], "NATIVE_PIN_MALFORMED")
}

test_native_archive_sha_mismatch_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/archive_sha256", "value": "19c23908e7d57e8d91ef85b41f5646307582f10f4f0fb999bbf89ed24ec9c983"}], "NATIVE_ARCHIVE_SHA256_MISMATCH")
}

test_native_archive_sha_both_absent_denies if {
	native_provenance_denies(
		[
			{"op": "remove", "path": "/native/archive_sha256"},
			{"op": "remove", "path": "/native/pinned_archive_sha256"},
		],
		"NATIVE_ARCHIVE_SHA256_MISMATCH",
	)
}

test_native_archive_sha_malformed_pin_denies if {
	native_provenance_denies(
		[
			{"op": "replace", "path": "/native/archive_sha256", "value": "184e34ed"},
			{"op": "replace", "path": "/native/pinned_archive_sha256", "value": "184e34ed"},
		],
		"NATIVE_PIN_MALFORMED",
	)
}

test_native_archive_url_mismatch_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/archive_url", "value": "https://github.com/valkey-io/valkey/archive/refs/tags/9.1.2.tar.gz"}], "NATIVE_ARCHIVE_URL_MISMATCH")
}

test_native_archive_tree_mismatch_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/archive_tree_match", "value": false}], "NATIVE_ARCHIVE_TREE_MISMATCH")
}

test_native_archive_tree_absent_denies if {
	native_provenance_denies([{"op": "remove", "path": "/native/archive_tree_match"}], "NATIVE_ARCHIVE_TREE_MISMATCH")
}

# A string "true" is not a comparison that ran.
test_native_archive_tree_string_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/archive_tree_match", "value": "true"}], "NATIVE_ARCHIVE_TREE_MISMATCH")
}

test_native_binary_hash_missing_denies if {
	native_provenance_denies([{"op": "remove", "path": "/native/from_source_sha256"}], "NATIVE_BINARY_HASH_MALFORMED")
}

test_native_binary_hash_empty_denies if {
	native_provenance_denies([{"op": "replace", "path": "/native/from_source_sha256", "value": ""}], "NATIVE_BINARY_HASH_MALFORMED")
}

test_native_observe_still_quarantines if {
	i := patch(base_native, [
		{"op": "replace", "path": "/image/enforcement", "value": "observe"},
		{"op": "replace", "path": "/native/archive_tree_match", "value": false},
	])
	d := pdp.decision with input as i
	d.allow
	d.namespace == "quarantine"
}

test_native_remediation_hint if {
	i := patch(base_native, [
		{"op": "replace", "path": "/scan_results/high_count", "value": 1},
		{"op": "replace", "path": "/scan_results/fixable_high_count", "value": 1},
		{"op": "replace", "path": "/scan_results/findings", "value": [{"id": "CVE-2026-71199", "severity": "High", "fix_state": "fixed", "package": "krb5-libs"}]},
	])
	d := pdp.decision with input as i
	some v in d.violations
	v.code == "CVE_HIGH_FIXABLE"
	contains(v.remediation_hint, "native image")
}

# --- Repo gate: native entries ---------------------------------------------

base_repo_native := patch(base_repo, [
	{"op": "add", "path": "/versions/bases/ubi9-minimal", "value": {}},
	{"op": "add", "path": "/versions/sources/valkey", "value": {
		"track": "^9\\.1\\.[0-9]+$", "ref": "9.1.3", "url": VK_URL, "commit": VK_COMMIT,
		"archive": {"url": VK_ARCHIVE, "sha256": VK_ARCHIVE_SHA},
	}},
	{"op": "add", "path": "/versions/images/valkey", "value": {
		"kind": "native", "upstreamTrust": "internal", "source": "valkey",
		"builder": "ubi9-minimal", "base": "ubi9-minimal",
		"containerfile": "Containerfiles/valkey.Containerfile", "arches": ["amd64", "arm64"],
		"native": {"language": "c", "buildPackages": ["gcc", "make"], "binary": "valkey-server", "installPath": "/usr/bin/valkey-server"},
	}},
])

repo_native_denies(ops, code) if {
	d := pdp.repo_decision with input as patch(base_repo_native, ops) with data.exceptions as []
	not d.allow
	code in repo_codes(d)
}

test_base_repo_native_allows if {
	d := pdp.repo_decision with input as base_repo_native with data.exceptions as []
	d.allow
}

test_repo_native_kind_is_known if {
	d := pdp.repo_decision with input as base_repo_native with data.exceptions as []
	not "VERSIONS_KIND_INVALID" in repo_codes(d)
}

test_repo_native_field_missing_denies if {
	repo_native_denies([{"op": "remove", "path": "/versions/images/valkey/builder"}], "VERSIONS_NATIVE_FIELD_MISSING")
}

test_repo_native_install_path_missing_denies if {
	repo_native_denies([{"op": "remove", "path": "/versions/images/valkey/native/installPath"}], "VERSIONS_NATIVE_FIELD_MISSING")
}

test_repo_native_language_invalid_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/images/valkey/native/language", "value": "cgo"}], "VERSIONS_NATIVE_LANGUAGE_INVALID")
}

test_repo_native_language_absent_denies if {
	repo_native_denies([{"op": "remove", "path": "/versions/images/valkey/native"}], "VERSIONS_NATIVE_LANGUAGE_INVALID")
}

test_repo_native_trust_class_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/images/valkey/upstreamTrust", "value": "none"}], "VERSIONS_NATIVE_TRUST_CLASS_INVALID")
}

test_repo_native_with_crosscheck_denies if {
	repo_native_denies([{"op": "add", "path": "/versions/images/valkey/crosscheck", "value": {"amd64": {"digest": D}}}], "VERSIONS_NATIVE_KIND_CONFLICT")
}

test_repo_native_with_first_party_denies if {
	repo_native_denies([{"op": "add", "path": "/versions/images/valkey/firstParty", "value": {"noVendorBinary": true, "reason": FP_REASON}}], "VERSIONS_NATIVE_KIND_CONFLICT")
}

test_repo_native_with_toolchain_denies if {
	repo_native_denies([{"op": "add", "path": "/versions/images/valkey/toolchain", "value": "go1.26"}], "VERSIONS_NATIVE_KIND_CONFLICT")
}

test_repo_native_source_dangling_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/images/valkey/source", "value": "redis"}], "VERSIONS_NATIVE_SOURCE_DANGLING")
}

test_repo_native_builder_dangling_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/images/valkey/builder", "value": "ubi9"}], "VERSIONS_NATIVE_BASE_DANGLING")
}

test_repo_native_base_dangling_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/images/valkey/base", "value": "ubi9-standard"}], "VERSIONS_NATIVE_BASE_DANGLING")
}

test_repo_native_archive_missing_denies if {
	repo_native_denies([{"op": "remove", "path": "/versions/sources/valkey/archive"}], "VERSIONS_NATIVE_ARCHIVE_MISSING")
}

test_repo_native_archive_http_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/sources/valkey/archive/url", "value": "http://github.com/valkey-io/valkey/archive/refs/tags/9.1.3.tar.gz"}], "VERSIONS_NATIVE_ARCHIVE_MISSING")
}

test_repo_native_archive_short_sha_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/sources/valkey/archive/sha256", "value": "184e34ed"}], "VERSIONS_NATIVE_ARCHIVE_MISSING")
}

# A bump that moved ref and commit but left the archive on the old release.
test_repo_native_archive_names_other_release_denies if {
	repo_native_denies(
		[
			{"op": "replace", "path": "/versions/sources/valkey/ref", "value": "9.1.4"},
			{"op": "replace", "path": "/versions/sources/valkey/archive/url", "value": VK_ARCHIVE},
		],
		"VERSIONS_NATIVE_ARCHIVE_REF_MISMATCH",
	)
}

# `9.1.3` must not match inside `19.1.3`.
test_repo_native_archive_ref_is_a_path_segment if {
	repo_native_denies(
		[{"op": "replace", "path": "/versions/sources/valkey/archive/url", "value": "https://github.com/valkey-io/valkey/archive/refs/tags/19.1.3.tar.gz"}],
		"VERSIONS_NATIVE_ARCHIVE_REF_MISMATCH",
	)
}

test_repo_native_archive_dir_form_allows if {
	i := patch(base_repo_native, [{"op": "replace", "path": "/versions/sources/valkey/archive/url", "value": "https://download.valkey.io/releases/9.1.3/valkey-9.1.3.tar.gz"}])
	d := pdp.repo_decision with input as i with data.exceptions as []
	d.allow
}

test_repo_native_source_commit_tag_denies if {
	repo_native_denies([{"op": "replace", "path": "/versions/sources/valkey/commit", "value": "9.1.3"}], "VERSIONS_SOURCE_REF_NOT_PINNED")
}

test_native_pinned_source_url_http_denies if {
	native_provenance_denies(
		[
			{"op": "replace", "path": "/native/pinned_source_url", "value": "http://github.com/valkey-io/valkey"},
			{"op": "replace", "path": "/native/source_url", "value": "http://github.com/valkey-io/valkey"},
			{"op": "replace", "path": "/image/labels/org.opencontainers.image.source", "value": "http://github.com/valkey-io/valkey"},
		],
		"NATIVE_PIN_MALFORMED",
	)
}

test_native_pinned_archive_url_http_denies if {
	native_provenance_denies(
		[
			{"op": "replace", "path": "/native/pinned_archive_url", "value": "http://github.com/valkey-io/valkey/archive/refs/tags/9.1.3.tar.gz"},
			{"op": "replace", "path": "/native/archive_url", "value": "http://github.com/valkey-io/valkey/archive/refs/tags/9.1.3.tar.gz"},
		],
		"NATIVE_PIN_MALFORMED",
	)
}

test_native_builder_repo_both_absent_denies if {
	native_provenance_denies(
		[
			{"op": "remove", "path": "/native/pinned_builder_repo"},
			{"op": "remove", "path": "/native/builder_image_repo"},
		],
		"NATIVE_PIN_MALFORMED",
	)
}

# ===========================================================================
# Native track, language python (ADR-010, LiteLLM)
# ===========================================================================

LL_LOCK_SHA := "2972e946f5bc76c72ea639f430b2882e9ee36f28257b8ec427dc1291a367ab50"

LL_URL := "https://pypi.org/project/litellm/"

LL_DISTS := ["litellm==1.109.1", "redis==8.1.0", "pyyaml==6.0.3"]

base_native_python := {
	"track": "native",
	"evaluated_at": NOW,
	"image": {
		"key": "litellm", "variant": "runtime", "enforcement": "enforce",
		"destination_repo": "ghcr.io/infrashift/trusted-service-containers/development/litellm",
		"destination_digest": D, "config_user": "1001",
		"labels": {
			"org.opencontainers.image.source": LL_URL,
			"org.opencontainers.image.revision": LL_LOCK_SHA,
			"org.opencontainers.image.version": "1.109.1",
			"io.infrashift.image.upstream.digest": D2,
			"io.infrashift.image.upstream.source": UBI_MINIMAL,
		},
	},
	"upstream": {
		"trust_class": "internal", "signature": "verified",
		"verified_with": ".github/pdp/public-keys/upstream/trusted-base-images-release.pub",
		"attestations": {"sbom": "present", "provenance": "present", "vex": "absent"},
	},
	"native": {
		"pinned_base_repo": UBI_MINIMAL, "base_image_repo": UBI_MINIMAL,
		"pinned_base_digest": D2, "base_image_digest": D2,
		"pinned_builder_repo": UBI_MINIMAL, "builder_image_repo": UBI_MINIMAL,
		"pinned_builder_digest": D3, "builder_image_digest": D3,
		"language": "python",
		"pinned_source_url": LL_URL,
		"pinned_version": "1.109.1",
		"pinned_distribution": "litellm",
		"pinned_lock_sha256": LL_LOCK_SHA, "checkout_lock_sha256": LL_LOCK_SHA, "lock_sha256": LL_LOCK_SHA,
		"locked_distributions": LL_DISTS,
		"installed_distributions": LL_DISTS,
		"verified_distributions": LL_DISTS,
		"verification": {"performed": true},
	},
	"scan_results": {
		"critical_count": 0, "high_count": 0, "medium_count": 0, "low_count": 0,
		"fixable_critical_count": 0, "fixable_high_count": 0, "findings": [],
	},
	"published_attestation_keys": {},
}

python_denies(ops, code) if {
	d := pdp.decision with input as patch(base_native_python, ops)
	not d.allow
	d.namespace == "quarantine"
	code in codes(d)
	"NATIVE_PROVENANCE_NOT_RECORDED" in codes(d)
}

test_base_native_python_allows if {
	d := pdp.decision with input as base_native_python
	d.allow
	d.namespace == "trusted"
	some o in d.observations
	o.code == "NATIVE_BUILD"
	o.language == "python"
	o.requirement == "litellm==1.109.1"
	o.distributions == 3
	o.gating == false
}

# A python leg has no commit: the source and archive rules of language c do
# not apply, and must not deny it.
test_native_python_needs_no_commit_or_archive if {
	d := pdp.decision with input as base_native_python
	every c in ["BUILD_SOURCE_REF_NOT_PINNED", "BUILD_SOURCE_REF_MISMATCH", "BUILD_REVISION_LABEL_DISAGREES", "NATIVE_ARCHIVE_TREE_MISMATCH", "NATIVE_BINARY_HASH_MALFORMED", "NATIVE_SOURCE_URL_MISMATCH"] {
		not c in codes(d)
	}
}

# ...and a c leg cannot pass on the python facts alone.
test_native_c_leg_with_python_facts_denies if {
	i := patch(base_native_python, [{"op": "replace", "path": "/native/language", "value": "c"}])
	d := pdp.decision with input as i
	not d.allow
	"NATIVE_PROVENANCE_NOT_RECORDED" in codes(d)
	"BUILD_SOURCE_REF_NOT_PINNED" in codes(d)
	"NATIVE_ARCHIVE_TREE_MISMATCH" in codes(d)
}

# ...and a python leg cannot pass on the c facts alone.
test_native_python_leg_with_c_facts_denies if {
	i := patch(base_native, [
		{"op": "replace", "path": "/native/language", "value": "python"},
		{"op": "add", "path": "/native/pinned_distribution", "value": "valkey"},
	])
	d := pdp.decision with input as i
	not d.allow
	"NATIVE_PROVENANCE_NOT_RECORDED" in codes(d)
	"NATIVE_LOCK_SHA256_MISMATCH" in codes(d)
}

test_native_python_lock_sha_mismatch_denies if {
	python_denies([{"op": "replace", "path": "/native/lock_sha256", "value": VK_ARCHIVE_SHA}], "NATIVE_LOCK_SHA256_MISMATCH")
}

test_native_python_lock_sha_both_absent_denies if {
	python_denies(
		[
			{"op": "remove", "path": "/native/lock_sha256"},
			{"op": "remove", "path": "/native/pinned_lock_sha256"},
		],
		"NATIVE_LOCK_SHA256_MISMATCH",
	)
}

test_native_python_checkout_lock_mismatch_denies if {
	python_denies([{"op": "replace", "path": "/native/checkout_lock_sha256", "value": VK_ARCHIVE_SHA}], "NATIVE_LOCK_CHECKOUT_MISMATCH")
}

test_native_python_checkout_lock_absent_denies if {
	python_denies([{"op": "remove", "path": "/native/checkout_lock_sha256"}], "NATIVE_LOCK_CHECKOUT_MISMATCH")
}

test_native_python_revision_label_denies if {
	python_denies([{"op": "replace", "path": "/image/labels/org.opencontainers.image.revision", "value": VK_ARCHIVE_SHA}], "NATIVE_REVISION_LABEL_DISAGREES")
}

test_native_python_source_label_denies if {
	native_python_label_denies("org.opencontainers.image.source", "https://pypi.org/project/evil/", "NATIVE_SOURCE_LABEL_DISAGREES")
}

test_native_python_version_label_denies if {
	native_python_label_denies("org.opencontainers.image.version", "1.108.9", "NATIVE_VERSION_LABEL_DISAGREES")
}

native_python_label_denies(label, value, code) if {
	d := pdp.decision with input as patch(base_native_python, [{"op": "replace", "path": concat("", ["/image/labels/", label]), "value": value}])
	not d.allow
	code in codes(d)
}

test_native_python_dist_not_installed_denies if {
	python_denies([{"op": "replace", "path": "/native/installed_distributions", "value": ["litellm==1.109.1", "pyyaml==6.0.3"]}], "NATIVE_DISTRIBUTION_NOT_INSTALLED")
}

test_native_python_other_version_installed_denies if {
	python_denies([{"op": "replace", "path": "/native/installed_distributions/1", "value": "redis==7.0.0"}], "NATIVE_DISTRIBUTION_NOT_INSTALLED")
}

test_native_python_unlocked_dist_denies if {
	python_denies([{"op": "add", "path": "/native/installed_distributions/-", "value": "pip==23.2.1"}], "NATIVE_DISTRIBUTION_UNLOCKED")
}

test_native_python_dist_not_verified_denies if {
	python_denies([{"op": "replace", "path": "/native/verified_distributions", "value": ["litellm==1.109.1", "redis==8.1.0"]}], "NATIVE_DISTRIBUTION_NOT_VERIFIED")
}

test_native_python_version_not_locked_denies if {
	python_denies(
		[
			{"op": "replace", "path": "/native/pinned_version", "value": "1.110.0"},
			{"op": "replace", "path": "/image/labels/org.opencontainers.image.version", "value": "1.110.0"},
		],
		"NATIVE_VERSION_NOT_LOCKED",
	)
}

test_native_python_distribution_not_locked_denies if {
	python_denies([{"op": "replace", "path": "/native/pinned_distribution", "value": "openai"}], "NATIVE_VERSION_NOT_LOCKED")
}

test_native_python_locked_malformed_denies if {
	python_denies([{"op": "replace", "path": "/native/locked_distributions/0", "value": "LiteLLM==1.109.1"}], "NATIVE_DISTRIBUTIONS_MALFORMED")
}

test_native_python_locked_empty_denies if {
	python_denies(
		[
			{"op": "replace", "path": "/native/locked_distributions", "value": []},
			{"op": "replace", "path": "/native/installed_distributions", "value": []},
			{"op": "replace", "path": "/native/verified_distributions", "value": []},
		],
		"NATIVE_DISTRIBUTIONS_MALFORMED",
	)
}

test_native_python_installed_not_a_list_denies if {
	python_denies([{"op": "replace", "path": "/native/installed_distributions", "value": "litellm==1.109.1"}], "NATIVE_DISTRIBUTIONS_MALFORMED")
}

test_native_python_verified_absent_denies if {
	python_denies([{"op": "remove", "path": "/native/verified_distributions"}], "NATIVE_DISTRIBUTIONS_MALFORMED")
}

test_native_python_pinned_distribution_absent_denies if {
	python_denies([{"op": "remove", "path": "/native/pinned_distribution"}], "NATIVE_PIN_MALFORMED")
}

test_native_python_builder_mismatch_denies if {
	python_denies([{"op": "replace", "path": "/native/builder_image_digest", "value": D}], "NATIVE_BUILDER_DIGEST_MISMATCH")
}

test_native_python_not_performed_denies if {
	d := pdp.decision with input as patch(base_native_python, [{"op": "replace", "path": "/native/verification/performed", "value": false}])
	not d.allow
	"NATIVE_PROVENANCE_NOT_RECORDED" in codes(d)
}

test_native_python_remediation_hint if {
	i := patch(base_native_python, [
		{"op": "replace", "path": "/scan_results/high_count", "value": 1},
		{"op": "replace", "path": "/scan_results/fixable_high_count", "value": 1},
		{"op": "replace", "path": "/scan_results/findings", "value": [{"id": "GHSA-xxxx", "severity": "High", "fix_state": "fixed", "package": "aiohttp"}]},
	])
	d := pdp.decision with input as i
	some v in d.violations
	v.code == "CVE_HIGH_FIXABLE"
	contains(v.remediation_hint, "new lock")
}

# --- Repo gate: native python entries --------------------------------------

base_repo_native_python := patch(base_repo_native, [{"op": "add", "path": "/versions/images/litellm", "value": {
	"kind": "native", "upstreamTrust": "internal",
	"builder": "ubi9-minimal", "base": "ubi9-minimal",
	"containerfile": "Containerfiles/litellm.Containerfile", "arches": ["amd64", "arm64"],
	"native": {
		"language": "python", "buildPackages": ["python3.12", "python3.12-pip"], "runtimePackages": ["python3.12"],
		"distribution": "litellm", "version": "1.109.1", "projectUrl": LL_URL,
		"lock": {"path": "locks/litellm/requirements.txt", "sha256": LL_LOCK_SHA},
		"venv": "/opt/litellm", "binary": "litellm", "installPath": "/opt/litellm/bin/litellm",
	},
}}])

repo_python_denies(ops, code) if {
	d := pdp.repo_decision with input as patch(base_repo_native_python, ops) with data.exceptions as []
	not d.allow
	code in repo_codes(d)
}

test_base_repo_native_python_allows if {
	d := pdp.repo_decision with input as base_repo_native_python with data.exceptions as []
	d.allow
}

test_repo_python_lock_missing_denies if {
	repo_python_denies([{"op": "remove", "path": "/versions/images/litellm/native/lock"}], "VERSIONS_NATIVE_FIELD_MISSING")
}

test_repo_python_version_missing_denies if {
	repo_python_denies([{"op": "remove", "path": "/versions/images/litellm/native/version"}], "VERSIONS_NATIVE_FIELD_MISSING")
}

test_repo_python_with_source_denies if {
	repo_python_denies([{"op": "add", "path": "/versions/images/litellm/source", "value": "valkey"}], "VERSIONS_NATIVE_KIND_CONFLICT")
}

test_repo_python_lock_of_other_image_denies if {
	repo_python_denies([{"op": "replace", "path": "/versions/images/litellm/native/lock/path", "value": "locks/other/requirements.txt"}], "VERSIONS_NATIVE_LOCK_INVALID")
}

test_repo_python_lock_short_sha_denies if {
	repo_python_denies([{"op": "replace", "path": "/versions/images/litellm/native/lock/sha256", "value": "2972e946"}], "VERSIONS_NATIVE_LOCK_INVALID")
}

test_repo_python_install_path_outside_venv_denies if {
	repo_python_denies([{"op": "replace", "path": "/versions/images/litellm/native/installPath", "value": "/usr/bin/litellm"}], "VERSIONS_NATIVE_INSTALL_PATH_OUTSIDE_VENV")
}

# A python entry needs no source and no archive.
test_repo_python_needs_no_source if {
	d := pdp.repo_decision with input as base_repo_native_python with data.exceptions as []
	not "VERSIONS_NATIVE_SOURCE_DANGLING" in repo_codes(d)
	not "VERSIONS_NATIVE_ARCHIVE_MISSING" in repo_codes(d)
}

# ...but a c entry still does.
test_repo_c_still_needs_source if {
	repo_native_denies([{"op": "remove", "path": "/versions/images/valkey/source"}], "VERSIONS_NATIVE_FIELD_MISSING")
}

# A malformed pin that is the same everywhere still denies.
test_native_python_malformed_lock_pin_everywhere_denies if {
	python_denies(
		[
			{"op": "replace", "path": "/native/pinned_lock_sha256", "value": "abc"},
			{"op": "replace", "path": "/native/checkout_lock_sha256", "value": "abc"},
			{"op": "replace", "path": "/native/lock_sha256", "value": "abc"},
			{"op": "replace", "path": "/image/labels/org.opencontainers.image.revision", "value": "abc"},
		],
		"NATIVE_PIN_MALFORMED",
	)
}

# A malformed distribution that is the same in all three sets still denies.
test_native_python_malformed_dist_everywhere_denies if {
	python_denies(
		[
			{"op": "add", "path": "/native/locked_distributions/-", "value": "Bad Name==1"},
			{"op": "add", "path": "/native/installed_distributions/-", "value": "Bad Name==1"},
			{"op": "add", "path": "/native/verified_distributions/-", "value": "Bad Name==1"},
		],
		"NATIVE_DISTRIBUTIONS_MALFORMED",
	)
}
