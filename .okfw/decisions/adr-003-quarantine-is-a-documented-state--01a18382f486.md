---
id: "01a18382-f486-74bb-9da8-cc2541391404"
title: "ADR-003: Quarantine is a documented state"
type: "decision"
tags:
  - "decision"
  - "quarantine"
created: "2026-10-28T12:16:00-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "ADR-003 makes quarantine/ a permanent state for images with violations, with full evidence and only an immutable tag."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/README.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
    title: "Ops.mk (clean-ghcr-namespace)"
x:
  adr: 3
---

# ADR-003: Quarantine is a documented state

ADR-003 makes `quarantine/` a documented state. A quarantined image has full evidence and an immutable tag, but never the clean upstream-shaped tag.

**Status:** Accepted, 2026-08-18.

## Context

An image can have violations. In `enforce` mode, its verdict is `FAIL`. In `observe` mode, its verdict is `PASS`. In both modes, the image needs a place that keeps its evidence. A consumer must not get it by mistake.

## Decision

* The pipeline mirrors or builds, scans and signs an image that has violations, as for all other images.
* The image has a signed verdict that records its violations.
* The image goes to `quarantine/` in both enforcement modes. An image with no violations goes to `trusted/` in both modes.
* It gets only the immutable `-<shortsha>` tag (`-<shortsha>-<arch>` on the build track).
* It never gets the clean upstream-shaped tag under `trusted/`.
* `quarantine/` is permanent. It is not a place to discard images.

## Consequences

* A typing error in a registry mirror cannot resolve to a quarantined image. To use one, a consumer must give the exact commit.
* `make -f Ops.mk clean-ghcr-namespace` refuses `quarantine/`, because it holds signed, referenced artifacts.
* An `observe` image that has blocking findings, for example nexus3 or mssql, can stay in `quarantine/` for a long time. That is a known state, not a failure of the pipeline.

## Related

* [Registry namespaces and cleanup](/architecture/registry-namespaces-and-cleanup--01a18382f3dd.md)
* [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
