package tsc.pdp

# ===========================================================================
# Trusted Service Containers -- Policy Decision Point
#
# ONE file. ONE package. There are no other .rego files in this repository and
# there must never be. The reference repo (trusted-base-oci-images) carried six
# orphaned policy files that contradicted the live one; two of them would have
# denied every image had anything ever evaluated them.
# scripts/check-no-orphan-rego.sh keeps this true.
#
# ---------------------------------------------------------------------------
# TWO ENTRYPOINTS
#
#   data.tsc.pdp.repo_decision   Scope: the repository. Secret scanning,
#                                versions.json schema, track anchoring,
#                                exception-register hygiene. Once per PR.
#
#   data.tsc.pdp.decision        Scope: one leg. Handles BOTH tracks.
#                                Mirror legs are one {service, variant} over a
#                                whole multi-arch index; build legs are one
#                                {service, arch}.
#
# ---------------------------------------------------------------------------
# ONE CVE GATE, FOR EVERY IMAGE, REGARDLESS OF TRUST CLASS OR TRACK
#
#   Critical                       -> blocking
#   High with fix_state "fixed"    -> blocking (actionable: a newer upstream
#                                     digest or base bump clears it)
#   High with no available fix     -> recorded (non-blocking; no action we
#                                     control clears it, and blocking would
#                                     gate every image on a vendor's backport
#                                     schedule rather than on anything we own)
#
# A blocking finding is waived ONLY by an entry in the committed exception
# register that names it, carries a justification, and has not expired as of
# input.evaluated_at. Waived findings surface in a distinct `waived` state.
# They are never silently dropped.
#
# ---------------------------------------------------------------------------
# TRUST CLASS DRIVES SIGNATURE VERIFICATION ONLY. NEVER CVE POLICY.
#
#   dhi       Docker Hardened Images. MUST verify against the pinned copy of
#             registry.scout.docker.com/keyring/dhi/latest.pub.
#   internal  Our own ubi9-micro / ubi9-minimal from the sibling repo. MUST
#             verify against that repo's committed release public key.
#   none      nexus3, and the official Ory/Dapr images we cross-check a binary
#             hash against. Confirmed unverifiable: `cosign download signature
#             oryd/kratos:v26.2.0` yields Cert:false, Chain:false -- a keyed
#             signature whose public key the vendor does not publish. Records
#             "not-applicable"; carries no CVE relief whatsoever.
#
# Grep for `trust_class` before merging any change to this file and confirm it
# appears in no CVE rule.
#
# ---------------------------------------------------------------------------
# DETERMINISM
#
# time.now_ns() is called NOWHERE in this file, including in the repo gate.
# Every temporal comparison uses input.evaluated_at, supplied by the caller.
# Re-running the gate on the same input a year later yields byte-identical
# output, which is what makes a signed verdict worth signing.
#
# ---------------------------------------------------------------------------
# FAIL-CLOSED CONTRACT. Read this before editing anything below.
#
#   1. NUMBERS. `> 0` against a missing or non-numeric value is *undefined* in
#      Rego, which is silently non-violating. Every numeric field has a
#      companion is_number() guard. Never rely on the comparison alone.
#
#   2. ENUMS. Every enum is read through object.get() with a "<missing>"
#      sentinel and tested against a closed set. Unknown or absent violates.
#
#   3. EQUALITY. When two fields must match, each side gets a *different*
#      sentinel default, so "both absent" compares unequal and denies rather
#      than trivially matching.
#
#   4. NEGATION. Never write `not <thing_is_bad>`. An undefined helper makes
#      `not` true, which fails open. Define the *positive* predicate and
#      negate that, so an undefined helper denies.
#
#   5. EXCEPTIONS. data.exceptions can only ever move a finding from
#      `blocking` to `waived`. No integrity, signature, attestation, track or
#      label rule consults it. This is structural: `waiver_for` is referenced
#      in exactly one place in this file.
# ===========================================================================

# ---------------------------------------------------------------------------
# Closed vocabularies
# ---------------------------------------------------------------------------

missing := "<missing>"

tracks := {"mirror", "build"}

trust_classes := {"dhi", "none", "internal"}

# Three distinct states. Never collapse to a boolean.
#   verified        verification ran and succeeded, against the correct key
#   failed          verification ran and did NOT succeed -- fatal for EVERY
#                   class including `none`. A class may decline to verify;
#                   it may not verify and lose.
#   not-applicable  verification was not attempted because the class does not
#                   support it. Honoured ONLY where required is false.
signature_states := {"verified", "failed", "not-applicable"}

attestation_states := {"present", "absent", "not-applicable"}

enforcement_modes := {"enforce", "observe"}

class_requires_signature := {"dhi": true, "internal": true, "none": false}

# The exact key material each class must have verified against. An image that
# verified against the wrong key is not verified. `none` has no entry, so
# claiming `verified` for it is a contradiction and denies below.
class_keyring := {
	"dhi": ".github/pdp/keyring/dhi-latest.pub",
	"internal": ".github/pdp/public-keys/upstream/trusted-base-images-release.pub",
}

class_requires_attestations := {"dhi": true, "internal": true, "none": false}

required_attestation_kinds := {"sbom", "provenance"}

# Labels required on BUILT images only. Five labels, every one of which our own
# build sets. Contrast the reference's labels.rego, which demanded nine
# including io.openshift.expose-services that no image set -- it would have
# denied every image, which is why nothing ever evaluated it.
#
# MIRRORED images have NO label requirement. We do not add labels to a mirrored
# image; that would change its digest. Vendor labels stay untouched and our
# provenance lives in an attestation instead.
required_build_labels := {
	"org.opencontainers.image.source",
	"org.opencontainers.image.revision",
	"org.opencontainers.image.version",
	"io.infrashift.image.upstream.digest",
	"io.infrashift.image.upstream.source",
}

allowed_destination_prefixes := {
	"ghcr.io/infrashift/trusted-service-containers/development/",
	"ghcr.io/infrashift/trusted-service-containers/trusted/",
	"ghcr.io/infrashift/trusted-service-containers/quarantine/",
}

# Uniform for every image. Trust class does not lengthen or shorten it.
max_exception_days := 90

min_justification_chars := 40

expiry_warning_days := 14

# Credential-shaped keys must never appear in an attestation we publish. The
# reference published a live sigstore-audience OIDC token at
# provenance.internalParameters.oidcToken as a public referrer on every image.
secret_key_pattern := `(?i)(token|secret|password|passwd|credential|authorization|bearer|private[-_]?key)`

ns_per_day := 86400000000000

# ---------------------------------------------------------------------------
# Safe accessors
# ---------------------------------------------------------------------------

track := object.get(input, ["track"], missing)

trust_class := object.get(input, ["upstream", "trust_class"], missing)

signature_state := object.get(input, ["upstream", "signature"], missing)

verified_with := object.get(input, ["upstream", "verified_with"], missing)

