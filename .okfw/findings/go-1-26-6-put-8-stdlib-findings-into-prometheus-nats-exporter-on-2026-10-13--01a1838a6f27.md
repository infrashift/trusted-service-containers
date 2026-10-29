---
id: "01a1838a-6f27-748a-b847-0d5a391bf5bc"
title: "Go 1.26.6 put 8 stdlib findings into prometheus-nats-exporter on 2026-10-13"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "toolchain"
  - "prometheus-nats-exporter"
created: "2026-10-28T12:24:10-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "The review of PR #29 found 8 Go stdlib findings, one Critical, on both prometheus-nats-exporter legs; the go1.26 toolchain pin caused them."
x:
  github:
    - 30
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/pull/29"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/30"
    title: "GH #30"
---

# Go 1.26.6 put 8 stdlib findings into prometheus-nats-exporter on 2026-10-13

On 2026-10-13, the review of PR #29 found 8 Go standard library findings in `prometheus-nats-exporter` on both legs. The `go1.26` toolchain pin, Go 1.26.6, caused them.

## Source of the measurement

* The review comment on PR #29 (`prometheus-nats-exporter` `v0.20.2`), posted 2026-10-13 at 04:11 UTC, after the merge. GH #30 reported it.

## Result

| Advisory | Severity |
|---|---|
| `GO-2026-6612` | Critical |
| `GO-2026-6603`, `-6605`, `-6607`, `-6608`, `-6610`, `-6611`, `-6613` | High, each with a fix |

* Both legs (amd64 and arm64) had `blocking=8`.
* The image had the enforcement `observe`, and the legs had blocking findings. Thus the review check was green, and the image went to `quarantine/` only, as per-architecture tags with no index.
* These are `stdlib` findings. Every image built with Go 1.26.6 had the same set. Images built before the advisories (2026-10-08) passed review at that time.
* On 2026-10-13, the tag `golang:1.26-trixie` resolved to Go 1.26.9.

## Related

* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md)
