---
id: "01a18383-daeb-798e-bb1f-2d8176803f33"
title: "Read the review comment before you merge an image PR"
type: "runbook"
tags:
  - "runbook"
  - "review"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "How to read the review comment before you merge an image PR: merge only when Blocking is 0 or the PR explains quarantine."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/review.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/29"
    title: "PR #29, merged with blocking findings under observe"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
    title: "CLAUDE.md: observe is not a pass"
---

# Read the review comment before you merge an image PR

This runbook tells you how to read the review comment before you merge a pull request that changes an image. A green `review/cve-policy` check is not a pass. An `observe` leg with blocking findings gets a green check and goes to `quarantine/`.

## Why this runbook exists

PR #29 merged on 2026-10-13, two minutes after a review comment that showed one Critical and seven Highs on each architecture. The check was green, because the image was in `observe`. The review comment then showed a bare **PASS** in the Verdict column. It now shows **PASS (observe)** in that state.

On 2026-10-28, the `main` ruleset requires only the `Repo Gate` check. A red `review/cve-policy` thus does not stop a merge either. The review comment is the signal.

## Procedure

WARNING: Do not merge an image pull request on a green check alone. Read the review comment first.

1. Wait for the `Review Attestations` workflow to finish. If `Review-Actor` has required reviewers, approve the deployment. On 2026-10-28 it had none (see [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)).
2. Open the pull request and find the comment "Trusted Service Containers — review".
3. Read the Verdict column of each leg. **PASS (observe)** means that the leg goes to `quarantine/`.
4. Read the Namespace column. Only `trusted` makes the image usable under its normal tag.
5. Read the Blocking column. It must be 0 on every leg.
6. If Blocking is not 0, open "Policy violations". Read the violations and the "Next step" of each leg.
7. Read the "Waived CVEs" table. Make sure that each waiver is one that you expect, with an owner and an expiry.
8. Read the "Binary cross-check" table only as information. A mismatch is normal and never gates.
9. If Blocking is 0 on every leg, merge.
10. If Blocking is not 0, fix the cause first. Use a newer source, toolchain or base, or a reviewed waiver.
11. If `quarantine/` is the correct result, say so in the pull request, and say why. Then merge.

## What each result means

| Verdict | Namespace | Check | Result |
|---|---|---|---|
| **PASS** | `trusted` | green | The leg has no violations, in `enforce` or `observe`. The image goes to `trusted/`. |
| **PASS (observe)** | `quarantine` | green | An `observe` leg has violations. The image goes to `quarantine/`. Only the exact commit tag can pull it. |
| **FAIL** | `quarantine` | red | An `enforce` leg has violations. The image goes to `quarantine/`. |

Before you open an image pull request, scan the local build. See step 6 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md). Then the review is not the place where you first see a finding.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [CVE gate](/supply-chain/cve-gate--01a18383d875.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
* [Move an image from observe to enforce](/operations/move-an-image-from-observe-to-enforce--01a18383dac5.md)
* [Plan workflow](/guides/plan-workflow--01a1837da67e.md)
* [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