image_key := object.get(input, ["image", "key"], missing)

variant := object.get(input, ["image", "variant"], missing)

enforcement := object.get(input, ["image", "enforcement"], "enforce")

image_id := sprintf("%s/%s", [image_key, variant])

attestation_state(kind) := object.get(input, ["upstream", "attestations", kind], missing)

label(name) := object.get(input, ["image", "labels", name], missing)

is_digest(s) if {
	is_string(s)
	startswith(s, "sha256:")
	count(s) == 71
}

# Deliberately NOT defaulted. A default would make every `expiry > default`
# comparison succeed, which fails open. Undefined here means no exception can
# apply to anything, and INPUT_TIMESTAMP_INVALID fires.
evaluated_at_ns := ns if {
	ns := time.parse_rfc3339_ns(object.get(input, ["evaluated_at"], ""))
	ns > 0
}

evaluated_at_str := object.get(input, ["evaluated_at"], missing)

numeric_scan_fields := [
	"critical_count",
	"high_count",
	"medium_count",
	"low_count",
	"fixable_critical_count",
	"fixable_high_count",
]

# Undefined -- not zero -- when absent or non-numeric. Every use is paired with
# the INPUT_SCAN_FIELD_MALFORMED rule.
scan_count(field) := n if {
	n := object.get(input, ["scan_results", field], null)
	is_number(n)
}

# ===========================================================================
# EXCEPTIONS
# ===========================================================================
# Loaded via `opa eval --data .github/pdp/exceptions.yaml`, whose top-level
# `exceptions:` key lands at data.exceptions. If the file fails to load,
# data.exceptions is undefined, the default [] applies, and nothing is waived.

default exception_list := []

exception_list := data.exceptions if is_array(data.exceptions)

# --- Validity: all positive predicates, so undefined => does not waive ------

exception_has_required_fields(exc) if {
	is_string(exc.id)
	is_string(exc.image)
	is_string(exc.variant)
	is_string(exc.package)
	is_string(exc.owner)
	is_string(exc.ticket)
	is_string(exc.issued)
	is_string(exc.expires)
	is_array(exc.cves)
	count(exc.cves) > 0
	every c in exc.cves { is_string(c) }
}

# MANDATORY and substantive. "n/a", "", or a bare "false positive" fails here.
exception_has_justification(exc) if {
	is_string(exc.justification)
	count(trim_space(exc.justification)) >= min_justification_chars
}

exception_dates_parse(exc) if {
	time.parse_rfc3339_ns(exc.issued)
	time.parse_rfc3339_ns(exc.expires)
}

# The maximum lifetime is enforced in policy, not left to reviewer discipline.
exception_window_valid(exc) if {
	issued := time.parse_rfc3339_ns(exc.issued)
	expiry := time.parse_rfc3339_ns(exc.expires)
	expiry > issued
	expiry - issued <= max_exception_days * ns_per_day
}

# Deterministic: compares against the caller-supplied evaluated_at, never a
# wall clock. If evaluated_at_ns is undefined this is undefined, so nothing is
# waived.
exception_unexpired(exc) if {
	expiry := time.parse_rfc3339_ns(exc.expires)
	expiry > evaluated_at_ns
}

# A structurally valid exception. MISSING `expires` or MISSING/short
# `justification` fails here, so such an entry waives NOTHING -- and it also
# raises EXCEPTION_INVALID below so the author finds out why.
exception_valid(exc) if {
	exception_has_required_fields(exc)
	exception_has_justification(exc)
	exception_dates_parse(exc)
	exception_window_valid(exc)
}

# --- Scope matching --------------------------------------------------------

exception_variant_matches(exc) if exc.variant == variant

exception_variant_matches(exc) if exc.variant == "*"

exception_covers(exc, f) if {
	some c in exc.cves
	c == f.id
}

exception_package_matches(exc, _) if exc.package == "*"

exception_package_matches(exc, f) if exc.package == f.package

# The ONLY bridge between the exception register and the gate. If you find
# yourself calling this from a rule that is not about a CVE finding, stop.
waiver_for(f) := exc if {
	some exc in exception_list
	exc.image == image_key
	exception_variant_matches(exc)
	exception_covers(exc, f)
	exception_package_matches(exc, f)
	exception_valid(exc)
	exception_unexpired(exc)
}

# ===========================================================================
# FINDINGS -- the three-state machine
# ===========================================================================
# input.scan_results.findings carries EVERY Critical and High grype match,
# unfiltered. Classification happens here, not in the jq that built the input,
# so the gate logic lives in one reviewable place.

raw_findings := object.get(input, ["scan_results", "findings"], null)

findings := [f |
	some f in raw_findings
	is_string(f.id)
	is_string(f.severity)
	is_string(f.fix_state)
	is_string(f.package)
]

# ONE gate for every image. No trust class appears in these two rules, and none
# ever should.
gate_relevant(f) if f.severity == "Critical"

gate_relevant(f) if {
	f.severity == "High"
	f.fix_state == "fixed"
}

classify(f) := c if {
	gate_relevant(f)
	exc := waiver_for(f)
	c := {
		"id": f.id, "severity": f.severity, "fix_state": f.fix_state,
		"package": f.package, "state": "waived",
		"waiver_id": exc.id, "waiver_expires": exc.expires,
		"waiver_owner": exc.owner, "waiver_ticket": exc.ticket,
	}
}

# Positive predicate, then negated: an undefined waiver_for leaves the finding
# blocking, which is the safe direction.
classify(f) := c if {
	gate_relevant(f)
	not waiver_for(f)
	c := {
		"id": f.id, "severity": f.severity, "fix_state": f.fix_state,
		"package": f.package, "state": "blocking",
	}
}

classify(f) := c if {
	not gate_relevant(f)
	c := {
		"id": f.id, "severity": f.severity, "fix_state": f.fix_state,
		"package": f.package, "state": "recorded",
	}
}

classified_findings := [classify(f) | some f in findings]

findings_in(state) := [c | some c in classified_findings; c.state == state]

blocking_findings := findings_in("blocking")

waived_findings := findings_in("waived")

recorded_findings := findings_in("recorded")

# ===========================================================================
# LEG GATE -- fail-closed input validation
# ===========================================================================

violations contains v if {
	not track in tracks
	v := {"code": "INPUT_TRACK_UNKNOWN", "value": track, "message": sprintf("input.track %q is not one of %v. Denying.", [track, tracks])}
}

violations contains v if {
	not trust_class in trust_classes
	v := {"code": "INPUT_TRUST_CLASS_UNKNOWN", "value": trust_class, "message": sprintf("upstream.trust_class %q is not one of %v. An unrecognised or missing class denies. Denying.", [trust_class, trust_classes])}
}

violations contains v if {
	not signature_state in signature_states
	v := {"code": "INPUT_SIGNATURE_STATE_UNKNOWN", "value": signature_state, "message": sprintf("upstream.signature %q is not one of %v. Denying.", [signature_state, signature_states])}
}

