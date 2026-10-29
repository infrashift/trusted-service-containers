---
id: "01a18395-b4f1-7b92-9c2c-e77b67a368e4"
title: "The nats config cites a runtime document that does not exist"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "docs"
  - "lint"
  - "nats"
created: "2026-10-28T12:36:28-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "nats-server.conf points at a docs/build-track runtime file that never existed; lint-skills.sh does not scan rootfs/."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/rootfs/nats/etc/nats/nats-server.conf"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-skills.sh"
    title: "scripts/lint-skills.sh"
---

# The nats config cites a runtime document that does not exist

## Problem

`rootfs/nats/etc/nats/nats-server.conf` tells the reader to see "docs/build-track/runtime.md". That file does not exist, and no commit in the history added it. `scripts/lint-skills.sh` does not scan `rootfs/`, so no check finds the bad reference.

## Context

* The reference is in the comment about the open port 4222: "beyond a trusted network. See docs/build-track/runtime.md."
* `docs/build-track/` holds only `docs/build-track/dual-provenance.md`, which is now a pointer to the wiki.
* `scripts/lint-skills.sh` scans `CLAUDE.md`, `README.md`, `SETUP-ENVIRONMENTS.md`, `.ai/PRD.md`, `.ai/skills/` and the markdown in `docs/`. It does not scan config files or code comments.
* The runtime facts for nats (ports, volume, auth warning) are in the [nats](/images/nats--01a183832e00.md) concept.

## Acceptance criteria

- [ ] The comment in `rootfs/nats/etc/nats/nats-server.conf` points at a path that exists, for example the nats concept in `.okfw/images/`.
- [ ] A decision records whether `scripts/lint-skills.sh` also scans comments in `rootfs/`.

## Analysis

A change to `rootfs/` rebuilds the nats image. A change to `scripts/` rebuilds all images. Do this fix with the next change to nats.

## Related

* [nats](/images/nats--01a183832e00.md)
* [lint-skills.sh does not check the paths in the wiki](/issues/lint-skills-sh-does-not-check-the-paths-in-the-wiki--01a1838a16b2.md)
* [Repository layout](/architecture/repository-layout--01a18382f432.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
