---
id: "01a18383-dac5-76c0-befe-432760c57a9e"
title: "Move an image from observe to enforce"
type: "runbook"
tags:
  - "runbook"
  - "enforcement"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:42-05:00"
description: "Change the enforcement of an image to enforce after a review shows zero blocking findings on every leg."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:42-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/ab0c4c5"
    title: "prometheus to enforce (2026-10-01)"
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/5c636c6"
    title: "prometheus-nats-exporter to enforce (2026-10-14)"
---

# Move an image from observe to enforce

This runbook changes the `enforcement` of an image in `versions.json` from `observe` to `enforce`. Under `observe`, a new blocking finding sends a release to `quarantine/` with a green check. Under `enforce`, the same finding fails the pipeline.

## Examples

* Commit `ab0c4c5` (2026-10-01) moved prometheus to `enforce`. The review of PR #25 showed `allow=true`, blocking 0 and waived 0 on both architectures, with six recorded findings.
* Commit `5c636c6` (2026-10-14) moved prometheus-nats-exporter to `enforce`. The review of PR #32 showed `allow=true`, blocking 0, waived 0, recorded 0 and namespace `trusted` on both architectures. Its consumer could not use an image in `quarantine/`.

## When to move

Move an image to `enforce` when one review of its current pins shows these values on every leg:

* The verdict is `PASS`, not **PASS (observe)**.
* The namespace is `trusted`.
* Blocking is 0.

Waived findings are acceptable if each waiver is valid. Recorded findings do not block.

## Procedure

1. Find the review comment of the most recent pull request that built the image.
2. Read the review comment. Blocking must be 0 on every leg of the image.
3. Make sure that the namespace column shows `trusted` on every leg.
4. Create a branch from `main`.
5. Set `enforcement` to `enforce` on the image entry in `versions.json`.
6. Update the `reason` text of the entry. Give the pull request and the review result.
7. Run `make -f Ops.mk validate`.
8. Open the pull request. The change to the image entry rebuilds the legs of that image.
9. Read the new review comment. Blocking must be 0 again, and the status must be `success` without a quarantine count.
10. Update the concept of the image in `images/`.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [Policy decision point](/supply-chain/policy-decision-point--01a18383d82e.md)
* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md)
* [Images overview](/images/images-overview--01a1837da526.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [prometheus](/images/prometheus--01a183832e94.md)
* [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md)