violations contains v if {
	some kind in {"sbom", "provenance", "vex"}
	not attestation_state(kind) in attestation_states
	v := {"code": "INPUT_ATTESTATION_STATE_UNKNOWN", "kind": kind, "value": attestation_state(kind), "message": sprintf("upstream.attestations.%v is %q, not one of %v. Denying.", [kind, attestation_state(kind), attestation_states])}
}

violations contains v if {
	not enforcement in enforcement_modes
	v := {"code": "INPUT_ENFORCEMENT_UNKNOWN", "value": enforcement, "message": sprintf("image.enforcement %q is not one of %v. Denying.", [enforcement, enforcement_modes])}
}

violations contains v if {
	not is_string(image_key)
	v := {"code": "INPUT_IMAGE_KEY_MISSING", "message": "image.key is missing or not a string. Denying."}
}

violations contains v if {
	not is_string(variant)
	v := {"code": "INPUT_VARIANT_MISSING", "message": "image.variant is missing or not a string. Denying."}
}

# Without a parseable evaluated_at no exception can be evaluated and no
# decision is reproducible. Both are fatal.
violations contains v if {
	not evaluated_at_ns
	v := {"code": "INPUT_TIMESTAMP_INVALID", "value": evaluated_at_str, "message": "input.evaluated_at is missing or not RFC3339. Exception expiry cannot be evaluated deterministically. Denying."}
}

violations contains v if {
	some field in numeric_scan_fields
	not is_number(object.get(input, ["scan_results", field], null))
	v := {"code": "INPUT_SCAN_FIELD_MALFORMED", "field": field, "message": sprintf("scan_results.%v is missing or not a number. Denying.", [field])}
}

violations contains v if {
	not is_array(raw_findings)
	v := {"code": "INPUT_FINDINGS_MALFORMED", "message": "scan_results.findings is missing or not an array. Denying."}
}

violations contains v if {
	is_array(raw_findings)
	count(raw_findings) != count(findings)
	v := {"code": "INPUT_FINDING_MALFORMED", "message": sprintf("%v of %v entries in scan_results.findings lack a string id/severity/fix_state/package. Denying.", [count(raw_findings) - count(findings), count(raw_findings)])}
}

# The list and the counts must tell the same story. Catches a truncated list, a
# buggy jq filter, and anyone hand-editing an input document.
violations contains v if {
	c := scan_count("critical_count")
	h := scan_count("high_count")
	count(findings) != c + h
	v := {"code": "INPUT_FINDINGS_INCONSISTENT", "message": sprintf("scan_results.findings holds %v entries but critical_count + high_count is %v. findings must carry every Critical and every High, unfiltered. Denying.", [count(findings), c + h])}
}

violations contains v if {
	not is_digest(object.get(input, ["image", "destination_digest"], null))
	v := {"code": "INPUT_DIGEST_MALFORMED", "field": "image.destination_digest", "message": "image.destination_digest is not a sha256: digest. Denying."}
}

# ===========================================================================
# LEG GATE -- upstream signature verification
# ===========================================================================
# This is the ONLY place trust_class does any work.

# Fatal for every class, including `none`.
violations contains v if {
	signature_state == "failed"
	v := {"code": "UPSTREAM_SIGNATURE_FAILED", "message": sprintf("Signature verification was attempted for %v and did not succeed. A class may decline to verify; it may not verify and lose. Denying.", [image_id])}
}

# The fail-open hole that `none` could otherwise open, closed.
violations contains v if {
	signature_state == "not-applicable"
	class_requires_signature[trust_class] == true
	v := {"code": "UPSTREAM_SIGNATURE_REQUIRED", "trust_class": trust_class, "expected_keyring": object.get(class_keyring, trust_class, missing), "message": sprintf("Trust class %q requires a verified signature against %v, but the reported state is not-applicable. Verification was skipped where it is mandatory. Denying.", [trust_class, object.get(class_keyring, trust_class, missing)])}
}

# Verified against the WRONG key is not verified. Without this rule, anyone who
# can influence the verification step could point cosign at a key they control
# and still report `verified`.
violations contains v if {
	signature_state == "verified"
	class_requires_signature[trust_class] == true
	expected := class_keyring[trust_class]
	verified_with != expected
	v := {"code": "UPSTREAM_KEYRING_MISMATCH", "expected": expected, "actual": verified_with, "message": sprintf("Trust class %q must verify against %v but the recorded keyring was %q. Denying.", [trust_class, expected, verified_with])}
}

# A class declared unverifiable in versions.json cannot report `verified`. The
# contradiction means versions.json is wrong, and a wrong trust declaration is
# exactly what this gate exists to catch.
violations contains v if {
	signature_state == "verified"
	class_requires_signature[trust_class] == false
	v := {"code": "UPSTREAM_TRUST_CLASS_CONTRADICTION", "trust_class": trust_class, "message": sprintf("versions.json declares trust class %q (unverifiable) but the pipeline reports signature state `verified`. Either the class is stale or the verification is bogus. Denying.", [trust_class])}
}

violations contains v if {
	class_requires_attestations[trust_class] == true
	some kind in required_attestation_kinds
	attestation_state(kind) != "present"
	v := {"code": "UPSTREAM_ATTESTATION_MISSING", "kind": kind, "state": attestation_state(kind), "message": sprintf("Trust class %q requires an upstream %v attestation; the state is %q. Either --referrers did not carry it across or upstream stopped publishing it. Denying.", [trust_class, kind, attestation_state(kind)])}
}

# TOFU-every-time is not a trust model. The workflow fetches the live keyring
# and compares it against the committed copy under .github/pdp/keyring/, which
# is CODEOWNERS-gated. An upstream key rotation therefore becomes a visible,
# reviewed pull request rather than a silent substitution.
# Different sentinels on each side so "both absent" denies.
violations contains v if {
	trust_class == "dhi"
	fetched := object.get(input, ["upstream", "keyring_fetched_sha256"], "<fetched-absent>")
	pinned := object.get(input, ["upstream", "keyring_pinned_sha256"], "<pinned-absent>")
	fetched != pinned
	v := {"code": "DHI_KEYRING_DRIFT", "fetched": fetched, "pinned": pinned, "message": sprintf("Live DHI keyring digest %v does not match the committed copy %v. Upstream may have rotated its signing key. Review and update .github/pdp/keyring/dhi-latest.pub in a PR. Denying.", [fetched, pinned])}
}

# ===========================================================================
# LEG GATE -- destination, common to both tracks
# ===========================================================================

destination_allowed(dest) if {
	some p in allowed_destination_prefixes
	startswith(dest, p)
}

