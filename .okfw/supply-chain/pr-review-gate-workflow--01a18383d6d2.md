---
id: "01a18383-d6d2-7d47-b59b-ccd2622182a3"
title: "PR Review Gate workflow"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "pr-gate"
created: "2026-10-28T12:16:57-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "How pr-gate.yml runs the static checks and the repository half of the PDP on every pull request, and seeds review/cve-policy."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/pr-gate.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/repo-gate.sh"
    title: "scripts/repo-gate.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
    title: "SETUP-ENVIRONMENTS.md §10"
---

# PR Review Gate workflow

The `PR Review Gate` workflow (`.github/workflows/pr-gate.yml`) runs on every pull request to `main`. It has no `paths:` filter, so its checks report on every pull request, also on a pull request that changes only documentation.

## Trigger and actor

| Item | Value |
|---|---|
| Trigger | `pull_request` to `main`, with no path filter |
| Environment | None. No job holds a signing key. |
| Top-level permissions | `permissions: {}` |
| Concurrency | One run for each pull request. A new push cancels the old run. |

## Jobs

| Job | Permissions | What it does |
|---|---|---|
| `Seed Review Status` | `statuses: write`, `pull-requests: read` | Sets the `review/cve-policy` commit status. |
| `Repo Gate` | `contents: read` | Runs the static checks and the repository half of the PDP. |

## Seed Review Status

The [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md) runs on `workflow_run`. Thus it cannot report a check on the pull request itself. This job sets the start value of `review/cve-policy`:

1. The job reads the changed files with `gh pr diff`.
2. It compares them with the `BUILD_PATHS` regex. See [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md).
3. If an image path changed, it sets `review/cve-policy` to `pending`. The review workflow resolves it later.
4. If no image path changed, it sets `review/cve-policy` to `success`.

The job does not run on a pull request from a fork. A fork gets a read-only token that cannot write a commit status, and it cannot reach `dhi.io` or push to GHCR.

## Repo Gate

The checkout uses `fetch-depth: 0`, because `gitleaks` scans the full history. The job runs these steps in sequence:

1. Install the pinned `opa` and `gitleaks` with `scripts/install-tools.sh`.
2. Make sure that `.gitleaks.toml` has 64 bytes or more and sets `useDefault = true`.
3. Validate `versions.json` against the JSON Schema with `scripts/validate-schema.py`.
4. Run `scripts/check-no-orphan-rego.sh`. Only one policy file can exist.
5. Run `scripts/lint-workflows.sh`. See [Workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md).
6. Run `scripts/lint-containerfiles.sh`. See [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md).
7. Run `scripts/lint-skills.sh`. Each documented repository path must exist.
8. Run `shellcheck -S warning` on `scripts/*.sh`.
9. Run `scripts/test-propose-drift.sh`, `scripts/test-drift-upstream.sh` and `scripts/test-release-gate.sh` against fixtures and stubs.
10. Run `opa check --strict`, `opa fmt --list` and `opa test`. The coverage floor is 85%.
11. Run `scripts/repo-gate.sh`. It evaluates `data.tsc.pdp.repo_decision` and writes `repo-decision.json`. See [Repo gate and secret scanning](/supply-chain/repo-gate-and-secret-scanning--01a18383d973.md).
12. Write a summary of the decision and upload `repo-decision.json`.

## Required checks

`SETUP-ENVIRONMENTS.md` §10 lists three required contexts on the `main` ruleset: `review/cve-policy`, `build/gate` and `Repo Gate`.

On 2026-10-28, `gh api repos/infrashift/trusted-service-containers/rulesets/21323251` showed only one required context: `Repo Gate`.

## Analysis

* If the ruleset requires only `Repo Gate`, a red `review/cve-policy` does not stop a merge. The review comment is then the only signal. See [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md).
* If `build/gate` becomes required, a documentation-only pull request waits for it, because `build.yml` does not run. This workflow does not seed `build/gate`.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md)
* [Repo gate and secret scanning](/supply-chain/repo-gate-and-secret-scanning--01a18383d973.md)
* [Workflow conventions](/supply-chain/workflow-conventions--01a18383d8e0.md)
* [Run the checks locally](/operations/run-the-checks-locally--01a18383da08.md)
* [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md)
