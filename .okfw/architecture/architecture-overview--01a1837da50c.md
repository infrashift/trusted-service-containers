---
id: "01a1837d-a50c-7526-9b3a-44be052472a5"
title: "Architecture overview"
type: "overview"
tags:
  - "hub"
  - "architecture"
created: "2026-10-28T12:10:11-05:00"
timestamp: "2026-10-28T12:10:11-05:00"
description: "The parts of the system, the two tracks, the three actors, and how an image moves from build to trusted or quarantine."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:11-05:00"
---

# Architecture overview

This bundle holds the parts of the system and how they connect: the two tracks, the three actors, the pins, promotion and the registry.

Do not put a runbook here. Put it in `operations/`. Do not put a workflow, a PDP rule or a waiver here. Put it in `supply-chain/`. Do not put a decision here. Put it in `decisions/`.

## Find concepts

* List this bundle: read `.okfw/architecture/index.md`.
* Search the bundle: `okfw search "<words>" --type component`.

## Add a concept

1. Search the wiki first. Update a concept that exists, if possible.
2. Run `okfw create "<Title>" --type component --path architecture -d "<one sentence>" --tags architecture,<topic>`.
3. Add a link to the new concept in the list below.
4. Obey the [wiki conventions](/guides/wiki-conventions--01a1837da62e.md) and [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Concepts

Start here:

* [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md): the mission and the seven principles, with links.
* [Repository layout](/architecture/repository-layout--01a18382f432.md): where each part lives.

The two tracks:

* [Mirror track](/architecture/mirror-track--01a18382f29c.md): copy by digest, keep the referrers, never rebuild.
* [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md): the five digest checks; no labels of ours on a mirrored image.
* [Build track](/architecture/build-track--01a18382f2d2.md): build from a pinned commit onto `ubi9-micro`; the three stages.
* [Required labels on built images](/architecture/required-labels-on-built-images--01a18382f2eb.md): the five labels and the ARG trap.

Pins:

* [Pins and tracks in versions.json](/architecture/pins-and-tracks-in-versions-json--01a18382f304.md): full digests, 40-hex commits, anchored tracks.
* [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md): rolling tags, `stdlib` findings, `GOTOOLCHAIN=local`.

Actors and trust:

* [The three actors](/architecture/the-three-actors--01a18382f33a.md): Build, Review and Release, and their keys.
* [The review actor re-derives the facts](/architecture/the-review-actor-re-derives-the-facts--01a18382f356.md): why the review actor does not use the build evidence.
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md): `dhi`, `internal`, `notation`, `none`; signature checks only.
* [Pinned upstream keyrings and identities](/architecture/pinned-upstream-keyrings-and-identities--01a18382f417.md): committed keyrings, drift detection, the notation identity.

Promotion and the registry:

* [Promotion](/architecture/promotion--01a18382f371.md): the signed verdict, and verdict versus namespace.
* [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md): tags for each track and namespace; no `latest`.
* [Dual signing at release](/architecture/dual-signing-at-release--01a18382f3b7.md): keyed without a log, then keyless with a log.
* [Registry namespaces and cleanup](/architecture/registry-namespaces-and-cleanup--01a18382f3dd.md): `development/`, `trusted/`, `quarantine/`, and narrow cleanup.

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Images overview](/images/images-overview--01a1837da526.md): one concept for each image.
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md): the reasons for the design.
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Terminology](/guides/terminology--01a1837da60b.md)