violations contains v if {
	dest := object.get(input, ["image", "destination_repo"], missing)
	not destination_allowed(dest)
	v := {"code": "DESTINATION_NAMESPACE_INVALID", "value": dest, "message": sprintf("Destination %q is not under a permitted namespace %v. Denying.", [dest, allowed_destination_prefixes])}
}

violations contains v if {
	some key, _ in object.get(input, ["published_attestation_keys"], {})
	regex.match(secret_key_pattern, key)
	v := {"code": "ATTESTATION_PREDICATE_LEAK", "key": key, "message": sprintf("Attestation predicate contains a credential-shaped key %q. Strip it before publishing. Denying.", [key])}
}

# ===========================================================================
# TRACK: mirror
# ===========================================================================
# Assertion: pinned_digest == source_digest == destination_digest, and the full
# multi-arch index landed intact. This is the content-addressed replacement for
# the reference repo's io.infrashift.image.upstream.digest label -- stronger,
# because it is a fact anyone can re-derive rather than a claim we assert.

violations contains v if {
	track == "mirror"
	some field in ["pinned_digest", "source_digest"]
	not is_digest(object.get(input, ["mirror", field], null))
	v := {"code": "INPUT_DIGEST_MALFORMED", "field": sprintf("mirror.%v", [field]), "message": sprintf("mirror.%v is not a sha256: digest. Denying.", [field])}
}

violations contains v if {
	track == "mirror"
	pinned := object.get(input, ["mirror", "pinned_digest"], "<pin-absent>")
	resolved := object.get(input, ["mirror", "source_digest"], "<resolved-absent>")
	pinned != resolved
	v := {"code": "PIN_MISMATCH", "pinned": pinned, "resolved": resolved, "message": sprintf("versions.json pins %v but the upstream tag now resolves to %v. Either the tag moved or the pin is wrong. Denying.", [pinned, resolved])}
}

violations contains v if {
	track == "mirror"
	src := object.get(input, ["mirror", "source_digest"], "<source-absent>")
	dst := object.get(input, ["image", "destination_digest"], "<dest-absent>")
	src != dst
	v := {"code": "MIRROR_DIGEST_DRIFT", "source": src, "destination": dst, "message": sprintf("Mirrored digest %v does not equal source digest %v. The copy was not content-preserving. Check that regctl image copy ran with --referrers, that the INDEX (not a platform child manifest) was copied, and that nothing re-tagged or re-annotated the manifest. Denying.", [dst, src])}
}

violations contains v if {
	track == "mirror"
	pinned_repo := object.get(input, ["mirror", "pinned_source_repo"], "<pin-absent>")
	actual_repo := object.get(input, ["mirror", "source_repo"], "<actual-absent>")
	pinned_repo != actual_repo
	v := {"code": "UPSTREAM_REPO_MISMATCH", "message": sprintf("Mirrored from %v but versions.json declares %v. Denying.", [actual_repo, pinned_repo])}
}

# An index that lost a platform in transit is a broken mirror even though its
# digest would also have changed. Belt and braces, and it produces a far clearer
# message than a bare digest mismatch.
violations contains v if {
	track == "mirror"
	src_platforms := object.get(input, ["mirror", "source_platforms"], ["<source-absent>"])
	dst_platforms := object.get(input, ["mirror", "destination_platforms"], ["<dest-absent>"])
	sort(src_platforms) != sort(dst_platforms)
	v := {"code": "INDEX_PLATFORM_DRIFT", "source_platforms": sort(src_platforms), "destination_platforms": sort(dst_platforms), "message": sprintf("Source index advertises %v but the destination advertises %v. Copy the index, never a platform child manifest. Denying.", [sort(src_platforms), sort(dst_platforms)])}
}

violations contains v if {
	track == "mirror"
	declared := object.get(input, ["mirror", "declared_platforms"], ["<declared-absent>"])
	actual := object.get(input, ["mirror", "destination_platforms"], ["<dest-absent>"])
	sort(declared) != sort(actual)
	v := {"code": "PLATFORM_SET_MISMATCH", "message": sprintf("versions.json declares platforms %v but the mirrored index carries %v. An upstream silently dropping an architecture must not produce a green build. Denying.", [sort(declared), sort(actual)])}
}

# --- Track constraint ------------------------------------------------------
# `track_constraint` is an anchored RE2 pattern the pinned tag must match. It is
# the machine-readable form of "this image follows the 3.90 patch line".
# Widening it is a policy change, not a digest bump -- hence versions.json sits
# behind @infrashift/security-admins.

tag_within_track if {
	regex.match(object.get(input, ["mirror", "track_constraint"], missing), object.get(input, ["mirror", "resolved_tag"], missing))
}

violations contains v if {
	track == "mirror"
	not tag_within_track
	v := {"code": "TRACK_VIOLATION", "track_constraint": object.get(input, ["mirror", "track_constraint"], missing), "resolved_tag": object.get(input, ["mirror", "resolved_tag"], missing), "message": sprintf("Resolved tag %q does not match the declared track %q. A move off-track is a version-line change and needs an explicit review, not an automated bump. Denying.", [object.get(input, ["mirror", "resolved_tag"], missing), object.get(input, ["mirror", "track_constraint"], missing)])}
}

# ===========================================================================
# TRACK: build
# ===========================================================================
# Assertion: the base-image digest recorded in the built image's
# io.infrashift.image.upstream.digest label equals the base digest pinned in
# versions.json, and the source revision equals the pinned commit. The label
# cross-check is the build-track analogue of the mirror track's digest chain --
# it is what stops a build silently landing on a stale or substituted base.

violations contains v if {
	track == "build"
	some name in required_build_labels
	label(name) == missing
	v := {"code": "BUILD_LABEL_MISSING", "label": name, "message": sprintf("Built image is missing required label %v. Denying.", [name])}
}

violations contains v if {
	track == "build"
	some name in required_build_labels
	label(name) != missing
	trim_space(label(name)) == ""
	v := {"code": "BUILD_LABEL_EMPTY", "label": name, "message": sprintf("Built image label %v is present but empty -- the classic symptom of a pre-FROM ARG not re-declared after FROM. Denying.", [name])}
}

violations contains v if {
	track == "build"
	not is_digest(object.get(input, ["build", "base_image_digest"], null))
	v := {"code": "INPUT_DIGEST_MALFORMED", "field": "build.base_image_digest", "message": "build.base_image_digest is not a sha256: digest. Denying."}
}

# The label and the observed base digest must agree. If they diverge, either the
# label was hand-written or the build did not use the base it claims.
violations contains v if {
	track == "build"
	labelled := object.get(input, ["image", "labels", "io.infrashift.image.upstream.digest"], "<label-absent>")
	observed := object.get(input, ["build", "base_image_digest"], "<observed-absent>")
	labelled != observed
	v := {"code": "BUILD_LABEL_DIGEST_DISAGREES", "labelled": labelled, "observed": observed, "message": sprintf("Label io.infrashift.image.upstream.digest says %v but the build recorded base digest %v. Denying.", [labelled, observed])}
}

