---
id: "01a1838a-13e9-7398-b0a4-2da3933dd5e7"
title: "The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "resolved"
  - "toolchain"
  - "cve"
  - "prometheus-nats-exporter"
created: "2026-10-28T12:23:46-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "Go 1.26.6 carried 8 stdlib findings into every Go build; PR #31 moved the toolchain to 1.26.9 on 2026-10-13. GitHub still shows it open."
x:
  github: 30
status: "deprecated"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/30"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/31"
    title: "PR #31"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/29"
    title: "PR #29 review comment"
---

# The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build

## Problem

The `go1.26` toolchain pin had the Go patch release 1.26.6. That compiler put 8 Go standard library findings into every image that it built. One of them, `GO-2026-6612`, is Critical. The other seven (`GO-2026-6603`, `-6605`, `-6607`, `-6608`, `-6610`, `-6611`, `-6613`) are High and have a fix.

## Context

* The review of PR #29 (`prometheus-nats-exporter` `v0.20.2`) reported these findings on both legs, with `blocking=8`. See [Go 1.26.6 put 8 stdlib findings into prometheus-nats-exporter on 2026-10-13](/findings/go-1-26-6-put-8-stdlib-findings-into-prometheus-nats-exporter-on-2026-10-13--01a1838a6f27.md).
* The image had the enforcement `observe`, and the legs had blocking findings. Thus the review check was green, and the image went to `quarantine/` only.
* A `stdlib` finding on a build leg comes from our compiler, not from the source or the base. Every `go1.26` image built on 1.26.6 had the same set.
* On 2026-10-13, the rolling tag `golang:1.26-trixie` resolved to 1.26.9.
* No workflow watched the toolchain pins before this issue.

## Acceptance criteria

- [x] The `go1.26` toolchain digests (amd64 and arm64) point at 1.26.9 or later.
- [x] The pipeline builds all images that use the toolchain again.
- [x] `prometheus-nats-exporter` gets a `PASS` verdict and goes to `trusted/`.

## Resolution

Resolved in the repository on 2026-10-13. GH #30 was closed on 2026-10-29, with a link to this issue.

* PR #31 (merged 2026-10-13):
  * `76d0c0f`: the toolchain moved from 1.26.6 to 1.26.9. This cleared `GO-2026-6603` to `GO-2026-6613` in every Go build.
  * `b107894`: the drift job watches the toolchain pins, and `verify-build-pins` checks them.
  * `0c32a9f`: a toolchain, base or source change rebuilds every image that uses it.
  * `3a294a3`: an `observe` leg with blocking findings no longer shows as a plain `PASS`.
* PR #32 (merged 2026-10-14), `5c636c6`: `prometheus-nats-exporter` moved to `enforce` after a clean review.
* PR #35 (merged 2026-10-28) moved the toolchain to 1.26.10.
* On 2026-10-28, the review of PR #39 gave `PASS` and `trusted` for both `prometheus-nats-exporter` legs. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

The consumer in another repository was to switch from the quarantined digest. This repository cannot show if that occurred.

## Related

* [Go 1.26.6 put 8 stdlib findings into prometheus-nats-exporter on 2026-10-13](/findings/go-1-26-6-put-8-stdlib-findings-into-prometheus-nats-exporter-on-2026-10-13--01a1838a6f27.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [nats](/images/nats--01a183832e00.md)
* [prometheus](/images/prometheus--01a183832e94.md)
* [loki](/images/loki--01a183832eba.md)
* [seaweedfs](/images/seaweedfs--01a183832ee2.md)
* [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md)
* [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md)
* [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md)
