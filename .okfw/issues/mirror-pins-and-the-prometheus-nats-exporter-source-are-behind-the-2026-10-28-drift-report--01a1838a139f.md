---
id: "01a1838a-139f-7e40-b8bf-30070517a51f"
title: "Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "drift"
  - "nexus3"
  - "mssql"
  - "postgres"
  - "traefik"
  - "prometheus-nats-exporter"
created: "2026-10-28T12:23:46-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "The build-track bumps of the 2026-10-28 drift report are merged; the DHI, nexus3, mssql and prometheus-nats-exporter changes are not."
x:
  github: 24
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/24"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
    title: "versions.json"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/36"
    title: "PR #36"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/38"
    title: "PR #38"
---

# Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report

## Problem

The upstream drift report of 2026-10-28 proposed new pins, and some of them are not merged. The mirror pins of traefik, postgres, nexus3 and mssql, and the `prometheus-nats-exporter` source, are behind their upstream tags. The bot keeps GH #24 open until every pin is current.

## Context

* The bot opened GH #24 on 2026-10-01 with the label `upstream-drift`. It updates the same issue on each run. The last update was on 2026-10-28 at 13:33 UTC.
* These parts of the report are merged:

| Change | PR | Date |
|---|---|---|
| `go1.26` toolchain to go1.26.10 | PR #35 | 2026-10-28 |
| dapr `v1.18.9`, loki `v3.7.9` | PR #36 | 2026-10-28 |
| nats `v2.14.9`, prometheus `v3.15.1`, seaweedfs `4.51` | PR #38 | 2026-10-28 |

* These parts are not merged (checked against `versions.json` on 2026-10-28):

| Entry | Proposed change |
|---|---|
| traefik `runtime`, `dev` | new digests on the same DHI tags |
| postgres `runtime`, `dev`, `runtime17`, `dev17` | new digests on the same DHI tags |
| nexus3 `runtime` | tag `3.90.5-ubi` to `3.90.6-ubi` |
| mssql `runtime` | new digest on `2025-latest` |
| `prometheus-nats-exporter` | source `v0.20.2` to `v0.20.3` |

* A mirror re-pin can change the blocking counts in [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md) and [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md).
* A human must open the PR from the branch `automation/upstream-drift`. The `GITHUB_TOKEN` cannot open PRs in this repository.

## Acceptance criteria

- [ ] A PR moves the remaining pins, and its review comment shows the new blocking count for each leg.
- [ ] The bot closes GH #24 because every pin is current.

## Related

* [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [The mssql image has 60 blocking findings and no triage](/issues/the-mssql-image-has-60-blocking-findings-and-no-triage--01a1838a1626.md)
* [The 2026-09-30 drift proposal had wrong crosscheck pins and stale hashes](/issues/the-2026-09-30-drift-proposal-had-wrong-crosscheck-pins-and-stale-hashes--01a1838a12ff.md)
* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [nexus3](/images/nexus3--01a183832d26.md)
* [mssql](/images/mssql--01a183832d44.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
