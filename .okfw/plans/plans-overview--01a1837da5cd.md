---
id: "01a1837d-a5cd-7b2a-94a4-e7ca0c23f55b"
title: "Plans overview"
type: "overview"
tags:
  - "hub"
  - "plans"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "The plans of this repository: work with more than one step, each with one state tag: proposed, active, done or dropped."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Plans overview

This bundle holds the plans: the steps of one piece of work that has more than one step. Each plan has one state tag: `proposed`, `active`, `done` or `dropped`.

Do not put a single problem or task here. Record it as an issue in `issues/`. Do not put a decision here. Put it in `decisions/`.

## Find concepts

* List this bundle: read `.okfw/plans/index.md`.
* Active plans: `okfw search --type plan --tag active`.
* Proposed plans: `okfw search --type plan --tag proposed`.

## Add a concept

1. Search the wiki for a plan or an issue about the same work.
2. Run `okfw create "<Title>" --type plan --path plans -d "<one sentence>" --tags plan,proposed`.
3. Add a link to the new plan in the list below.
4. Write the sections Goal, Context, Steps, Verification and Related. Follow the [plan workflow](/guides/plan-workflow--01a1837da67e.md).

A plan that changes an image must say how to check the review. Blocking must be 0, or the plan must say why `quarantine/` is the correct result.

## Concepts

### Roadmap

* [Roadmap](/plans/roadmap--01a18396ce3c.md): the open issues and the waiver expiry dates in time order. It has no state tag.

### Active

* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md): move the PRD, the `.ai` cards, the docs and the issues into this wiki.

### Done and dropped

None yet.

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Plan workflow](/guides/plan-workflow--01a1837da67e.md)
* [Issue workflow](/guides/issue-workflow--01a1837da656.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
