---
id: "01a1dbd5-3dd3-7d66-8e24-b802e268dc4e"
title: "The Chit pin has 9 Critical and 24 fixable High Go module findings"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "chit"
  - "cve"
created: "2026-11-14T14:52:27-06:00"
timestamp: "2026-11-14T14:52:46-06:00"
description: "On 2026-11-14, the pinned Chit commit failed both local grype gates; Chit dependency bumps in x/crypto, x/net, kin-openapi and compress clear them."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-11-14T14:52:46-06:00"
---

# The Chit pin has 9 Critical and 24 fixable High Go module findings

## Problem

The pinned Chit commit `50fdba3709fa` carries 9 Critical and 24 High findings in Go modules. Each finding has a fix. Thus both scans of step 6 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md) fail, and the PDP sends each Chit leg to `quarantine/`.

## Context

On 2026-11-14, we built `Containerfiles/chit.Containerfile` for amd64 and scanned the local image with grype. The grype database was built on 2026-11-14. The counts are matches. A finding in a module that both binaries link counts two times.

| Severity | Matches | With a fix | Distinct advisories |
|---|---|---|---|
| Critical | 9 | 9 | 8 |
| High | 24 | 24 | 18 |
| Medium | 30 | 25 | |
| Low | 10 | 1 | |

* `grype <image> --fail-on critical` exited 2.
* `grype <image> --only-fixed --fail-on high` exited 2.

The findings are in these modules:

* `golang.org/x/crypto` v0.51.0, in `chitd`: 7 Critical and 5 High. The Criticals have the fix in v0.52.0.
* `golang.org/x/net` v0.55.0, in both binaries: Critical `GO-2026-6612` and the Highs `GO-2026-5942`, `GO-2026-6603`, `GO-2026-6610`, `GO-2026-6611`, `GO-2026-6617` and `GO-2026-6860`.
* `github.com/getkin/kin-openapi` v0.144.0, in `chitd`: 5 High.
* `github.com/klauspost/compress` v1.18.2, in `chitd`: 2 High.

No finding is in `stdlib`. Thus the `go1.26` toolchain pin is not the cause. A dependency bump in Chit clears all of them.

## Acceptance criteria

- [ ] Chit bumps these modules, and `versions.json` pins the new commit and its pseudo-version `ref`.
- [ ] A local scan of the new pin passes both grype commands.
- [ ] The review comment of the image pull request shows Blocking 0 for both arches.

## Related

* [chit](/images/chit--01a1dbd53dc3.md)
* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)

## Update 2026-11-14
Chit PR #1 updated the vulnerable modules and set `toolchain go1.26.11`. The pin moved to its merge commit `033e4e928f4b` (`v0.0.0-20261114214224-033e4e928f4b`). A local image of that source, on ubi9-micro, passed both grype gates. The CI review of this pull request scans the image again. Close this issue when the review shows zero blocking findings.
