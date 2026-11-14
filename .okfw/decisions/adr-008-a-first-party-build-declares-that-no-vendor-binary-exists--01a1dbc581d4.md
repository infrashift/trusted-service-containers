---
id: "01a1dbc5-81d4-73d2-afa6-0555d3a39ead"
title: "ADR-008: A first-party build declares that no vendor binary exists"
type: "decision"
tags:
  - "decision"
  - "dual-provenance"
  - "build"
  - "first-party"
created: "2026-11-14T14:35:16-06:00"
timestamp: "2026-11-14T14:35:33-06:00"
description: "A build entry for our own infrashift service declares firstParty with a reason in place of crosscheck; absence never means first-party."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-11-14T14:35:33-06:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/provenance-mode.sh"
    title: "scripts/provenance-mode.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/review-leg.sh"
    title: "scripts/review-leg.sh"
x:
  adr: 8
---

# ADR-008: A first-party build declares that no vendor binary exists

A build entry for our own service declares `firstParty` in place of `crosscheck`. The declaration is explicit, has a reason, and is valid only for a source under `https://github.com/infrashift/`.

**Status:** Proposed, 2026-11-14. It needs a review by `@infrashift/security-admins`, because it changes `.github/pdp/policies.rego` and `schemas/versions.schema.json`.

## Context

The build track compares each binary that we build with the same binary in the vendor image. See [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md). The policy denies a build leg that did not do the comparison (`DUAL_PROVENANCE_NOT_RECORDED`).

HALO needs images for two infrashift services: keto-cue and Chit. We are the only publisher of these services. No vendor image exists, so no comparison is possible. Before this decision, `scripts/build-leg.sh` required a `crosscheck` block, and the policy denied every leg without a comparison.

Three dangers come with an exemption:

1. A missing block could become an exemption. Then a deleted `crosscheck` block skips the comparison for a vendor image.
2. Anyone could mark a vendor image first-party and skip its comparison.
3. The build actor could claim the mode in its evidence.

## Decision

A build entry has exactly one of two blocks:

* `crosscheck`: a vendor binary exists. The pipeline compares it, as before.
* `firstParty`: `{ "noVendorBinary": true, "reason": "<at least 40 characters>" }`. No vendor binary exists.

The pipeline records the hash of our binary in both modes. In the first-party mode, the hash is the change detector of ADR-004 without a vendor reference.

### The checks

| Where | Check | Code |
|---|---|---|
| JSON Schema | Exactly one of `crosscheck` and `firstParty`. `noVendorBinary` is the constant `true`. | schema error |
| Repo gate | Neither block. | `VERSIONS_PROVENANCE_MODE_MISSING` |
| Repo gate | Both blocks. | `VERSIONS_FIRST_PARTY_CONFLICT` |
| Repo gate | `noVendorBinary` is not `true`, or the reason is too short. | `VERSIONS_FIRST_PARTY_MALFORMED` |
| Repo gate | The source URL is not under `https://github.com/infrashift/`. The URL comes from `sources.<s>.repos.<r>.url` when the entry has `repo`, else from `sources.<s>.url`. | `VERSIONS_FIRST_PARTY_SOURCE_NOT_INFRASHIFT` |
| Repo gate | A build entry without a valid first-party declaration still needs a per-platform crosscheck digest. | `VERSIONS_CROSSCHECK_DIGEST_INVALID` |
| Leg | The mode in `versions.json` differs from the mode in the build evidence. | `PROVENANCE_MODE_MISMATCH` |
| Leg | The declared source is not under `https://github.com/infrashift/`. | `FIRST_PARTY_SOURCE_NOT_INFRASHIFT` |
| Leg | The reason is missing or too short. | `FIRST_PARTY_REASON_MISSING` |
| Leg | The entry also pins a crosscheck, or the review did not state that it pins none. | `FIRST_PARTY_WITH_CROSSCHECK` |
| Leg | The provenance names a source other than the pinned source. | `FIRST_PARTY_SOURCE_URL_DISAGREES` |
| Leg | The hash of our binary is missing or malformed. | `DUAL_PROVENANCE_MALFORMED` |
| Leg | Any condition of the mode fails. | `DUAL_PROVENANCE_NOT_RECORDED` |

The URL pattern is `^https://github\.com/infrashift/[A-Za-z0-9][A-Za-z0-9._-]*$`. It rejects `github.com/infrashift.evil/`, a path with a slash after the repository name, `..`, and `http://`.

### Why each danger is closed

1. **Absence is not first-party.** `DUAL_PROVENANCE_NOT_RECORDED` negates the positive predicate `first_party_mode_valid`. Each condition of the mode is in that predicate. An undefined or partly true predicate keeps the rule active, as point 4 of the [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md) requires. The declared mode defaults to the strict mode `vendor-crosscheck`.
2. **Only infrashift sources.** The repo gate and the leg policy both check the source URL.
3. **The review actor re-derives the claim.** `scripts/review-leg.sh` reads `declared`, `crosscheck_pinned`, `reason` and `source_url` from the checked-out `versions.json`. It reads only `evidence_mode` and `built_source_url` from the evidence, and the policy requires them to agree with `versions.json`. See [The review actor re-derives the facts](/architecture/the-review-actor-re-derives-the-facts--01a18382f356.md).

`scripts/provenance-mode.sh` applies the same rules before `scripts/build-leg.sh` builds anything. It is a pre-flight check, not the decision. The PDP decides.

### What the evidence records

* `crosscheck.json` has `mode: "first-party"`, the hash of our binary, the reason, the source URL and `comparison.performed: false`.
* The SLSA provenance has no `crosscheck-reference` dependency and one byproduct, `binary/built-from-source`.
* The signed verdict has the observation `FIRST_PARTY_BUILD` and `subject.provenanceMode`. The release attestation copies `provenanceMode`.
* The PR comment lists first-party legs in their own table.

## Consequences

* A first-party image gets no CVE relief. The CVE gate is the same for every image. A test proves it.
* A first-party image has no independent binary check. Its trust comes from the pinned commit of our own repository and from the review of that repository.
* A first-party Containerfile has no crosscheck ARGs and no `io.infrashift.build.crosscheck.image` label. `scripts/lint-containerfiles.sh` enforces this.
* `scripts/drift-upstream.sh` skips the crosscheck update for a first-party entry. Before this change, `null | keys` stopped its jq, and the loop lost the rows of the other images.
* The HALO plan named the field `first_party: true`. This decision uses the camelCase object `firstParty`, because the schema is camelCase and the mode needs a reason.

## The proof

Each new rule has a test in `.github/pdp/policies_test.rego` that fails without the rule. Each first-party leg test expects the specific code and `DUAL_PROVENANCE_NOT_RECORDED`. Thus a deleted specific rule and a weakened predicate both fail a test.

On 2026-11-14, 28 deliberate breaks of the policy were made one at a time. Examples are: delete each rule, remove each condition from each predicate, widen or unanchor the URL pattern, default the declared mode to `first-party`, and resolve the URL without the `repo` key. `opa test` failed for each break. Eight deliberate breaks of `scripts/provenance-mode.sh` also failed `scripts/test-provenance-mode.sh`. A removed `has("crosscheck")` guard failed `scripts/test-drift-upstream.sh`.

## Related

* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [The review actor re-derives the facts](/architecture/the-review-actor-re-derives-the-facts--01a18382f356.md)
* [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md)
* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
