---
id: "01a1838a-1626-7930-8221-3f96b536f7fe"
title: "The mssql image has 60 blocking findings and no triage"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "prd"
  - "mssql"
  - "cve"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "On 2026-10-28 mssql had 60 blocking findings, no waiver and no triage record, so it stays in quarantine under observe."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.ai/PRD.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39 review comment"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/9"
    title: "PR #9"
---

# The mssql image has 60 blocking findings and no triage

## Problem

The mssql image has 60 blocking findings, and nobody has done a triage. `.github/pdp/exceptions.yaml` has no mssql waiver, and no issue records which findings are acceptable. The image stays in `quarantine/`.

## Context

* Before the wiki adoption, `.ai/PRD.md` listed this open item: "mssql's day-one CVE count is unknown; a ~700MB RHEL image will very likely quarantine. Triage lands in `.github/pdp/exceptions.yaml` after the first scan." `.ai/PRD.md` is now a pointer to the wiki, and the open items are in the [Issues overview](/issues/issues-overview--01a1837da5b0.md).
* PR #9 added mssql on 2026-09-11 with the enforcement `observe`, "pending day-one CVE triage". The pin moved to `2025-CU9-rhel-10` in PR #15 (2026-09-15).
* The count is now known. On 2026-10-28, the review of PR #39 gave `mssql-runtime` (amd64 only): Blocking 60, Waived 0, Recorded 57. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).
* The note in `versions.json` says that mssql stays in `observe` until the triage is in `.github/pdp/exceptions.yaml`.
* The drift report of 2026-10-28 proposed a new digest on `2025-latest`. That change is not merged. See [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md).

## Acceptance criteria

- [ ] A review of the newest `2025-latest` digest gives the blocking findings by package.
- [ ] A new pin clears each blocking finding, or a waiver with an owner, an expiry and a justification covers it. Alternatively, an issue records that `quarantine/` is the intended state.
- [ ] The [mssql](/images/mssql--01a183832d44.md) concept gives the result of the triage.

## Related

* [The pinned mssql signing identity expires on 2027-10-31](/issues/the-pinned-mssql-signing-identity-expires-on-2027-10-31--01a1838a166f.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [mssql](/images/mssql--01a183832d44.md)
