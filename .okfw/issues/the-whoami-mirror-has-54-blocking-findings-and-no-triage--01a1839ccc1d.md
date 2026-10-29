---
id: "01a1839c-cc1d-7da6-96f4-08bf357b0b80"
title: "The whoami mirror has 54 blocking findings and no triage"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "whoami"
  - "cve"
created: "2026-10-28T12:44:13-05:00"
timestamp: "2026-10-28T12:48:18-05:00"
description: "On 2026-10-28 whoami had 54 blocking Go findings, no waiver and no triage record, so it stays in quarantine under observe."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:48:18-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39 review comment (2026-10-28)"
---

# The whoami mirror has 54 blocking findings and no triage

## Problem

The whoami mirror had 54 blocking findings on 2026-10-28, and no issue tracked them. `.github/pdp/exceptions.yaml` has no whoami waiver. The image stays in `quarantine/`.

## Context

* On 2026-10-28, the review comment on PR #39 gave `whoami-runtime` on `linux-amd64`, `linux-arm` and `linux-arm64`: verdict `PASS (observe)`, namespace `quarantine`, Blocking 54, Waived 0, Recorded 0. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).
* The 54 findings are 18 for each platform: 2 `CVE_CRITICAL` and 16 `CVE_HIGH_FIXABLE`.
* The packages are `stdlib`, `golang.org/x/net` and `google.golang.org/grpc`. The Critical is `GO-2026-6612`, in `stdlib` and in `golang.org/x/net`. The review comment marks each finding as fixed upstream.
* `versions.json` gives whoami the enforcement `observe` and the trust class `none`. Its `reason` says that whoami stays in `observe` until the day-one CVE triage is in `.github/pdp/exceptions.yaml`. It also says to expect Go standard-library findings from the toolchain of the vendor.
* Commit `0229f14` added whoami. The `updated` value in `versions.json` is 2026-09-30.
* On 2026-10-28, the body of GH #24 (the upstream drift report) did not name whoami.

## Acceptance criteria

- [ ] A review of the newest whoami release on the track gives the blocking findings by package.
- [ ] A new pin clears each blocking finding, or a waiver with an owner, an expiry and a justification covers it.
- [ ] Or: this issue records that `quarantine/` is the intended state for whoami.

## Analysis

* All the findings are in the Go binary that the vendor built. Only a new whoami release can remove the `stdlib` findings, because we do not rebuild a mirror.
* An `observe` leg with blocking findings gets a green `review/cve-policy`. Thus the check does not show these findings. See [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md).

## Related

* [whoami](/images/whoami--01a183832d61.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [The mssql image has 60 blocking findings and no triage](/issues/the-mssql-image-has-60-blocking-findings-and-no-triage--01a1838a1626.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
