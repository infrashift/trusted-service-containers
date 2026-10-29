---
id: "01a18382-f432-7ecc-80d2-5ee1d48c1b38"
title: "Repository layout"
type: "component"
tags:
  - "architecture"
  - "layout"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The top-level directories and files of the repository and what each one holds."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/README.md"
---

# Repository layout

This concept lists the top-level parts of the repository. All pipeline logic is in `scripts/`. Thus the workflows stay small.

| Path | Holds |
|---|---|
| `versions.json` | The sovereign source of truth: each pin and each track. |
| `schemas/` | The JSON Schema for `versions.json`. |
| `Containerfiles/` | One Containerfile for each build-track image. |
| `rootfs/` | Service configuration that we put into an image, for example the NATS configuration. |
| `.github/pdp/` | The one policy, its tests, the waivers, the vendor keyrings and the public keys. |
| `.github/workflows/` | The seven workflows. |
| `scripts/` | All pipeline logic. |
| `docs/build-track/` | A pointer to the wiki. Its content moved to [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md). |
| `.ai/skills/` | Rule cards. Their content moved into this wiki. See [ADR-007: The wiki is the tracker of record](/decisions/adr-007-the-wiki-is-the-tracker-of-record--01a18382f505.md). |
| `.okfw/` | This wiki: issues, plans, findings, decisions and architecture. |
| `tools.lock` | The pinned version of each tool. |
| `Ops.mk` | Local targets, for example `validate` and `verify-pins`. |
| `SETUP-ENVIRONMENTS.md` | The one-time setup runbook. |

## The seven workflows

| Workflow | Trigger | Does |
|---|---|---|
| `pr-gate.yml` | PR | Repository gate: secrets, schema, policy tests, lints |
| `build.yml` | PR that changes a path in its `paths:` filter | Mirror legs and build legs, signed evidence |
| `review.yml` | `workflow_run` on "CI Build & Audit" (`build.yml`), when it completes | Independent checks, policy, signed verdict |
| `release.yml` | Push to `main` | Promotion and dual signing |
| `cleanup-dev.yml` | `workflow_run` on "Release Images" (`release.yml`), when it completes | Removes the `development/` images of the PR |
| `drift-base.yml` | Daily schedule | Finds drift of our UBI base |
| `drift-upstream.yml` | Daily schedule | Finds drift of each pinned upstream |

Before you propose a change, run `make -f Ops.mk validate`.

## Related

* [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md)
* [The three actors](/architecture/the-three-actors--01a18382f33a.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md): the workflows in detail.
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
