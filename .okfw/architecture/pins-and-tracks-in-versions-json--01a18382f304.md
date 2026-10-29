---
id: "01a18382-f304-79e5-97e7-b913567872b6"
title: "Pins and tracks in versions.json"
type: "component"
tags:
  - "architecture"
  - "pins"
  - "versions-json"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The rules for pins and tracks in versions.json: full digests only, 40-hex source commits, anchored track regexes that change only in their own PR."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/schemas/versions.schema.json"
    title: "versions.json schema"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/CODEOWNERS"
    title: "CODEOWNERS"
---

# Pins and tracks in versions.json

`versions.json` is the only file that holds a pin. Each pin is a full digest or a 40-hex commit, and an anchored track regex limits where it can go.

## Rules for pins

1. Put each digest in `versions.json` only. Do not put a digest in a Containerfile, a workflow or a script. `scripts/lint-containerfiles.sh` fails the build if a Containerfile holds a digest.
2. Write each image pin as a full `sha256:` digest. A tag is not a pin.
3. Write each source pin as a 40-hex commit. An upstream can move a tag or force-push it.
4. When an upstream stamps a short commit, pin `shortCommit` as data next to the commit. A drift PR must change both together.

`schemas/versions.schema.json` validates the file. `make -f Ops.mk verify-pins` resolves each pin again against the live registries.

## Rules for tracks

A track is an anchored regex in `versions.json`. It limits where a pin can legally go. The drift workflows `drift-base.yml` and `drift-upstream.yml` propose changes inside each track. They never make a track wider.

WARNING: Do not make a track wider as part of another change. A wider track is a policy decision. It needs its own reviewed PR.

1. Anchor each track with `^` and `$`. Without anchors, `3\.90\.` also matches `13.90.7`.
2. Use an exact track, for example `^3-debian13$`, when the vendor moves a rolling tag and only the digest changes.

## Why CODEOWNERS protects the file

`.github/CODEOWNERS` puts `versions.json` under `@infrashift/security-admins`. A wider track can be a change of one character class. At a glance, it looks like a routine digest bump. But it changes each future release from a reviewed decision into an automated bump.

## Related

* [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md): the toolchain pins in the same file.
* [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md)
* [The review actor re-derives the facts](/architecture/the-review-actor-re-derives-the-facts--01a18382f356.md): the review actor reads `versions.json` from the repository.
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [The notes in versions.json are stale](/issues/the-notes-in-versions-json-are-stale--01a18395b56b.md)
