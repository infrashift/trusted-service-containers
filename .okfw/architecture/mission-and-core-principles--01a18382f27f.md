---
id: "01a18382-f27f-7167-9195-35f8dd046d18"
title: "Mission and core principles"
type: "component"
tags:
  - "architecture"
  - "principles"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The mission of the repository and its seven core principles, each with a link to the concept that explains it."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/README.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
    title: "The policy and its fail-closed contract"
---

# Mission and core principles

This repository publishes service images whose provenance a person can verify without trust in us. Seven principles define the design.

## Mission

Publish service containers whose provenance a person who does not trust us can verify independently.

The repository is a sibling of `infrashift/trusted-base-images`, which builds the UBI base images. The design follows the reference repository `trusted-base-oci-images`, but it does not copy its defects. See [Defects of the reference repo and their guards](/decisions/defects-of-the-reference-repo-and-their-guards--01a18382f526.md).

## The split that drives the design

There are two kinds of image. Each kind has its own integrity model:

* The [Mirror track](/architecture/mirror-track--01a18382f29c.md) copies a vendor image by digest and never rebuilds it.
* The [Build track](/architecture/build-track--01a18382f2d2.md) compiles a pinned source commit onto our own `ubi9-micro` base.

## Core principles

1. **`versions.json` is sovereign.** No digest lives in another file. `scripts/lint-containerfiles.sh` enforces this. See [Pins and tracks in versions.json](/architecture/pins-and-tracks-in-versions-json--01a18382f304.md).
2. **The digest is the claim.** We cannot add a label to a mirrored image without a change to its digest. Thus the proof is content-addressed, not asserted. Three actors check the digest five times, at three stages. A label is an assertion. A digest is a fact that all persons can derive again. See [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md).
3. **Fail closed, and prove it.** In Rego, `> 0` against a missing value is undefined, and thus does not violate. The policy guards each numeric field and closes each enum. It gives each side of an equality a different sentinel, so "both absent" denies. The policy tests have a coverage floor of 85%.
4. **The trust class drives signature verification only.** It never changes a CVE threshold. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).
5. **One CVE gate applies to every image.** The only change for one image is a waiver. A waiver is dated, justified and reviewed, with a limit of 90 days. The PDP evaluates a waiver against a timestamp that the caller supplies. Thus a decision gives the same result when it runs again.
6. **Key isolation is the `environment:` binding.** There are three actors, three keys and one secret name. In the design, `Review-Actor` has Required Reviewers, so a Review signature is proof that a human approved. On 2026-10-28, the live settings did not match: `Review-Actor` and `Release-Actor` had no required reviewers. See [The three actors](/architecture/the-three-actors--01a18382f33a.md) and [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md).
7. **Never rebuild during promotion.** The promoted image is byte-identical to the reviewed image. The release actor asserts this again. See [Promotion](/architecture/promotion--01a18382f371.md).

## Analysis

The source of principle 3 says "85 tests". On 2026-10-28, `.github/pdp/policies_test.rego` has 99 test rules. The coverage floor of 85% is still correct.

## Related

* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [The three actors](/architecture/the-three-actors--01a18382f33a.md)
* [Repository layout](/architecture/repository-layout--01a18382f432.md)
* [Defects of the reference repo and their guards](/decisions/defects-of-the-reference-repo-and-their-guards--01a18382f526.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
* [README.md describes an older image set and an old test count](/issues/readme-md-describes-an-older-image-set-and-an-old-test-count--01a18395b534.md)
