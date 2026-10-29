---
id: "01a18383-d75b-7305-ae28-b5a2418f0788"
title: "Cleanup Dev Images workflow"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "cleanup"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "How cleanup-dev.yml deletes the development/ image versions of one PR after its release, and why a manual run is a dry run by default."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/cleanup-dev.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/cleanup-dev.sh"
    title: "scripts/cleanup-dev.sh"
---

# Cleanup Dev Images workflow

The `Cleanup Dev Images` workflow (`.github/workflows/cleanup-dev.yml`) deletes the `development/` image versions that one pull request made. It runs after a successful release, or by hand. It never touches `trusted/` or `quarantine/`.

## Trigger and actor

| Item | Value |
|---|---|
| Trigger | `workflow_run` of `Release Images` (success only), or `workflow_dispatch` |
| Inputs of a manual run | `pr_number` (required) and `dry_run` (default `true`) |
| Environment | None |
| Job permissions | `contents: read`, `packages: write`, `actions: read` |

## What it does

1. Find the pull request number. A manual run uses the input. An automatic run reads the `pullRequest` field of the release result, then the event, then the run API.
2. If the number is not numeric, write a warning and stop.
3. Run `scripts/cleanup-dev.sh`.
4. Write the log to the step summary.

## What cleanup-dev.sh deletes

The script deletes single package versions, never a full package. A full delete would also remove the in-progress versions of other pull requests.

* The script deletes a version only when every tag on it starts with `pr-<number>-`.
* A version that has one tag of this pull request and another tag is shared. The script reports it and keeps it.
* When `DRY_RUN=1`, the script lists the versions and deletes nothing.

A manual run is a dry run by default, so the operator sees the list first. The automatic run after a release deletes.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md)
* [Clean the development namespace](/operations/clean-the-development-namespace--01a18383db39.md)