# ...and both must equal the pin.
violations contains v if {
	track == "build"
	pinned := object.get(input, ["build", "pinned_base_digest"], "<pin-absent>")
	observed := object.get(input, ["build", "base_image_digest"], "<observed-absent>")
	pinned != observed
	v := {"code": "BUILD_BASE_DIGEST_MISMATCH", "pinned": pinned, "observed": observed, "message": sprintf("versions.json pins base digest %v but the image was built on %v. Bump the pin deliberately or rebuild on the pinned base. Denying.", [pinned, observed])}
}

violations contains v if {
	track == "build"
	pinned := object.get(input, ["build", "pinned_base_repo"], "<pin-absent>")
	actual := object.get(input, ["build", "base_image_repo"], "<actual-absent>")
	pinned != actual
	v := {"code": "BUILD_BASE_REPO_MISMATCH", "message": sprintf("Built on %v but versions.json pins base repo %v. Denying.", [actual, pinned])}
}

# The check that gives the build track its meaning: the review actor
# independently confirms the artifact was built from the reviewed source pin.
violations contains v if {
	track == "build"
	pinned := object.get(input, ["build", "pinned_source_ref"], "<pin-absent>")
	actual := object.get(input, ["build", "source_revision"], "<actual-absent>")
	pinned != actual
	v := {"code": "BUILD_SOURCE_REF_MISMATCH", "pinned": pinned, "actual": actual, "message": sprintf("versions.json pins source ref %v but the build used %v. Denying.", [pinned, actual])}
}

# A git tag or branch is not a pin -- it can be moved or force-pushed. Build
# entries pin a 40-character commit SHA.
violations contains v if {
	track == "build"
	ref := object.get(input, ["build", "source_revision"], missing)
	not regex.match(`^[0-9a-f]{40}$`, ref)
	v := {"code": "BUILD_SOURCE_REF_NOT_PINNED", "value": ref, "message": sprintf("build.source_revision %q is not a 40-character commit SHA. Tags and branches move; commits do not. Denying.", [ref])}
}

violations contains v if {
	track == "build"
	labelled := object.get(input, ["image", "labels", "org.opencontainers.image.revision"], "<label-absent>")
	actual := object.get(input, ["build", "source_revision"], "<actual-absent>")
	labelled != actual
	v := {"code": "BUILD_REVISION_LABEL_DISAGREES", "message": sprintf("Label org.opencontainers.image.revision says %v but the build recorded revision %v. Denying.", [labelled, actual])}
}

# --- Dual provenance: recorded, never gated --------------------------------
# The build records BOTH the hash of the binary it built from source AND the
# hash of the binary extracted from the vendor's official image. Go builds are
# rarely bit-reproducible, so a MISMATCH IS NOT A VIOLATION and must never be
# made one. See .ai/skills/dual-provenance.md.
#
# What IS gated is that the observation was recorded at all, and recorded
# well-formed. A build that quietly skips the comparison must not pass as though
# it performed one.

violations contains v if {
	track == "build"
	object.get(input, ["build", "dual_provenance", "performed"], false) != true
	v := {"code": "DUAL_PROVENANCE_NOT_RECORDED", "message": "build.dual_provenance.performed is not true. The from-source / official-image binary hash comparison is a mandatory recorded observation. Denying."}
}

violations contains v if {
	track == "build"
	object.get(input, ["build", "dual_provenance", "performed"], false) == true
	some field in ["from_source_sha256", "official_image_sha256"]
	not regex.match(`^[0-9a-f]{64}$`, object.get(input, ["build", "dual_provenance", field], ""))
	v := {"code": "DUAL_PROVENANCE_MALFORMED", "field": field, "message": sprintf("build.dual_provenance.%v is missing or not a 64-hex sha256. Denying.", [field])}
}

violations contains v if {
	track == "build"
	object.get(input, ["build", "dual_provenance", "performed"], false) == true
	not is_digest(object.get(input, ["build", "dual_provenance", "official_image_digest"], null))
	v := {"code": "DUAL_PROVENANCE_MALFORMED", "field": "official_image_digest", "message": "build.dual_provenance.official_image_digest is not a sha256: digest. Denying."}
}

# The reference image must be the one versions.json pins, or the comparison is
# against something nobody reviewed.
violations contains v if {
	track == "build"
	object.get(input, ["build", "dual_provenance", "performed"], false) == true
	pinned := object.get(input, ["build", "pinned_crosscheck_digest"], "<pin-absent>")
	used := object.get(input, ["build", "dual_provenance", "official_image_digest"], "<used-absent>")
	pinned != used
	v := {"code": "DUAL_PROVENANCE_REFERENCE_UNPINNED", "pinned": pinned, "used": used, "message": sprintf("Cross-check compared against %v but versions.json pins %v. Denying.", [used, pinned])}
}

# ===========================================================================
# THE CVE GATE
# ===========================================================================
# One gate. Same thresholds for dhi, internal and none; same for mirror and
# build. The only per-image variation permitted is a named, expiring, justified
# waiver in the committed register.

# Advice only -- it steers triage, it does not alter the gate.
remediation_hint := "DHI advertises a near-zero known-CVE baseline, so a finding here is far more likely a stale pin than an acceptable risk. Re-resolve the upstream digest (make -f Ops.mk verify-pins) before considering an exception." if {
	trust_class == "dhi"
} else := "Rebuild on a current base (check the sibling repo for a newer trusted ubi9-micro digest) or bump the pinned upstream source before considering an exception." if {
	track == "build"
} else := "Check whether a newer release on the declared track clears this before considering an exception."

violations contains v if {
	some f in blocking_findings
	f.severity == "Critical"
	v := {"code": "CVE_CRITICAL", "cve": f.id, "package": f.package, "fix_state": f.fix_state, "remediation_hint": remediation_hint, "message": sprintf("Critical %v in %v (fix: %v). Criticals block unconditionally, fix available or not. Denying.", [f.id, f.package, f.fix_state])}
}

violations contains v if {
	some f in blocking_findings
	f.severity == "High"
	v := {"code": "CVE_HIGH_FIXABLE", "cve": f.id, "package": f.package, "remediation_hint": remediation_hint, "message": sprintf("High %v in %v has an available upstream fix, so it is actionable. Denying.", [f.id, f.package])}
}

# --- Exception hygiene, leg-scoped -----------------------------------------
# A malformed entry already fails closed -- it simply does not waive. This rule
# exists so the author learns WHY, instead of losing an hour to "why isn't my
# exception working".

violations contains v if {
	some exc in exception_list
	object.get(exc, "image", missing) == image_key
	not exception_valid(exc)
	v := {"code": "EXCEPTION_INVALID", "exception_id": object.get(exc, "id", missing), "message": sprintf("Exception %v for %v is malformed and waives nothing. Required: id, image, variant, package, non-empty cves[], owner, ticket, issued, expires, and a justification of at least %v characters; expires must be after issued and within %v days of it.", [object.get(exc, "id", missing), image_key, min_justification_chars, max_exception_days])}
}

