---
id: "01a18382-f2b9-77e6-acf1-7015b50cd2b3"
title: "The digest is the claim"
type: "component"
tags:
  - "architecture"
  - "mirror"
  - "digest"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "Why mirrored images carry no labels of ours, and the five digest checks that three actors make at three stages."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/review-leg.sh"
    title: "review-leg.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-leg.sh"
    title: "release-leg.sh"
---

# The digest is the claim

A mirrored image carries no label of ours, because a label changes the digest. Our provenance is the digest itself, and an attestation records the rest.

## Why a digest and not a label

The reference repository builds its images, so it adds the label `io.infrashift.image.upstream.digest`. We cannot add a label to a mirrored image without a change to its digest. The digest is a stronger proof than a label. A label is only our assertion. All persons can derive a digest again, with no trust in us.

Thus a mirrored image gets no labels of ours. The vendor labels stay as they are. Our provenance goes into an attestation. A built image is different: it carries five required labels. See [Required labels on built images](/architecture/required-labels-on-built-images--01a18382f2eb.md).

A user can do the check with one command on each image:

```console
$ regctl manifest head ghcr.io/infrashift/trusted-service-containers/trusted/traefik:3-debian13
$ regctl manifest head dhi.io/traefik:3-debian13
```

The two commands return the same digest.

## The five checks

Three actors check the digest five times, at three stages:

1. `versions.json` pins the upstream index digest. CODEOWNERS protects the file.
2. `scripts/mirror-leg.sh` copies by digest, never by tag.
3. `scripts/mirror-leg.sh` then asserts that the destination resolves to the same digest.
4. `scripts/review-leg.sh` resolves the digest again, live from GHCR. It compares the result with `versions.json` in the repository, not with the evidence bundle.
5. `scripts/release-leg.sh` asserts the digest a third time, on the promoted reference.

## Related

* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [The review actor re-derives the facts](/architecture/the-review-actor-re-derives-the-facts--01a18382f356.md): why the review actor does not use the build evidence.
* [Promotion](/architecture/promotion--01a18382f371.md)
* [Pins and tracks in versions.json](/architecture/pins-and-tracks-in-versions-json--01a18382f304.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
