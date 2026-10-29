---
id: "01a18383-d80b-7b56-bee0-65e00d8ced53"
title: "Build path filter sync"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "pr-gate"
  - "build"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The BUILD_PATHS regex in pr-gate.yml must cover the paths filter of build.yml, or a pull request waits for a check that never resolves."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/pr-gate.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
    title: "build.yml"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
    title: "scripts/lint-workflows.sh (check 5)"
---

# Build path filter sync

The `BUILD_PATHS` regex in `pr-gate.yml` must match every path in the `paths:` filter of `build.yml`. If it does not, a pull request can wait for a check that never resolves.

## How the two lists work together

* `build.yml` runs only when a changed file matches its `paths:` filter.
* `pr-gate.yml` sets `review/cve-policy` to `pending` when a changed file matches `BUILD_PATHS`. Only the review workflow, which follows the build, resolves it.

If `BUILD_PATHS` matches a file that the `paths:` filter does not match, the status stays `pending` and the build never runs. This occurred for `build.yml` itself: `BUILD_PATHS` listed it, but the `paths:` filter did not. A pull request that changed only `build.yml` waited for a review that never started. The reference repository has a commit that fixes only this mismatch.

## How the lint enforces it

Check 5 of `scripts/lint-workflows.sh` reads the `paths:` list of `build.yml`. It changes each glob into a sample path. For example, it changes `scripts/**` into the sample "scripts/x". Then it tests the sample against `BUILD_PATHS`. If a sample does not match, the lint fails.

The check proves that `BUILD_PATHS` covers the filter. It does not prove the opposite direction.

## The current paths

The `paths:` filter lists `versions.json`, `Containerfiles/**`, `rootfs/**`, `scripts/**`, `tools.lock`, `.github/pdp/**` and the three workflows `build.yml`, `review.yml` and `release.yml`. `BUILD_PATHS` lists the same set as one regex.

WARNING: When you add a path to the `paths:` filter of `build.yml`, add it to `BUILD_PATHS` in the same commit.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [PR Review Gate workflow](/supply-chain/pr-review-gate-workflow--01a18383d6d2.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [Workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md)
