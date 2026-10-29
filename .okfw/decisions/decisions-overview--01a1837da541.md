---
id: "01a1837d-a541-7b06-b225-1971aca8d08a"
title: "Decisions overview"
type: "overview"
tags:
  - "hub"
  - "decisions"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "The decisions that shape this project, one ADR concept each, and the defects of the reference repo that we guard against."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Decisions overview

This bundle holds one ADR concept for each design decision, with its context, the decision and its consequences.

Do not put a measured fact here. Put it in `findings/`. Do not put a description of how a part works here. Put it in `architecture/`.

## Find concepts

* List this bundle: read `.okfw/decisions/index.md`.
* Search the decisions: `okfw search "<words>" --type decision`.

## Add a concept

1. Search the wiki first. If a decision changes an old decision, amend the old ADR or mark it `deprecated`.
2. Run `okfw create "ADR-<nnn>: <Title>" --type decision --path decisions -d "<one sentence>" --tags decision,<topic>`.
3. Add `x:` with `adr: <n>` to the frontmatter.
4. Write the sections Status, Context, Decision, Consequences and Related.
5. Add a link to the new concept in the list below.
6. Obey [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Concepts

The pipeline:

* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md): a new upstream can join without a red `main`. Includes the rule "observe is not a pass".
* [ADR-003: Quarantine is a documented state](/decisions/adr-003-quarantine-is-a-documented-state--01a18382f486.md): a permanent, evidenced state with only an immutable tag.
* [ADR-002: No latest tag](/decisions/adr-002-no-latest-tag--01a18382f469.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md): the binary cross-check never gates.

Tools and signing:

* [ADR-005: Pin cosign to v2.6.1](/decisions/adr-005-pin-cosign-to-v2-6-1--01a18382f4c6.md): keep the same attestation layout as the sibling repository.
* [ADR-006: Never pass --replace to cosign attest](/decisions/adr-006-never-pass-replace-to-cosign-attest--01a18382f4e6.md): it would delete the vendor attestations.

Process:

* [ADR-007: The wiki is the tracker of record](/decisions/adr-007-the-wiki-is-the-tracker-of-record--01a18382f505.md): issues, plans and findings live in `.okfw/`.
* [Defects of the reference repo and their guards](/decisions/defects-of-the-reference-repo-and-their-guards--01a18382f526.md): the nine defects and the guard for each one.

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
