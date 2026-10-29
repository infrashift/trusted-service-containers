---
id: "01a1838a-1439-7637-904e-6a1a8f1ed121"
title: "The ubi9-micro base pins were behind the sibling repository on 2026-10-14"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "resolved"
  - "drift"
  - "base"
created: "2026-10-28T12:23:46-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "The base drift job found new ubi9-micro digests on 2026-10-14; PR #32 re-pinned them to the pcre2-patched release."
x:
  github: 33
status: "deprecated"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/33"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/32"
    title: "PR #32"
---

# The ubi9-micro base pins were behind the sibling repository on 2026-10-14

## Problem

On 2026-10-14, the base drift workflow found that the `ubi9-micro` pins (amd64 and arm64) were behind the digests of the sibling repository `infrashift/trusted-base-images`. Every build track image uses `ubi9-micro` as its runtime base.

## Context

* The bot opened GH #33 with the label `base-drift`.
* A base change rebuilds every build track image, because `versions.json` is a path trigger for `.github/workflows/build.yml`.
* Before a merge, the bot asks for `make -f Ops.mk verify-pins`. The Containerfiles add a CA bundle, tzdata and UID 1001, because `ubi9-micro` does not have them.

## Acceptance criteria

- [x] The `ubi9-micro` pins match the digests of the sibling repository.

## Resolution

Resolved on 2026-10-14.

* PR #32 (merged 2026-10-14), `0361ba8`: the trusted `ubi9-micro` pins moved to the release with the patched `pcre2`.
* The bot closed GH #33 on 2026-10-15: every pin was current.

## Related

* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md)
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
* [Base Image Drift workflow](/supply-chain/base-image-drift-workflow--01a18383d780.md)
