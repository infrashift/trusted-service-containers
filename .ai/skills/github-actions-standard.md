# Workflow conventions

`scripts/lint-workflows.sh` enforces most of this; it runs in `make validate`
and in `pr-gate.yml`.

## The workflows

| file | name | trigger |
|---|---|---|
| `pr-gate.yml` | PR Review Gate | `pull_request`, unfiltered |
| `build.yml` | CI Build & Audit | `pull_request` (paths) |
| `review.yml` | Review Attestations | `workflow_run` |
| `release.yml` | Release Images | `pull_request: closed` |
| `cleanup-dev.yml` | Cleanup Dev Images | `workflow_run` + dispatch |
| `drift-base.yml` / `drift-upstream.yml` | drift | schedule + dispatch |

**One `build.yml` for both tracks**, not two. Two producers would race to write
the same commit status, and `release.yml`'s clean no-op only works with a single
path-filtered producer.

## Non-negotiables

- Every `uses:` pinned to a 40-char SHA. Tools pinned in `tools.lock` — never
  install from an unpinned `latest` into a job holding a signing key.
- `permissions: {}` at the top; least privilege per job; `id-token: write` only
  where needed.
- Untrusted values reach shell via `env:` as `"$VAR"`, never interpolated.
  jq takes them via `--arg`.
- `set -euo pipefail`, `fail-fast: false`.

## Two invariants the lint checks

- The matrix injection guard is **byte-identical** in `build.yml`, `review.yml`
  and `release.yml`. `build-matrix.json` crosses that trust boundary three
  times.
- `pr-gate.yml`'s `BUILD_PATHS` regex covers `build.yml`'s `paths:` filter.

## Required checks

`pr-gate.yml` is deliberately **unfiltered**: a path-filtered workflow does not
run, its contexts never appear, and a docs-only PR hangs forever. It seeds
`review/cve-policy` as pending; `review.yml` resolves it.

**Never make individual matrix legs required checks.** Job names change with the
matrix and a context that stops reporting blocks every PR. Use the aggregate
`build/gate` job.

## GITHUB_TOKEN cannot open PRs

By design — the same setting would let a workflow satisfy a required approval.
It *can* create and edit issues, which is how the drift workflows surface work.
A token-authored commit also does not trigger downstream workflows, so a human
opening the PR is load-bearing, not a formality.