# ===========================================================================
# Warnings -- recorded in the verdict, never blocking
# ===========================================================================

warnings contains w if {
	count(recorded_findings) > 0
	w := {"code": "CVE_HIGH_UNFIXABLE", "count": count(recorded_findings), "message": sprintf("%v High vulnerabilities with no available upstream fix. Recorded, not blocking: no action we control clears them, and blocking would gate every image on a vendor backport schedule.", [count(recorded_findings)])}
}

warnings contains w if {
	m := scan_count("medium_count")
	m > 0
	w := {"code": "CVE_MEDIUM_PRESENT", "count": m, "message": sprintf("%v Medium vulnerabilities.", [m])}
}

# Every waived finding surfaces here as well as in decision.waived, so a reader
# of the warnings list alone still sees them. Nothing is silently dropped.
warnings contains w if {
	some f in waived_findings
	w := {"code": "CVE_WAIVED", "cve": f.id, "severity": f.severity, "package": f.package, "waiver_id": f.waiver_id, "expires": f.waiver_expires, "owner": f.waiver_owner, "message": sprintf("%v %v in %v waived by %v (owner %v, expires %v).", [f.severity, f.id, f.package, f.waiver_id, f.waiver_owner, f.waiver_expires])}
}

warnings contains w if {
	some exc in exception_list
	object.get(exc, "image", missing) == image_key
	exception_valid(exc)
	expiry := time.parse_rfc3339_ns(exc.expires)
	expiry > evaluated_at_ns
	expiry < evaluated_at_ns + (expiry_warning_days * ns_per_day)
	w := {"code": "EXCEPTION_EXPIRING_SOON", "exception_id": exc.id, "expires": exc.expires, "owner": exc.owner, "message": sprintf("Exception %v expires %v, under %v days away. Re-triage or it will start blocking.", [exc.id, exc.expires, expiry_warning_days])}
}

# An expired exception stops waiving, which surfaces as a CVE_* violation. This
# warning names the lapsed entry so the cause is obvious from the verdict.
warnings contains w if {
	some exc in exception_list
	object.get(exc, "image", missing) == image_key
	exception_has_required_fields(exc)
	exception_dates_parse(exc)
	expiry := time.parse_rfc3339_ns(exc.expires)
	expiry <= evaluated_at_ns
	w := {"code": "EXCEPTION_EXPIRED", "exception_id": exc.id, "expires": exc.expires, "message": sprintf("Exception %v expired on %v and no longer waives anything. Re-triage or prune it.", [exc.id, exc.expires])}
}

warnings contains w if {
	class_requires_attestations[trust_class] == true
	attestation_state("vex") != "present"
	w := {"code": "UPSTREAM_VEX_ABSENT", "message": "No upstream VEX attestation found. Scan results are un-suppressed and may overcount."}
}

# Runtime variants should not run as root. Dev variants legitimately ship a
# shell, a package manager and root -- that is what they are for -- so they are
# exempt from THIS rule and from nothing else. Note this is a surface rule, not
# a CVE rule: the CVE gate is identical for both variants.
#
# Shipped as a WARNING for the first cycle because the DHI runtime config user
# is unverified at design time. To promote it, move this block from
# `warnings contains` to `violations contains` verbatim. That is the whole change.
warnings contains w if {
	variant != "dev"
	u := object.get(input, ["image", "config_user"], missing)
	u in {"", "0", "root", missing}
	w := {"code": "RUNTIME_RUNS_AS_ROOT", "value": u, "message": sprintf("Runtime variant %v reports config user %q. Runtime variants are expected to be non-root.", [image_id, u])}
}

# ===========================================================================
# Observations -- neither gate nor warning. Recorded into the signed verdict.
# ===========================================================================

observations contains o if {
	track == "build"
	object.get(input, ["build", "dual_provenance", "performed"], false) == true
	dp := input.build.dual_provenance
	o := {
		"code": "DUAL_PROVENANCE",
		"from_source_sha256": dp.from_source_sha256,
		"official_image_sha256": dp.official_image_sha256,
		"official_image_digest": dp.official_image_digest,
		"reproducibility_tier": object.get(dp, "reproducibility_tier", "unknown"),
		"match": dp.from_source_sha256 == dp.official_image_sha256,
		"gating": false,
		"message": "Recorded comparison of our from-source binary against the binary in the vendor's official image. This is an OBSERVATION, NOT A GATE: Go builds are rarely bit-reproducible, so a mismatch is expected and proves nothing on its own. A match is weak corroboration that the same source produced both. Neither outcome affects the decision.",
	}
}

# ===========================================================================
# Decision
# ===========================================================================

default decision := {
	"allow": false,
	"namespace": "quarantine",
	"violations": [],
	"warnings": [],
	"observations": [],
	"findings": [],
	"error": "policy did not evaluate",
}

decision := {
	"allow": promote_allowed,
	"namespace": target_namespace,
	"image": image_id,
	"image_key": image_key,
	"variant": variant,
	"dev_variant": variant == "dev",
	"track": track,
	"trust_class": trust_class,
	"signature_state": signature_state,
	"enforcement": enforcement,
	"evaluated_at": evaluated_at_str,
	"counts": {
		"blocking": count(blocking_findings),
		"waived": count(waived_findings),
		"recorded": count(recorded_findings),
		"violations": count(violations),
		"warnings": count(warnings),
	},
	"findings": sort(classified_findings),
	"violations": sort([v | some v in violations]),
	"warnings": sort([w | some w in warnings]),
	"observations": sort([o | some o in observations]),
	"waived": waived_findings,
}

# MUST have a default. Without one, promote_allowed is undefined whenever there
# are violations, which makes the whole `decision` object undefined and falls
# back to the terse default -- losing every violation detail exactly when the
# operator needs it most. Fail-closed AND informative.
default promote_allowed := false

promote_allowed if count(violations) == 0

# `observe` still computes and publishes every violation and still routes the
# image to quarantine. It only stops the pipeline hard-failing, so a new
# upstream can be onboarded and triaged without red-lighting main. It is NOT a
# route into trusted/.
promote_allowed if {
	enforcement == "observe"
	count(violations) > 0
}

target_namespace := "trusted" if {
	count(violations) == 0
} else := "quarantine"

# ===========================================================================
# REPO GATE -- scope: the repository, not an image
# ===========================================================================

default repo_decision := {
	"allow": false,
	"violations": [],
	"warnings": [],
	"error": "policy did not evaluate",
}

repo_decision := {
	"allow": count(repo_violations) == 0,
	"counts": {"violations": count(repo_violations), "warnings": count(repo_warnings)},
	"evaluated_at": evaluated_at_str,
	"violations": sort([v | some v in repo_violations]),
	"warnings": sort([w | some w in repo_warnings]),
}

