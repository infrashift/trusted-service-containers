---
id: "01a1dbce-4e57-7421-b82c-9e1e0af93c65"
title: "The keto-cue pin has a Critical and 13 fixable High Go module findings"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "keto-cue"
  - "cve"
created: "2026-11-14T14:44:53-06:00"
timestamp: "2026-11-14T14:44:59-06:00"
description: "On 2026-11-14, the pinned keto-cue commit failed both local grype gates; an unmerged keto-cue dependency bump is the fix to pin."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-11-14T14:44:59-06:00"
sources:
  - resource: "https://github.com/infrashift/keto-cue/pull/3"
    title: "keto-cue pull request 3"
---

# The keto-cue pin has a Critical and 13 fixable High Go module findings

## Problem

The pinned keto-cue commit `2a6c583e05f5` carries 1 Critical and 13 High findings in Go modules. Each finding has a fix. Thus both scans of step 6 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md) fail, and the PDP sends each keto-cue leg to `quarantine/`.

## Context

On 2026-11-14, we built `Containerfiles/keto-cue.Containerfile` for amd64 and scanned the local image with grype. The grype database was built on 2026-11-14.

| Severity | Count | With a fix |
|---|---|---|
| Critical | 1 | 1 |
| High | 13 | 13 |
| Medium | 25 | 20 |
| Low | 14 | 5 |

* `grype <image> --fail-on critical` exited 2.
* `grype <image> --only-fixed --fail-on high` exited 2.

The findings are in these modules:

* Critical `GO-2026-6612` and the Highs `GO-2026-6603`, `GO-2026-6610`, `GO-2026-6611`, `GO-2026-6617` and `GO-2026-6860`: `golang.org/x/net` v0.56.0. The fix is in v0.60.0 and v0.62.0.
* `GO-2026-6303`, `GO-2026-6354`, `GO-2026-6355`: `golang.org/x/crypto` v0.53.0.
* `GO-2026-6179`, `GO-2026-6180`: `golang.org/x/mod` v0.37.0.
* `GO-2026-6629`: `golang.org/x/text` v0.39.0.
* `GHSA-2v4p-qf9q-27wj`, `GHSA-vp52-pcj8-j9qc`: `google.golang.org/grpc` v1.82.1.

No finding is in `stdlib`. Thus the `go1.26` toolchain pin is not the cause.

keto-cue has an open pull request, number 3, on the branch `fix/deps-vulnerabilities`. Its commit `a52923dc` has the title "fix(deps): bump vulnerable Go dependencies". On 2026-11-14 it was not merged.

The image starts in `observe`, so the pipeline does not fail. But `observe` is not a pass. See [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md).

## Acceptance criteria

- [ ] keto-cue merges its dependency bump, and `versions.json` pins the new commit and its pseudo-version `ref`.
- [ ] A local scan of the new pin passes both grype commands.
- [ ] The review comment of the image pull request shows Blocking 0 for both arches.

## Related

* [keto-cue](/images/keto-cue--01a1dbce4e47.md)
* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)

## Update 2026-11-14
keto-cue PR #3 updated the vulnerable Go modules. The pin moved to the merge commit `b1faf67fb5bf` (`v0.0.0-20261114205939-b1faf67fb5bf`). The CI build and review of the pull request scan the new image. Close this issue when that review shows zero blocking findings.
