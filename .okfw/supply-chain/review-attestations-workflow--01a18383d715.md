---
id: "01a18383-d715-78b0-bdb5-8fca1e91019c"
title: "Review Attestations workflow"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "review"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "How review.yml verifies each leg again as Review-Actor, signs a verdict, and resolves the review/cve-policy status."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/review.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/review-leg.sh"
    title: "scripts/review-leg.sh"
---

# Review Attestations workflow

The `Review Attestations` workflow (`.github/workflows/review.yml`) is the review actor. It verifies the evidence of each leg, makes the important facts again from trusted sources, evaluates the PDP, and signs a verdict. By design, a human must approve each run before it gets the review key. On 2026-10-28, `Review-Actor` had no required reviewers, so no approval occurred. See [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md).

## Trigger and actor

| Item | Value |
|---|---|
| Trigger | `workflow_run` of `CI Build & Audit`, type `completed` |
| Condition | The build run succeeded and came from a `pull_request` event. |
| Environment | `Review-Actor`. The design gives it Required Reviewers and `prevent_self_review`. On 2026-10-28 it had no protection rules. |
| Top-level permissions | `permissions: {}` |

A `workflow_run` workflow cannot report a check on the pull request. Thus the [PR Review Gate workflow](/supply-chain/pr-review-gate-workflow--01a18383d6d2.md) seeds `review/cve-policy`, and the `Review Summary` job of this workflow resolves it.

## Jobs

| Job | What it does |
|---|---|
| `Resolve PR` | Finds the pull request number and the head commit. If the event has no pull request, it asks the commits API. It checks the shape of both values. |
| `Load Matrix` | Downloads `build-matrix.json` from the build run and checks it with the [matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md). |
| `Review <leg>` | Runs `scripts/review-leg.sh` for one leg, as `Review-Actor`. |
| `Review Summary` | Writes the review comment and sets `review/cve-policy`. |

## What review-leg.sh does

1. Verify the checksum file and the signature of each evidence file against `build.pub`, before it reads any content.
2. Read the normalised subject. One code path serves both tracks.
3. Verify the attestation signatures.
4. Read the trust class from the checked-out `versions.json`. Stop if the evidence gives a different trust class.
5. Resolve the digests again, live from GHCR.
6. Evaluate `data.tsc.pdp.decision` one time for each platform. The leg verdict is the AND of all platforms.
7. Sign the verdict with the review key.

## The review actor does not trust the build actor

The review actor reads digests live from GHCR. It reads the trust class from the checked-out `versions.json`, not from the evidence bundle. Thus a downgrade of the verification of an image needs a commit that CODEOWNERS review. A change to a workflow is not sufficient. Keep it this way.

## The review comment

The `Review Summary` job writes one table row for each leg. The columns are Leg, Kind, Trust, Verdict, Namespace, Blocking, Waived and Recorded.

* If a leg has the verdict `PASS` but its namespace is not `trusted`, the comment shows **PASS (observe)** with a warning sign. The comment never shows a bare **PASS** in this state.
* If one or more legs go to `quarantine/` and the overall result is success, the comment adds a warning block.
* A folded section lists the violations of each leg, with the "Next step" hint from the PDP.
* A "Waived CVEs" table lists each waived finding with its waiver id, expiry and owner.
* A "Binary cross-check" table shows the dual-provenance result. It never gates.

## The review/cve-policy status

| Condition | State |
|---|---|
| The review job did not complete | `error` |
| All legs `PASS` and none go to `quarantine/` | `success` |
| All legs `PASS`, but one or more `observe` legs go to `quarantine/` | `success`, and the description gives the count |
| One or more legs `FAIL` | `failure` |

An `observe` leg with blocking findings gets a green status. See [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md).

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md)
* [Policy decision point](/supply-chain/policy-decision-point--01a18383d82e.md)
* [CVE gate](/supply-chain/cve-gate--01a18383d875.md)
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
