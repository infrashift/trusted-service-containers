---
id: "01a18383-d851-7ade-9e21-44c737c2d5f3"
title: "Fail-closed policy contract"
type: "component"
tags:
  - "supply-chain"
  - "pdp"
  - "fail-closed"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The five rules at the top of policies.rego that make the PDP deny on missing input, and the test rules for each new rule."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
    title: "CLAUDE.md: fail closed, and prove it"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies_test.rego"
    title: "policies_test.rego"
---

# Fail-closed policy contract

The top of `.github/pdp/policies.rego` gives a five-point fail-closed contract. Each point makes the PDP deny when input is missing or wrong. Read the contract before you edit the policy.

## The five points in the policy file

1. **Numbers.** In Rego, `> 0` against a missing or non-numeric value is undefined. Undefined does not violate. Thus every numeric field has an `is_number()` guard. Do not use the comparison alone.
2. **Enums.** Read every enum with `object.get()` and the sentinel `"<missing>"`. Test it against a closed set. An unknown or absent value violates.
3. **Equality.** When two fields must match, give each side a different sentinel default. Then "both absent" compares unequal and denies.
4. **Negation.** Do not write `not <thing_is_bad>`. An undefined helper makes `not` true, and the rule fails open. Define the positive predicate and negate it, so an undefined helper denies.
5. **Exceptions.** A waiver can only move a finding from `blocking` to `waived`. No integrity, signature, attestation, track or label rule reads a waiver. The policy refers to `waiver_for` in exactly one place.

## The test rules

`CLAUDE.md` adds two rules for every change to the policy:

1. Every new rule needs a test that fails without the rule.
2. The coverage floor is 85%. `make -f Ops.mk policy-test` and the `Repo Gate` job fail below it.

Break a new check on purpose and make sure that it fails. In this repository, three lint rules first passed because they matched their own comments. `scripts/binary-crosscheck.sh` reported a match because it compared two empty strings.

## Examples in the policy

* `scan_count(field)` is undefined, not zero, when a field is absent. `INPUT_SCAN_FIELD_MALFORMED` fires with it.
* `evaluated_at_ns` has no default. A default would make every expiry comparison succeed. When it is undefined, no waiver applies, and `INPUT_TIMESTAMP_INVALID` fires.
* `BUILD_LABEL_DIGEST_DISAGREES` reads the observed digest with the sentinel `"<observed-absent>"`, which differs from the label sentinel.
* `promote_allowed` has `default false`. Without it, a violation would make the full decision undefined, and the detail would be lost.

## Analysis

* `CLAUDE.md` gives the contract as four rules plus the test rule. The policy file gives five points, and its fifth point is about waivers, not tests. Both are correct. This concept gives both lists.
* The policy reads `enforcement` with the default `"enforce"`, not `"<missing>"`. An absent value thus gives the stricter mode. An unknown value still violates with `INPUT_ENFORCEMENT_UNKNOWN`.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Policy decision point](/supply-chain/policy-decision-point--01a18383d82e.md)
* [CVE gate](/supply-chain/cve-gate--01a18383d875.md)
* [Run the checks locally](/operations/run-the-checks-locally--01a18383da08.md)
