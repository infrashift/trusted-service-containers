---
id: "01a1dfc5-71ae-7418-b27c-019501a296e9"
title: "The review summary finds no verdict when the PR has one review leg"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "review"
  - "workflow"
  - "resolved"
created: "2026-11-15T09:13:41-06:00"
timestamp: "2026-11-15T09:13:41-06:00"
description: "download-artifact puts a single review artifact directly in verdicts/, so the verdicts/*/ glob of review.yml found no verdict and failed a signed PASS."
status: "deprecated"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-11-15T09:13:41-06:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/review.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/actions/runs/43727009682"
    title: "Review run 43727009682 for PR #63: one verdict downloaded to verdicts/, the summary found none"
---

# The review summary finds no verdict when the PR has one review leg

## Problem

PR #63 has one mirror leg, `ollama-runtime`. The review job signed the verdict `PASS` with Blocking 0. But the `Review Summary` job wrote "No verdicts were produced" and set `review/cve-policy` to `failure`.

## Context

The `Review Summary` job downloads the artifacts that match `review-*` to `verdicts/`. When two or more artifacts match, `download-artifact` puts each artifact in `verdicts/<artifact name>/`. When one artifact matches, it puts the files directly in `verdicts/`. `merge-multiple: false` does not change this. Review run [43727009682](https://github.com/infrashift/trusted-service-containers/actions/runs/43727009682) shows `Starting download of artifact to: .../verdicts` for the one artifact `review-ollama-runtime`.

The job found the verdicts with the glob `verdicts/*/review-verdict.json`. This glob finds only the second layout, so a pull request with one review leg always got `failure`.

The `Release Summary` job of `release.yml` had the same glob for `release-result.json` and `manifest-result.json`. Its report then said "No images were promoted" for a release of one leg. The release itself was correct. `cleanup-dev.yml` read the pull request number with the same glob, and then used its fallbacks.

## Acceptance criteria

- [x] The review summary finds the verdict for zero, one and many artifacts.
- [x] `review/cve-policy` is not `success` when there is no verdict, or when a verdict is not `PASS`.
- [x] The release summary finds the results for zero, one and many artifacts.
- [x] A lint rule stops a `dir/*/file.json` glob in a workflow.

## Resolution

* `review.yml`, `release.yml` and `cleanup-dev.yml` find the files with `find <dir> -maxdepth 2 -type f -name <file>`. Depth 1 is the layout for one artifact. Depth 2 is the layout for many artifacts. The search does not go deeper.
* `scripts/test-artifact-summaries.sh` takes the `Build the report` and `Resolve review/cve-policy` steps from `review.yml`, and the `Report` step from `release.yml`. It runs them on fixture directories with a stub `gh`. The cases are: no download, an empty download, one `PASS`, one `FAIL`, one `observe` leg, three `PASS` in their own directories, many with one `FAIL`, and a verdict that is too deep. `make -f Ops.mk test-scripts` and `.github/workflows/pr-gate.yml` run it.
* Check 12 of `scripts/lint-workflows.sh` stops a `dir/*/file.json` glob in a workflow.
* Deliberate breaks made the test fail: the old glob in `review.yml` (case "one"), the old glob in `release.yml` (case "release one"), a summary that ignores a `FAIL` (case "onefail"), a summary that reports `success` with no verdict (case "zero"), and a `find` with no depth limit (case "deep").

`review.yml` runs on `workflow_run`, so GitHub uses the file on `main`. A re-run of an old review run uses the old file. PR #63 gets the fix only from a new `CI Build & Audit` run after the fix merges.

## Related

* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [PR Review Gate workflow](/supply-chain/pr-review-gate-workflow--01a18383d6d2.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