repo_violations contains v if {
	not evaluated_at_ns
	v := {"code": "INPUT_TIMESTAMP_INVALID", "message": "input.evaluated_at is missing or not RFC3339. Denying."}
}

# --- Secret scanning -------------------------------------------------------
# The reference asserted "gitleaks_passed": true as a hardcoded literal in a
# shell heredoc while .gitleaks.toml was 0 bytes and every rule was disabled.
# These rules consume MEASURED facts instead: the tool ran, the config is
# non-trivial, it extends the defaults, and the findings list is a real array.

repo_violations contains v if {
	object.get(input, ["gitleaks", "status"], missing) != "ran"
	v := {"code": "GITLEAKS_DID_NOT_RUN", "message": "gitleaks.status is not \"ran\". A gate that did not execute is not a pass. Denying."}
}

repo_violations contains v if {
	not is_array(object.get(input, ["gitleaks", "findings"], null))
	v := {"code": "GITLEAKS_REPORT_MALFORMED", "message": "gitleaks.findings is missing or not an array. Denying."}
}

repo_violations contains v if {
	not is_number(object.get(input, ["gitleaks", "config_bytes"], null))
	v := {"code": "GITLEAKS_CONFIG_UNKNOWN", "message": "gitleaks.config_bytes is missing or not a number. Denying."}
}

repo_violations contains v if {
	b := object.get(input, ["gitleaks", "config_bytes"], null)
	is_number(b)
	b < 64
	v := {"code": "GITLEAKS_CONFIG_EMPTY", "bytes": b, "message": sprintf(".gitleaks.toml is %v bytes. An empty config silently disables every rule and exits 0. Denying.", [b])}
}

repo_violations contains v if {
	object.get(input, ["gitleaks", "uses_default_ruleset"], false) != true
	v := {"code": "GITLEAKS_DEFAULTS_DISABLED", "message": ".gitleaks.toml must set [extend] useDefault = true. Denying."}
}

repo_violations contains v if {
	some leak in object.get(input, ["gitleaks", "findings"], [])
	v := {"code": "SECRET_DETECTED", "file": object.get(leak, "File", missing), "rule": object.get(leak, "RuleID", missing), "message": sprintf("Secret detected in %v (rule %v). Denying.", [object.get(leak, "File", missing), object.get(leak, "RuleID", missing)])}
}

# --- versions.json schema --------------------------------------------------
# Validated in policy as well as in JSON Schema, so a bad trust class, an
# unpinned digest, or a widened track can never reach the leg gate at all.

versions_images := object.get(input, ["versions", "images"], {})

repo_violations contains v if {
	not is_object(object.get(input, ["versions", "images"], null))
	v := {"code": "VERSIONS_MALFORMED", "message": "versions.json has no `images` object. Denying."}
}

repo_violations contains v if {
	some key, img in versions_images
	not object.get(img, "kind", missing) in tracks
	v := {"code": "VERSIONS_KIND_INVALID", "image": key, "message": sprintf("images.%v.kind is %q, not one of %v. Denying.", [key, object.get(img, "kind", missing), tracks])}
}

repo_violations contains v if {
	some key, img in versions_images
	not object.get(img, "upstreamTrust", missing) in trust_classes
	v := {"code": "VERSIONS_TRUST_CLASS_INVALID", "image": key, "message": sprintf("images.%v.upstreamTrust is %q, not one of %v. Denying.", [key, object.get(img, "upstreamTrust", missing), trust_classes])}
}

repo_violations contains v if {
	some key, img in versions_images
	object.get(img, "upstreamTrust", missing) == "dhi"
	not startswith(object.get(img, "upstreamRepo", missing), "dhi.io/")
	v := {"code": "VERSIONS_DHI_REPO_INVALID", "image": key, "message": sprintf("images.%v declares trust class dhi but upstreamRepo %q is not on dhi.io. Denying.", [key, object.get(img, "upstreamRepo", missing)])}
}

