---
id: "01a18382-f356-70df-a1b4-f5a363fc6247"
title: "The review actor re-derives the facts"
type: "component"
tags:
  - "architecture"
  - "actors"
  - "review"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The review actor resolves digests live from GHCR and reads the trust class from versions.json, never from the build evidence."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/review-leg.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/review.yml"
    title: "review.yml"
---

# The review actor re-derives the facts

The review actor does not trust the build actor. It resolves each digest again, live from GHCR, and reads the trust class from the checked-out `versions.json`.

## What the review actor reads

* **Digests:** `scripts/review-leg.sh` resolves each digest live from GHCR. It compares the result with `versions.json`, not with the evidence bundle.
* **Trust class:** the review actor reads the trust class from the `versions.json` of the checked-out commit. It never reads the trust class from the evidence bundle.

## Why

The build actor writes the evidence bundle. If the review actor read the trust class from the bundle, an edit to a workflow could lower the verification of an image. The review actor reads `versions.json`. Thus a lower verification needs a commit to that file. CODEOWNERS makes `@infrashift/security-admins` review that commit.

This design also expects Required Reviewers on the `Review-Actor` environment, so that a human approves each verdict. On 2026-10-28, the live settings did not match this design. `Review-Actor` had no protection rules. `Release-Actor` had only a custom deployment branch policy. Neither environment had required reviewers. Thus, on that date, a Review signature was not proof that a human approved. See [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md).

Keep this design. Do not make the review actor read a fact from the evidence when it can derive the fact itself.

## Related

* [The three actors](/architecture/the-three-actors--01a18382f33a.md)
* [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md): the five digest checks.
* [Pins and tracks in versions.json](/architecture/pins-and-tracks-in-versions-json--01a18382f304.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
