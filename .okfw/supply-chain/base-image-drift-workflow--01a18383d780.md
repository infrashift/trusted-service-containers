---
id: "01a18383-d780-7f33-a8da-f28d99e2fe14"
title: "Base Image Drift workflow"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "drift"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The drift-base.yml workflow compares the base pins with the sibling repo each day, pushes a proposal branch and updates one tracking issue."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/drift-base.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-base.sh"
    title: "scripts/drift-base.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/propose-drift.sh"
    title: "scripts/propose-drift.sh"
---

# Base Image Drift workflow

The `Base Image Drift` workflow (`.github/workflows/drift-base.yml`) checks each day whether the sibling repository `infrashift/trusted-base-images` published a newer base. If so, it changes the pins, pushes a proposal branch, and updates one tracking issue.

## Trigger and actor

| Item | Value |
|---|---|
| Trigger | `schedule` at 06:17 UTC each day, and `workflow_dispatch` |
| Environment | None. The base packages are readable without a credential. |
| Job permissions | `contents: write` (push the branch), `issues: write` (the tracking issue) |
| Concurrency | One run at a time. A new run does not cancel the old one. |

This repository polls the sibling on a schedule. A push from the sibling with `repository_dispatch` would be faster, but it needs a cross-repository write token in the sibling. That is a standing credential, and the three-actor key isolation exists to prevent one.

## What drift-base.sh does

1. Read each base in the `bases` map of `versions.json`.
2. For each architecture, resolve the per-architecture child digest of `:latest` with `regctl manifest head --platform`.
3. If the digest is not equal to the pin, write the new digest into `versions.json`.
4. If a base changed, set the `updated` date of every base.
5. Write a report. It says that the merge rebuilds every build-track image.

The script pins the per-architecture child, not the index. An index pin would rebuild every image when any one architecture changed, and would not show which one moved.

## What propose-drift.sh does

1. If nothing changed and no alarm exists, close the open tracking issue with a comment, and stop.
2. If `versions.json` changed, commit it on the branch `automation/base-drift` and force-push the branch. One open proposal exists at a time.
3. Create or update one tracking issue with the label `base-drift`. The issue gives a link to open the pull request.

`GITHUB_TOKEN` cannot open a pull request in this repository. The setting that would allow it would also let a workflow satisfy a required approval. Also, a commit by `GITHUB_TOKEN` does not start other workflows. Thus a human must open the pull request, and that pull request runs the build and the review.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [Re-pin a base image](/operations/re-pin-a-base-image--01a18383da79.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [The ubi9-micro base pins were behind the sibling repository on 2026-10-14](/issues/the-ubi9-micro-base-pins-were-behind-the-sibling-repository-on-2026-10-14--01a1838a1439.md)
* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md)
