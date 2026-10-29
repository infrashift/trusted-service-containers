---
id: "01a1838a-173b-7546-ac9b-280017b6567d"
title: "Two code comments point at moved skill cards"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "okfw"
  - "docs"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "Comments in policies.rego and exceptions.yaml cite skill cards that are now stubs; fix them with the next change to .github/pdp/."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
---

# Two code comments point at moved skill cards

## Problem

Two code comments send the reader to skill cards that now only point to the wiki. The paths still exist, so no lint fails. But the reader must go through a stub to find the content.

## Context

| File | Line (about) | Cites |
|---|---|---|
| `.github/pdp/policies.rego` | 731 | `.ai/skills/dual-provenance.md` |
| `.github/pdp/exceptions.yaml` | 22 | `.ai/skills/exception-handling.md` |

A third comment in `.github/pdp/policies.rego` (about line 972) is wrong. It says that `observe` "still routes the image to quarantine". The code sends a leg with no violations to `trusted/` in both modes. Only a leg with violations goes to `quarantine/`. See [ADR-001](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md).

* The wiki is the tracker of record and holds the content of these cards.
* A change in `.github/pdp/` makes `.github/workflows/build.yml` rebuild every image. Do not make a change in these files for the comments only.

## Acceptance criteria

- [ ] With the next change to `.github/pdp/policies.rego`, its comment cites [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md).
- [ ] With the next change to `.github/pdp/exceptions.yaml`, its comment cites the wiki concept for waivers.
- [ ] With the next change to `.github/pdp/policies.rego`, the `observe` comment says that only a leg with violations goes to `quarantine/`.

## Related

* [lint-skills.sh does not check the paths in the wiki](/issues/lint-skills-sh-does-not-check-the-paths-in-the-wiki--01a1838a16b2.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
