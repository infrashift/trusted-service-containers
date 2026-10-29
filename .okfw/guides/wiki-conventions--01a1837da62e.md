---
id: "01a1837d-a62e-7e42-931d-8b0b08dca51d"
title: "Wiki conventions"
type: "guide"
tags:
  - "guide"
  - "okfw"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "The structure rules for the wiki: disclosure levels, bundles, types, tags, pointers, trust and lifecycle."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Wiki conventions

This concept gives the rules for the structure of the wiki. Read it before you add or change a concept.

## Disclosure levels

The wiki shows a small amount first. The reader opens more only when necessary.

| Level | What the reader reads | When |
|---|---|---|
| 0 | The okfw block in `CLAUDE.md`, the root `index.md` and the [wiki map](/wiki-map--01a1837da4d8.md) | Always first |
| 1 | The `index.md` and the overview of one bundle | To choose concepts |
| 2 | One concept | When its description shows that it is relevant |
| 3 | The `resource` and `sources` of a concept, and the repository files | Only when the concept is not sufficient |

To make this work, obey these rules:

1. Give each concept a `description` of one sentence. The `index.md` listings show it.
2. Put one idea in one concept. If a concept has two ideas, divide it.
3. Put the most important fact in the first paragraph.
4. Link each concept to one or more other concepts.
5. Link each concept from the overview of its bundle.

## Bundles

| Bundle | Holds |
|---|---|
| `guides/` | Rules for the wiki and for writing |
| `architecture/` | The parts of the system and how they connect |
| `images/` | One concept for each image in `versions.json` |
| `decisions/` | One ADR concept for each decision |
| `supply-chain/` | Workflows, the PDP, waivers, signing environments and lint rules |
| `findings/` | Measured facts and waivers that have a date |
| `operations/` | Runbooks |
| `issues/` | Problems and tasks |
| `plans/` | Steps for one piece of work |

Each bundle has an overview concept with the tag `hub`.

## Types

Set `type` to one of these values: `map`, `overview`, `guide`, `component`, `image`, `decision`, `finding`, `runbook`, `issue`, `plan`. Issues also have `kind: issue`.

## Tags

* Use lowercase words with hyphens, for example `supply-chain`.
* Use the image name as a tag when a concept is about one image, for example `nats`. Use `ory` and `dapr` for the image groups.
* Use the state tags only for issues and plans. See [Issue workflow](/guides/issue-workflow--01a1837da656.md) and [Plan workflow](/guides/plan-workflow--01a1837da67e.md).

## What the wiki does not hold

The repository files are the source of truth for machine-read data. The wiki explains them and links to them.

1. Do not copy a digest or a commit into the wiki, and do not state which version is pinned now. `versions.json` is the only place a pin lives. Link to it. A dated record (an issue or a finding) can name the version that it is about.
2. Do not copy a waiver. `.github/pdp/exceptions.yaml` is the only place a waiver lives, because the PDP reads it. Give the waiver id, for example `EXC-2026-0012`.
3. Do not quote a private-key header, a JWT or a token prefix. `gitleaks` scans the whole tree, and the PDP denies on a finding.
4. Do not add a `.rego` file. `scripts/check-no-orphan-rego.sh` fails on one anywhere in the tree.

## Links to the repository

Set `resource` and `sources` to GitHub URLs on the `main` branch, for example `https://github.com/infrashift/trusted-service-containers/blob/main/versions.json`. A URL stays correct when a concept moves.

In the body, write a repository path in code font, for example `scripts/review-leg.sh`. Make sure that the path exists.

## Trust and lifecycle

1. When an agent writes a concept, set `generated.by` to the agent, for example `claude-code/opus-5-5`.
2. Set `status` to `draft` until a human reviews the concept.
3. When a human reviews a concept, run `okfw verify <id> --by human:<login>`.
4. After the review, run `okfw set-lifecycle <id> stable`.
5. When a concept has a known end date, run `okfw set-stale-after <id> <datetime>`. A waiver finding goes stale on its `expires` date.
6. When a concept is no longer correct, run `okfw set-lifecycle <id> deprecated`. Do not delete it.

## Custom fields

Put custom metadata under `x:`. The schema rejects all other unknown keys. Examples: `x.github` (a GitHub issue or PR number), `x.waivers` (a list of waiver ids), `x.adr` (an ADR number).

## Commands to use

* Use `okfw create` to add a concept. Do not make the file by hand.
* Use `okfw move` to rename or move a concept. Do not use `mv`.
* Use `okfw delete` to remove a concept. Do not use `rm`.
* Do not edit `index.md` or `log.md`. okfw makes them.
* After you edit a concept by hand, run `make -f Ops.mk check-wiki`.

## Related

* [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md)
* [Terminology](/guides/terminology--01a1837da60b.md)
