---
id: "01a18382-f526-777c-828e-3929433559cf"
title: "Defects of the reference repo and their guards"
type: "decision"
tags:
  - "decision"
  - "reference-repo"
created: "2026-10-28T12:16:00-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The nine defects of trusted-base-oci-images that this repository did not repeat, and the mechanical guard for each one."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/check-no-orphan-rego.sh"
    title: "check-no-orphan-rego.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-skills.sh"
    title: "lint-skills.sh"
---

# Defects of the reference repo and their guards

The reference repository `trusted-base-oci-images` is the model for this design. This concept lists the defects of the reference repository. Each defect has a mechanical guard in this repository.

**Status:** Accepted, 2026-08-18.

## Defects and guards

| Defect in the reference repository | Guard in this repository |
|---|---|
| A 0-byte `.gitleaks.toml` had zero rules and exited 0, while the pipeline attested `gitleaks_passed: true`. | A real `.gitleaks.toml`, an assertion in CI, and a policy that reads the measured bytes of the config. |
| Six orphaned `.rego` files contradicted the live policy. | `scripts/check-no-orphan-rego.sh` |
| Two scripts required `human.pub`, and nobody created it. | No human key. In the design, Required Reviewers on `Review-Actor` is the gate. On 2026-10-28, `Review-Actor` had no required reviewers. See [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md). |
| The `paths` filter drifted from the regex of the gate. | `scripts/lint-workflows.sh` |
| Live private keys were in the working tree. | `.gitignore`, gitleaks rules, and key generation in `/dev/shm` |
| A live OIDC token was published in a public attestation. | The PDP rule `ATTESTATION_PREDICATE_LEAK` |
| The signing job installed tools from unpinned `main`. | `tools.lock` |
| The cleanup read a distro key as a PR number. | An explicit `pullRequest` field |
| Skill cards cited four files that never existed. | `scripts/lint-skills.sh` |

## Context

Most conventions in `CLAUDE.md` exist because the reference repository had a defect that nobody saw before a close examination. This type of defect also occurred here. Three lint rules first passed because they matched their own comments. `scripts/binary-crosscheck.sh` reported a MATCH when it compared two empty strings. See [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md).

## Decision

When you add a check, do these steps:

1. Break the check deliberately.
2. Make sure that the check fails.

## Consequences

* Most guards run in `make -f Ops.mk validate` or in the PDP.
* `.github/workflows/pr-gate.yml` has a `BUILD_PATHS` regex that must cover the `paths:` filter of `build.yml`. The lint checks this. The reason is that the reference repository has a dedicated commit that corrects this drift.

## Related

* [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md)
* [ADR-006: Never pass --replace to cosign attest](/decisions/adr-006-never-pass-replace-to-cosign-attest--01a18382f4e6.md)
* [ADR-007: The wiki is the tracker of record](/decisions/adr-007-the-wiki-is-the-tracker-of-record--01a18382f505.md): the wiki and `scripts/lint-skills.sh`.
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md): the lint rules and the PDP.
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
