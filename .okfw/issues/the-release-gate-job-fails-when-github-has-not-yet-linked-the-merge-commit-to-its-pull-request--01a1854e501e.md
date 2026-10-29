---
id: "01a1854e-501e-7811-b0e8-7109c9daa1f3"
title: "The release Gate job fails when GitHub has not yet linked the merge commit to its pull request"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "release"
  - "workflow"
  - "resolved"
created: "2026-10-28T20:37:44-05:00"
timestamp: "2026-10-28T20:56:14-05:00"
description: "The Gate job of release.yml looks up the merged pull request once, so a short GitHub API delay after a merge stops the release."
status: "deprecated"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T20:56:14-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/release.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/actions/runs/40801309587"
    title: "Release run 40801309587 for PR #40: attempt 1 failed, attempt 2 passed"
  - resource: "https://github.com/infrashift/trusted-service-containers/actions/runs/40801760051"
    title: "Release run 40801760051 for PR #41: attempt 1 failed, the re-run of the failed job passed"
---

# The release Gate job fails when GitHub has not yet linked the merge commit to its pull request

## Problem

The `Gate` job of `.github/workflows/release.yml` can run before GitHub links the merge commit to its pull request. The job then finds no merged pull request, stops with an error, and the release does not occur. The job must wait a short time for GitHub before it fails.

## Context

The `Derive identifiers` step finds the pull request with `gh api repos/<repo>/commits/<merge sha>/pulls`. If the result has no merged pull request, the step stops with `no merged pull request found for <sha>; refusing to release`. This check is correct: a push to `main` without a merged pull request must not release. But the GitHub API does not show a new link immediately.

On 2026-10-29, PR #40 merged at 01:35:11 UTC. Release run [40801309587](https://github.com/infrashift/trusted-service-containers/actions/runs/40801309587) started at 01:35:14 UTC. The step called the API at 01:35:17 UTC and got no merged pull request. A query after the run gave PR #40 with `merged_at` 01:35:11. A re-run of the same run passed and gave `resolved PR #40`.

On 2026-10-29, PR #41 merged at 01:39:47 UTC. Release run [40801760051](https://github.com/infrashift/trusted-service-containers/actions/runs/40801760051) started at 01:39:50 UTC. The step called the API at 01:39:53 UTC and stopped with the same error. After the API showed PR #41 with `merged_at` 01:39:47, `gh run rerun 40801760051 --failed` passed and gave `resolved PR #41`.

PR #40 and PR #41 changed no image-affecting paths, so these failures stopped no release. On an image pull request, the same failure stops the promotion of all legs to `trusted/` or `quarantine/` until an operator re-runs the workflow.

The `Gate` job failed for this cause on two merges in sequence: PR #40 and PR #41. In both runs, the API call occurred 6 seconds or less after the merge. The four merges before them on 2026-10-28 (PRs #35, #36, #38 and #39) did not fail. The earlier failed release runs since the push trigger (PRs #9, #11 and #20) failed in other jobs.

## Acceptance criteria

- [x] The `Derive identifiers` step tries the API call again for a limited time (for example 5 tries, 10 seconds apart) before it stops.
- [x] The step still stops with an error when no merged pull request appears in that time. A deliberate break (a push to a test branch with no pull request, or a stub that gives `[]`) shows that it fails.
- [x] The step retries only for an empty result. It does not retry for an API error, so that a wrong token or a wrong repository stops the job immediately.
- [x] The [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md) concept describes the wait.

## Analysis

* Two failures in two merges show that the delay is frequent. Until the fix is in place, an operator must examine the release run after each merge. The maintainer must decide: do the fix soon with one full build, or wait for the next workflow change.
* Do not read the pull request number from the merge commit message. A person can write any text in a commit message, so it is not a fact from GitHub.
* Do not remove the check. It is the guard against a release that no review verdict covers.
* `.github/workflows/release.yml` is in the `paths:` filter of `build.yml`. A change to it builds all images again. Put the fix in the next pull request that changes a build path, or accept one full build.
* Until the fix is in place, do this when the `Gate` job fails with this error: make sure that the pull request shows as merged, then run `gh run rerun <run id> --failed`. The re-run does the API call again.

## Resolution

PR #44 fixed this issue on 2026-10-29. The maintainer decided to accept one full image build for the fix.

* The `Derive identifiers` step in `.github/workflows/release.yml` now does the lookup up to `LOOKUP_ATTEMPTS` times (6), with `LOOKUP_DELAY_SECONDS` (15) between the attempts. The longest wait is 75 seconds.
* The step retries only when the result has no merged pull request. An API error stops the step at the first call.
* After the last attempt, the step stops with `no merged pull request found for <sha> after 6 attempts; refusing to release`.
* `scripts/test-release-gate.sh` takes the step from `release.yml` and runs it with a stub `gh`. It has six cases: a link on the first call, a link on the third call, no pull request, a pull request that is not merged, an API error, and a bad head commit. `make -f Ops.mk test-scripts` and `.github/workflows/pr-gate.yml` run it.
* Four deliberate breaks made the test fail: the old step with one lookup, a retry after an API error, a match on a pull request that is not merged, and `LOOKUP_ATTEMPTS` set to 1.

The release run of the PR #44 merge is the first check on GitHub. If the link is late, its log shows `retrying in 15s` before `resolved PR #44`.

## Related

* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
* [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
