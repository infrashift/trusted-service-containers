---
id: "01a1837d-a4d8-7813-a3d0-5db53c9090c4"
title: "Wiki map"
type: "map"
tags:
  - "hub"
  - "map"
created: "2026-10-28T12:10:11-05:00"
timestamp: "2026-10-28T12:10:11-05:00"
description: "Start here: what this wiki holds, the bundles, and the commands for common questions."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:11-05:00"
---

# Wiki map

This wiki holds the knowledge about the trusted service containers that the code does not show: reasons, findings, issues, plans and runbooks.

The project publishes service container images whose provenance a person who does not trust us can verify. The mirror track copies vendor images by digest. The build track builds Go services from a pinned source commit onto our own UBI base. Three actors build, review and release each image. One policy makes the decision.

## Start here

1. Read this map. Choose the bundle for your question.
2. Read the overview of that bundle.
3. Open only the concepts whose description matches your question.
4. Follow `resource` and `sources` to the repository only when necessary.

## Bundles

| Bundle | Use it for |
|---|---|
| [guides/](/guides/guides-overview--01a1837da4f2.md) | Read first. Writing rules, words, and how to track issues and plans. |
| [architecture/](/architecture/architecture-overview--01a1837da50c.md) | The parts of the system and how they connect. |
| [images/](/images/images-overview--01a1837da526.md) | One concept for each image in `versions.json`. |
| [decisions/](/decisions/decisions-overview--01a1837da541.md) | The reasons for the design. One ADR for each decision. |
| [supply-chain/](/supply-chain/supply-chain-overview--01a1837da55d.md) | Workflows, the PDP, waivers, signing environments and lint rules. |
| [findings/](/findings/findings-overview--01a1837da578.md) | Dated measurements and waivers. |
| [operations/](/operations/operations-overview--01a1837da594.md) | Runbooks for common changes and checks. |
| [issues/](/issues/issues-overview--01a1837da5b0.md) | Open and resolved problems and tasks. |
| [plans/](/plans/plans-overview--01a1837da5cd.md) | Multi-step work and its state. |

## Common questions

| Question | Command |
|---|---|
| What is open? | `okfw search --kind issue --tag open` |
| What is open for one image? | `okfw search --kind issue --tag open --tag <image>` |
| What work is in progress? | `okfw search --type plan --tag active` |
| Which waivers or facts are out of date? | `okfw search --stale` |
| What is not reviewed? | `okfw search --status draft` |
| What links to a concept? | `okfw backlinks <id>` |
| Is the wiki valid? | `make -f Ops.mk check-wiki` |
