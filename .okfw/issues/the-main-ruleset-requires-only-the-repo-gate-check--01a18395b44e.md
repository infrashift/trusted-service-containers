---
id: "01a18395-b44e-78d5-a25c-53df203d6782"
title: "The main ruleset requires only the Repo Gate check"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "ci"
  - "ruleset"
  - "pipeline"
created: "2026-10-28T12:36:28-05:00"
timestamp: "2026-10-28T12:36:42-05:00"
description: "The main branch ruleset requires only Repo Gate, not review/cve-policy, so a red CVE review does not stop a merge."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:42-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/pr-gate.yml"
    title: ".github/workflows/pr-gate.yml"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/review.yml"
    title: ".github/workflows/review.yml"
---

# The main ruleset requires only the Repo Gate check

## Problem

The branch ruleset on `main` requires only the `Repo Gate` check. `SETUP-ENVIRONMENTS.md` §10 requires three checks: `review/cve-policy`, `build/gate` and `Repo Gate`. Thus a red `review/cve-policy` does not stop a merge.

## Context

* On 2026-10-28, `gh api repos/infrashift/trusted-service-containers/rulesets/21323251` showed one required status check: `Repo Gate`.
* The same ruleset requires 0 approvals and no Code Owner review. §10 requires 1 approval and a Code Owner review. The bypass list is empty, as §10 requires.
* The head commits of PR #35, PR #36, PR #38 and PR #39 had `review/cve-policy` in the state `failure`. All four PRs merged on 2026-10-28. The failures came from the mirror legs. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).
* The comments in `.github/workflows/pr-gate.yml` and `.github/workflows/review.yml` say that `review/cve-policy` must match "the required status check on the main ruleset".
* `.github/workflows/pr-gate.yml` seeds `review/cve-policy` on every PR. It does not seed `build/gate`. `.github/workflows/build.yml` has a path filter, so it does not run on a documentation-only PR.

## Acceptance criteria

- [ ] The ruleset requires `review/cve-policy`, or `SETUP-ENVIRONMENTS.md` §10 records why it does not.
- [ ] A decision records whether `build/gate` is required. If it is, `pr-gate.yml` seeds `build/gate` for a PR that changes no build path.
- [ ] A documentation-only PR can merge after the change.
- [ ] The approval and Code Owner rules of the ruleset agree with §10, or §10 records the difference.

## Analysis

* If `build/gate` becomes required with no seed, a documentation-only PR waits for a check that never reports. The PR cannot merge.
* While `review/cve-policy` is not required, the review comment is the only signal of a `FAIL` verdict. See [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md).
* A required `review/cve-policy` does not block an `observe` leg, because that check is green. See [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md).
* A required `review/cve-policy` blocks every PR while a mirror leg in `enforce` mode fails. On 2026-10-28, the postgres and traefik legs failed. The maintainer must decide if that is the intended result.

## Related

* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
* [PR Review Gate workflow](/supply-chain/pr-review-gate-workflow--01a18383d6d2.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [Set up a new repository from scratch](/operations/set-up-a-new-repository-from-scratch--01a18383db12.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