# --- mirror entries --------------------------------------------------------

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "mirror"
	not is_object(object.get(img, "variants", null))
	v := {"code": "VERSIONS_VARIANTS_MISSING", "image": key, "message": sprintf("mirror entry images.%v has no `variants` object. Denying.", [key])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "mirror"
	some vname, vspec in object.get(img, "variants", {})
	not is_digest(object.get(vspec, "digest", null))
	v := {"code": "VERSIONS_DIGEST_INVALID", "image": key, "variant": vname, "message": sprintf("images.%v.variants.%v.digest is not a sha256: digest. Pins are by index digest, never by tag alone. Denying.", [key, vname])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "mirror"
	some vname, vspec in object.get(img, "variants", {})
	not is_string(object.get(vspec, "tag", null))
	v := {"code": "VERSIONS_TAG_MISSING", "image": key, "variant": vname, "message": sprintf("images.%v.variants.%v.tag is missing; the tag is required for re-resolution. Denying.", [key, vname])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "mirror"
	some vname, vspec in object.get(img, "variants", {})
	not is_string(object.get(vspec, "track", null))
	v := {"code": "VERSIONS_TRACK_MISSING", "image": key, "variant": vname, "message": sprintf("images.%v.variants.%v.track is missing. Every pin declares the version line it follows, as an anchored regex. Denying.", [key, vname])}
}

# An unanchored track silently permits far more than it appears to: `3\.90\.`
# without anchors also matches `13.90.7`. Anchors are mandatory.
anchored(t) if {
	startswith(t, "^")
	endswith(t, "$")
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "mirror"
	some vname, vspec in object.get(img, "variants", {})
	t := object.get(vspec, "track", null)
	is_string(t)
	not anchored(t)
	v := {"code": "VERSIONS_TRACK_UNANCHORED", "image": key, "variant": vname, "message": sprintf("images.%v.variants.%v.track %q must be anchored with ^ and $. An unanchored track matches far more than it looks like it does. Denying.", [key, vname, t])}
}

# A track that does not match its own current pin is either a typo or a silently
# widened constraint. Both must fail here, before any mirror runs.
versions_track_matches(vspec) if regex.match(vspec.track, vspec.tag)

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "mirror"
	some vname, vspec in object.get(img, "variants", {})
	is_string(object.get(vspec, "track", null))
	is_string(object.get(vspec, "tag", null))
	not versions_track_matches(vspec)
	v := {"code": "VERSIONS_TRACK_MISMATCH", "image": key, "variant": vname, "message": sprintf("images.%v.variants.%v: tag %q does not match its own track %q. Denying.", [key, vname, vspec.tag, vspec.track])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "mirror"
	not is_array(object.get(img, "platforms", null))
	v := {"code": "VERSIONS_PLATFORMS_MISSING", "image": key, "message": sprintf("mirror entry images.%v must declare a `platforms` array. Denying.", [key])}
}

# --- build entries ---------------------------------------------------------

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "build"
	some field in ["source", "toolchain", "base", "caSource", "containerfile"]
	not is_string(object.get(img, field, null))
	v := {"code": "VERSIONS_BUILD_FIELD_MISSING", "image": key, "field": field, "message": sprintf("build entry images.%v.%v is missing. Denying.", [key, field])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "build"
	not object.get(img, "upstreamTrust", missing) == "internal"
	v := {"code": "VERSIONS_BUILD_TRUST_CLASS_INVALID", "image": key, "message": sprintf("build entry images.%v must declare upstreamTrust \"internal\" -- the base image is ours and is verifiable against the sibling repo's committed release key. Denying.", [key])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "build"
	not object.get(img, "source", missing) in object.keys(object.get(input, ["versions", "sources"], {}))
	v := {"code": "VERSIONS_BUILD_SOURCE_DANGLING", "image": key, "message": sprintf("images.%v.source %q has no matching entry under sources. Denying.", [key, object.get(img, "source", missing)])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "build"
	not object.get(img, "base", missing) in object.keys(object.get(input, ["versions", "bases"], {}))
	v := {"code": "VERSIONS_BUILD_BASE_DANGLING", "image": key, "message": sprintf("images.%v.base %q has no matching entry under bases. Denying.", [key, object.get(img, "base", missing)])}
}

repo_violations contains v if {
	some key, img in versions_images
	img.kind == "build"
	some arch in ["amd64", "arm64"]
	arch in object.get(img, "arches", [])
	not is_digest(object.get(img, ["crosscheck", arch, "digest"], null))
	v := {"code": "VERSIONS_CROSSCHECK_DIGEST_INVALID", "image": key, "arch": arch, "message": sprintf("images.%v.crosscheck.%v.digest is not a sha256: digest. The cross-check reference must be pinned per platform, never by index digest. Denying.", [key, arch])}
}

# --- sources ---------------------------------------------------------------
# A git tag is not a pin. Every source commit is a 40-hex SHA.

versions_sources := object.get(input, ["versions", "sources"], {})

repo_violations contains v if {
	some key, src in versions_sources
	not is_object(object.get(src, "repos", null))
	not regex.match(`^[0-9a-f]{40}$`, object.get(src, "commit", ""))
	v := {"code": "VERSIONS_SOURCE_REF_NOT_PINNED", "source": key, "value": object.get(src, "commit", missing), "message": sprintf("sources.%v.commit is not a 40-character commit SHA. Tags and branches move; commits do not. Denying.", [key])}
}

repo_violations contains v if {
	some key, src in versions_sources
	some rname, r in object.get(src, "repos", {})
	not regex.match(`^[0-9a-f]{40}$`, object.get(r, "commit", ""))
	v := {"code": "VERSIONS_SOURCE_REF_NOT_PINNED", "source": sprintf("%v/%v", [key, rname]), "value": object.get(r, "commit", missing), "message": sprintf("sources.%v.repos.%v.commit is not a 40-character commit SHA. Denying.", [key, rname])}
}

repo_violations contains v if {
	some key, src in versions_sources
	t := object.get(src, "track", missing)
	is_string(t)
	not anchored(t)
	v := {"code": "VERSIONS_TRACK_UNANCHORED", "source": key, "message": sprintf("sources.%v.track %q must be anchored with ^ and $. Denying.", [key, t])}
}

# Lockstep: every image naming a source with a `lockstep` list must appear in
# that list, and vice versa. This is what makes Dapr's three images structurally
# incapable of drifting apart.
repo_violations contains v if {
	some key, src in versions_sources
	is_array(object.get(src, "lockstep", null))
	declared := {n | some n in src.lockstep}
	actual := {ik | some ik, img in versions_images; object.get(img, "source", missing) == key}
	declared != actual
	v := {"code": "VERSIONS_LOCKSTEP_MISMATCH", "source": key, "declared": sort([n | some n in declared]), "actual": sort([n | some n in actual]), "message": sprintf("sources.%v.lockstep declares %v but the images pointing at it are %v. They must match exactly, or a partial version bump becomes possible. Denying.", [key, sort([n | some n in declared]), sort([n | some n in actual])])}
}

# --- Exception register hygiene, repo-scoped -------------------------------

repo_violations contains v if {
	not is_array(data.exceptions)
	v := {"code": "EXCEPTIONS_MALFORMED", "message": "exceptions.yaml must contain a top-level `exceptions` list. Denying."}
}

repo_violations contains v if {
	some exc in exception_list
	not object.get(exc, "image", missing) in object.keys(versions_images)
	v := {"code": "EXCEPTION_ORPHANED", "exception_id": object.get(exc, "id", missing), "message": sprintf("Exception %v targets image %q, which is not in versions.json. Prune it. Denying.", [object.get(exc, "id", missing), object.get(exc, "image", missing)])}
}

repo_violations contains v if {
	some exc in exception_list
	not exception_valid(exc)
	v := {"code": "EXCEPTION_INVALID", "exception_id": object.get(exc, "id", missing), "message": sprintf("Exception %v is malformed and waives nothing. Required: id, image, variant, package, non-empty cves[], owner, ticket, issued, expires, and a justification of at least %v characters; expires must be after issued and within %v days of it.", [object.get(exc, "id", missing), min_justification_chars, max_exception_days])}
}

repo_violations contains v if {
	some i, a in exception_list
	some j, b in exception_list
	i < j
	object.get(a, "id", missing) == object.get(b, "id", missing)
	v := {"code": "EXCEPTION_DUPLICATE_ID", "exception_id": object.get(a, "id", missing), "message": sprintf("Exception id %v appears more than once. Ids must be unique. Denying.", [object.get(a, "id", missing)])}
}

# Lapsed entries are a WARNING, not a violation. Making them fatal would
# red-light every unrelated PR on the day one expires. Expiry already does its
# real work at the leg gate, where the finding starts blocking again.
repo_warnings contains w if {
	some exc in exception_list
	exception_has_required_fields(exc)
	exception_dates_parse(exc)
	expiry := time.parse_rfc3339_ns(exc.expires)
	expiry <= evaluated_at_ns
	w := {"code": "EXCEPTION_EXPIRED", "exception_id": exc.id, "expires": exc.expires, "owner": exc.owner, "message": sprintf("Exception %v expired on %v. Re-triage or prune it.", [exc.id, exc.expires])}
}

repo_warnings contains w if {
	some exc in exception_list
	exception_valid(exc)
	expiry := time.parse_rfc3339_ns(exc.expires)
	expiry > evaluated_at_ns
	expiry < evaluated_at_ns + (expiry_warning_days * ns_per_day)
	w := {"code": "EXCEPTION_EXPIRING_SOON", "exception_id": exc.id, "expires": exc.expires, "owner": exc.owner, "message": sprintf("Exception %v expires %v.", [exc.id, exc.expires])}
}
