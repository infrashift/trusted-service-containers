---
id: "01a18382-f505-7cde-aa6f-26357cbb8613"
title: "ADR-007: The wiki is the tracker of record"
type: "decision"
tags:
  - "decision"
  - "okfw"
  - "process"
created: "2026-10-28T12:16:00-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "ADR-007 makes the .okfw/ wiki the place for issues, plans and findings; GitHub issues and the old .ai/ files point to it."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
x:
  adr: 7
---

# ADR-007: The wiki is the tracker of record

ADR-007 makes the `.okfw/` wiki the tracker of record. The wiki holds the issues, plans and findings. Other trackers point to the wiki.

**Status:** Accepted, 2026-10-28, by the maintainer.

## Context

Before this decision, the knowledge of the repository was in many places. These places were GitHub issues from the drift bots, `.ai/PRD.md`, the rule cards in `.ai/skills/`, `CLAUDE.md` and the docs. A reader had to search all of them.

## Decision

1. Record each issue, plan and finding in `.okfw/`.
2. When a drift bot opens a GitHub issue, read it. Then close it with a link to a wiki issue.
3. When you add a new waiver, set its `ticket` to the GitHub URL of the wiki issue.
4. Move the content of `.ai/PRD.md` and of the rule cards into the wiki. The old files become pointers to the wiki.

## Consequences

* The wiki is the one place for the reasons of the design, for open work and for findings.
* `scripts/lint-skills.sh` does not scan `.okfw/` yet. If a backticked path in a concept does not resolve, CI does not fail.
* CI does not run okfw yet. `make -f Ops.mk validate` runs it locally, but `pr-gate.yml` does not.
* The `issues/` bundle records both gaps as open issues. See [Issues overview](/issues/issues-overview--01a1837da5b0.md).

## Related

* [Repository layout](/architecture/repository-layout--01a18382f432.md)
* [Issue workflow](/guides/issue-workflow--01a1837da656.md)
* [Plan workflow](/guides/plan-workflow--01a1837da67e.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
* [Close the GitHub issues that the wiki now tracks](/issues/close-the-github-issues-that-the-wiki-now-tracks--01a18395b6bd.md)
