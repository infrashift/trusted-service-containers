---
id: "01a18383-d737-7db2-8c05-56df7b256e28"
title: "Release Images workflow"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "release"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The release.yml workflow runs on a push to main, finds the reviewed build, and promotes each leg byte-identical to trusted/ or quarantine/."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/release.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-leg.sh"
    title: "scripts/release-leg.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-manifest.sh"
    title: "scripts/release-manifest.sh"
---

# Release Images workflow

The `Release Images` workflow (`.github/workflows/release.yml`) is the release actor. It promotes each reviewed leg from `development/` to `trusted/` or `quarantine/`. It copies the image and never builds it again, so the digest does not change.

## Trigger and actor

| Item | Value |
|---|---|
| Trigger | `push` to `main`, which a merge makes |
| Environment | `Release-Actor`, which only `main` can deploy to |
| Top-level permissions | `permissions: {}` |

The trigger is a push, not `pull_request: closed`. A `pull_request` run has the ref `refs/pull/<n>/merge`. The deployment branch policy of `Release-Actor` allows only `main`, so it rejected every release leg. Do not widen that policy. If it allowed merge refs, any pull request could deploy to the environment that holds the release key.

## Jobs

| Job | What it does |
|---|---|
| `Gate` | Finds the merged pull request and its head commit from the merge commit. It stops if no merged pull request exists. It does the lookup one time only; see [the open issue](/issues/the-release-gate-job-fails-when-github-has-not-yet-linked-the-merge-commit-to-its-pull-request--01a1854e501e.md). |
| `Resolve Build & Review Runs` | Finds the successful build run and the review run that reviewed it. |
| `Load Matrix` | Downloads `build-matrix.json` from the build run and checks it with the [matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md). |
| `Release <leg>` | Runs `scripts/release-leg.sh` for one leg. |
| `Manifest <service>` | Runs `scripts/release-manifest.sh` for one build-track service. |
| `Release Summary` | Writes a summary and comments on the pull request. |

## How it finds the build and the review

1. The job lists the build runs for the head commit.
2. If no build run exists, the pull request changed no image path. The job sets `has_build=false`, and the workflow ends without a release.
3. If a build run is still in progress, the job waits. The limit is 1800 seconds.
4. If no build run succeeded, the job fails.
5. The job then looks for a review run that started after the build ended.
6. It accepts a review run only if a downloaded verdict names this build run in `buildRunId`. The limit is 2700 seconds.

A merge can occur while the build still runs. Thus the job waits. It bounds the search by time, not by a count of runs, so the search cannot miss a real review.

## What release-leg.sh does

1. Read the verdict from the signed review attestation on the image. It does not read a workflow artifact, because a re-run can change an artifact.
2. Select the namespace. `PASS` with namespace `trusted` goes to `trusted/`. All other verdicts go to `quarantine/`.
3. Copy the image with `regctl image copy` and its referrers. Do not use `cosign copy`, because it drops OCI referrers.
4. Make sure that the promoted digest is equal to the `development/` digest.
5. Write a release attestation that records the waived findings, and sign it two times: keyed with no transparency log, then keyless to Rekor.

## Tags

| Namespace | Mirror leg | Build leg |
|---|---|---|
| `trusted/` | upstream tag, tag plus short commit, tag plus date | version plus short commit plus architecture |
| `quarantine/` | tag plus short commit only | version plus short commit plus architecture |

The bare upstream-shaped tag exists only under `trusted/`. To use a quarantined image, a consumer must name the exact commit tag.

## Manifest lists

The `Manifest` job runs only for build-track services. Its matrix excludes mirror legs by structure, because a new manifest list over a mirrored index would replace the signed vendor index. The job makes a manifest list only when every architecture of the service is in `trusted/`. No `:latest` tag exists.

## Related

* [The release Gate job fails when GitHub has not yet linked the merge commit to its pull request](/issues/the-release-gate-job-fails-when-github-has-not-yet-linked-the-merge-commit-to-its-pull-request--01a1854e501e.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [Cleanup Dev Images workflow](/supply-chain/cleanup-dev-images-workflow--01a18383d75b.md)
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md)
* [Matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md)
