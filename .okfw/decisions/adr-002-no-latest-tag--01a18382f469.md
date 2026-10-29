---
id: "01a18382-f469-790d-886f-e7b0298c7ac0"
title: "ADR-002: No latest tag"
type: "decision"
tags:
  - "decision"
  - "tags"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "ADR-002 publishes no latest tag for any image, because it has no clear meaning and invites a -dev image into production."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/README.md"
x:
  adr: 2
---

# ADR-002: No latest tag

ADR-002 publishes no `latest` tag for any image, in any namespace.

**Status:** Accepted, 2026-08-18.

## Context

The repository publishes many images. Many of them have a runtime variant and a `-dev` variant. A `-dev` image runs as root and has a shell and a package manager.

## Decision

Do not publish a `latest` tag. Publish only the tags in [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md).

## Consequences

* `latest` has no clear meaning across many images and their variants. We do not have to define a meaning.
* A consumer cannot pull a `-dev` image into production by accident with `latest`.
* Each consumer must name a tag. A mirrored image uses the upstream tag, so a move to our registry is a change of one line.

## Analysis

The source of this decision says "twelve services". On 2026-10-28, `versions.json` has 17 images. The reason is still correct.

## Related

* [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md)
* [ADR-003: Quarantine is a documented state](/decisions/adr-003-quarantine-is-a-documented-state--01a18382f486.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [README.md describes an older image set and an old test count](/issues/readme-md-describes-an-older-image-set-and-an-old-test-count--01a18395b534.md)
