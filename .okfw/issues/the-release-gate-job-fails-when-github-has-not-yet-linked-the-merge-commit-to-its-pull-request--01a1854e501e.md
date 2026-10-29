---
id: "01a1854e-501e-7811-b0e8-7109c9daa1f3"
title: "The release Gate job fails when GitHub has not yet linked the merge commit to its pull request"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "release"
  - "workflow"
created: "2026-10-28T20:37:44-05:00"
timestamp: "2026-10-28T20:38:13-05:00"
description: "The Gate job of release.yml looks up the merged pull request once, so a short GitHub API delay after a merge stops the release."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T20:38:13-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/release.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/actions/runs/40801309587"
    title: "Release run 40801309587 for PR #40: attempt 1 failed, attempt 2 passed"
---

# The release Gate job fails when GitHub has not yet linked the merge commit to its pull request

## Problem

The `Gate` job of `.github/workflows/release.yml` can run before GitHub links the merge commit to its pull request. The job then finds no merged pull request, stops with an error, and the release does not occur. The job must wait a short time for GitHub before it fails.

## Context

The `Derive identifiers` step finds the pull request with `gh api repos/<repo>/commits/<merge sha>/pulls`. If the result has no merged pull request, the step stops with `no merged pull request found for <sha>; refusing to release`. This check is correct: a push to `main` without a merged pull request must not release. But the GitHub API does not show a new link immediately.

On 2026-10-29, PR #40 merged at 01:35:11 UTC. Release run [40801309587](https://github.com/infrashift/trusted-service-containers/actions/runs/40801309587) started at 01:35:14 UTC. The step called the API at 01:35:17 UTC and got no merged pull request. A query after the run gave PR #40 with `merged_at` 01:35:11. A re-run of the same run passed and gave `resolved PR #40`.

PR #40 changed no image-affecting paths, so this failure stopped no release. On an image pull request, the same failure stops the promotion of all legs to `trusted/` or `quarantine/` until an operator re-runs the workflow.

This is the first time that the `Gate` job failed for this cause. The earlier failed release runs since the push trigger (PRs #9, #11 and #20) failed in other jobs.

## Acceptance criteria

- [ ] The `Derive identifiers` step tries the API call again for a limited time (for example 5 tries, 10 seconds apart) before it stops.
- [ ] The step still stops with an error when no merged pull request appears in that time. A deliberate break (a push to a test branch with no pull request, or a stub that gives `[]`) shows that it fails.
- [ ] The step retries only for an empty result. It does not retry for an API error, so that a wrong token or a wrong repository stops the job immediately.
- [ ] The [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md) concept describes the wait.

## Analysis

* Do not read the pull request number from the merge commit message. A person can write any text in a commit message, so it is not a fact from GitHub.
* Do not remove the check. It is the guard against a release that no review verdict covers.
* `.github/workflows/release.yml` is in the `paths:` filter of `build.yml`. A change to it builds all images again. Put the fix in the next pull request that changes a build path, or accept one full build.
* Until the fix is in place, do this when the `Gate` job fails with this error: make sure that the pull request shows as merged, then run `gh run rerun <run id> --failed`. The re-run does the API call again.

## Related

* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
* [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
