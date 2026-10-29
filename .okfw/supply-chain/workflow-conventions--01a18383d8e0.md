---
id: "01a18383-d8e0-7a50-baf1-5da52bbb90ef"
title: "Workflow conventions"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "conventions"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The rules for every workflow: actions pinned by SHA, tools from tools.lock, empty top-level permissions, untrusted values through env, and the required checks."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
    title: "CLAUDE.md: workflow conventions"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/tools.lock"
    title: "tools.lock"
---

# Workflow conventions

These rules apply to every workflow in `.github/workflows/`. `scripts/lint-workflows.sh` enforces most of them. It runs in `make -f Ops.mk validate` and in the `Repo Gate` job.

## The workflows

| File | Name | Trigger |
|---|---|---|
| `pr-gate.yml` | PR Review Gate | `pull_request`, no path filter |
| `build.yml` | CI Build & Audit | `pull_request`, with a path filter |
| `review.yml` | Review Attestations | `workflow_run` of the build |
| `release.yml` | Release Images | `push` to `main` |
| `cleanup-dev.yml` | Cleanup Dev Images | `workflow_run` of the release, and `workflow_dispatch` |
| `drift-base.yml` | Base Image Drift | `schedule` and `workflow_dispatch` |
| `drift-upstream.yml` | Upstream Drift | `schedule` and `workflow_dispatch` |

One `build.yml` serves both tracks. See [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md) for the reason.

## Rules for every workflow

1. Pin every `uses:` to a 40-character commit SHA. Put the version in a comment.
2. Pin every tool version in `tools.lock`. Install tools only with `scripts/install-tools.sh`. Never install from an unpinned `latest` into a job that holds a signing key.
3. Install `cosign` only with `scripts/install-tools.sh`. Do not use the `cosign-installer` action.
4. Set `permissions: {}` at the top. Give each job only the permissions that it needs. Give `id-token: write` only to a job that needs it.
5. Pass an untrusted value to the shell through `env:`, and use it as `"$VAR"`. Do not interpolate it into the script. Pass it to `jq` with `--arg`.
6. Start each `run:` script with `set -euo pipefail`. Set `fail-fast: false` on each matrix.
7. Bind an `environment:` to every job that uses `COSIGN_PRIVATE_KEY`.
8. Never pass `--replace` to `cosign attest`. Here it would delete the vendor attestations that the mirror track keeps, and replace the `amd64` SBOM when it writes the `arm64` SBOM.

## Two cross-file rules

* The [matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md) is byte-identical in `build.yml`, `review.yml` and `release.yml`.
* The `BUILD_PATHS` regex in `pr-gate.yml` covers the `paths:` filter of `build.yml`. See [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md).

## Required checks

`pr-gate.yml` has no path filter, by design. A workflow with a path filter does not run on some pull requests, and its contexts never appear. A required context that never appears blocks a documentation-only pull request for all time.

`pr-gate.yml` seeds `review/cve-policy` as `pending`, and `review.yml` resolves it. The context string is the same in both files and in the ruleset.

Do not make one matrix leg a required check. Use the aggregate `build/gate` job.

## GITHUB_TOKEN cannot open pull requests

The setting "Allow GitHub Actions to create and approve pull requests" stays disabled. The same setting would let a workflow satisfy a required approval. `GITHUB_TOKEN` can create and edit issues, so the drift workflows report work in an issue. A commit by `GITHUB_TOKEN` does not start other workflows. Thus a human must open the drift pull request.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md)
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md)
* [Two jq traps](/supply-chain/two-jq-traps--01a18383d94f.md)
