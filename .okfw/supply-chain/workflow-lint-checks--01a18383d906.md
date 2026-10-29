---
id: "01a18383-d906-7191-af56-b1b37087ad09"
title: "Workflow lint checks"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "lint"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The eleven checks in scripts/lint-workflows.sh and the defect that each check prevents."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
    title: "build.yml"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
    title: "CLAUDE.md"
---

# Workflow lint checks

`scripts/lint-workflows.sh` runs eleven checks across the workflow set. Each check prevents a defect that the reference repository had, or a bug that occurred here. Run it with `make -f Ops.mk lint-workflows`.

## The checks

| No. | Check | What it prevents |
|---|---|---|
| 1 | Every `uses:` ends in a 40-hex commit SHA. | An action pinned by a tag that can move. |
| 2 | Every `workflow_run` names a workflow that exists. | A trigger that never fires after a rename. |
| 3 | The matrix injection guard is the same in `build.yml`, `review.yml` and `release.yml`. | A trust boundary without a guard. |
| 4 | Only one commit-status context exists, `review/cve-policy`. `pr-gate.yml` seeds it and `review.yml` resolves it. | A required check that hangs because two files spell it differently. |
| 5 | `BUILD_PATHS` in `pr-gate.yml` covers the `paths:` filter of `build.yml`. | A `pending` status that the build never resolves. |
| 6 | Every workflow has `permissions: {}` at the top. | Default token permissions. |
| 7 | Every job that uses `COSIGN_PRIVATE_KEY` binds an `environment:`. | A job that gets a key without the environment that selects it. |
| 8 | Every `./scripts/` file that a workflow names exists and is executable. | A missing script found only at run time. |
| 9 | No `cosign attest` call passes `--replace`. | Deleted vendor attestations, and an `amd64` SBOM replaced by the `arm64` SBOM. |
| 10 | No file uses `cosign-installer` or `cosign-release:`, and every signing job installs `cosign` with `scripts/install-tools.sh`. | A `cosign` version that differs from `tools.lock`, and `cosign: command not found`. |
| 11 | The `CHANGED` expression in `build.yml` selects the correct images for five fixture cases. | A toolchain or base bump that rebuilds only some images. |

## How the checks avoid false passes

* Checks 9 and 10 exclude `scripts/lint-workflows.sh` itself and comment lines. The script names the forbidden flags, so it would otherwise match itself.
* Check 11 runs the real jq expression from `build.yml` against a fixture. It does not search for text.

## Analysis

Check 3 has a test for an empty build hash (`-z "$H_BUILD"`). That test cannot fire, because `sha256sum` of empty input gives a hash. But an empty extract makes `grep -v` exit 1, so `set -euo pipefail` stops the script with exit 1. The check thus fails closed, but it prints no error message. A test on 2026-10-28 with a file that has no guard gave exit 1 and no output.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Workflow conventions](/supply-chain/workflow-conventions--01a18383d8e0.md)
* [Matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md)
* [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [Ops.mk validate targets](/supply-chain/ops-mk-validate-targets--01a18383d999.md)
* [Check 3 of lint-workflows.sh has a dead empty-hash test](/issues/check-3-of-lint-workflows-sh-has-a-dead-empty-hash-test--01a18395b612.md)
