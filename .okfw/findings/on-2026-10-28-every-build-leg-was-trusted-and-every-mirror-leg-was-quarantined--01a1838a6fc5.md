---
id: "01a1838a-6fc5-781f-8004-90a8f920a0a9"
title: "On 2026-10-28 every build leg was trusted and every mirror leg was quarantined"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "mssql"
  - "nexus3"
  - "postgres"
  - "traefik"
  - "whoami"
created: "2026-10-28T12:24:10-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "The review of PR #39 gives the verdict, blocking and waived counts of every leg on 2026-10-28, after the October bumps and waivers."
x:
  github:
    - 5
    - 6
    - 7
    - 37
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
---

# On 2026-10-28 every build leg was trusted and every mirror leg was quarantined

On 2026-10-28, the review of PR #39 put all 24 build legs in `trusted/`. Every mirror leg went to `quarantine/`, with blocking findings that no waiver covers.

## Source of the measurement

* The review comment on PR #39, posted 2026-10-28 at 14:29 UTC. PR #39 changed `.github/pdp/`, so the review ran every leg again.
* At that time, `main` had the merges of PR #35, PR #36, PR #38 and PR #39.

## Build track

| Image | Verdict | Namespace | Blocking | Waived |
|---|---|---|---:|---:|
| `daprd`, `dapr-placement`, `dapr-scheduler` | `PASS` | `trusted` | 0 | 1 each |
| hydra | `PASS` | `trusted` | 0 | 14 |
| keto | `PASS` | `trusted` | 0 | 12 |
| kratos | `PASS` | `trusted` | 0 | 15 |
| oathkeeper | `PASS` | `trusted` | 0 | 15 |
| loki, nats, prometheus, `prometheus-nats-exporter` | `PASS` | `trusted` | 0 | 0 |
| seaweedfs | `PASS` | `trusted` | 0 | 1 |

The counts are per leg. Each image has an amd64 and an arm64 leg with the same counts.

## Mirror track

| Leg | Enforcement | Verdict | Namespace | Blocking | Waived | Recorded |
|---|---|---|---|---:|---:|---:|
| `mssql-runtime` (amd64) | `observe` | `PASS (observe)` | `quarantine` | 60 | 0 | 57 |
| `nexus3-runtime` | `observe` | `PASS (observe)` | `quarantine` | 88 | 66 | 24 |
| `postgres-dev`, `postgres-dev17` | `enforce` | `FAIL` | `quarantine` | 8 each | 36 each | 268 each |
| `postgres-runtime`, `postgres-runtime17` | `enforce` | `FAIL` | `quarantine` | 8 each | 36 each | 176 each |
| `traefik-dev` | `enforce` | `FAIL` | `quarantine` | 86 | 0 | 164 |
| `traefik-runtime` | `enforce` | `FAIL` | `quarantine` | 34 | 0 | 0 |
| `whoami-runtime` (amd64, arm, arm64) | `observe` | `PASS (observe)` | `quarantine` | 54 | 0 | 0 |

The review table shows one row for all platforms of a mirror leg.

## Waivers that matched

* Every waiver from `EXC-2026-0001` to `EXC-2026-0029` matched at least one finding, except `EXC-2026-0003` and `EXC-2026-0013` to `EXC-2026-0016`.
* `EXC-2026-0002` matched 7 of its 15 ids on each postgres leg.

## Dual provenance

The cross-check ran on all 24 build legs. No leg matched the vendor binary. Every leg had the tier `best-effort`. See [A nats binary built from source did not match the vendor binary on 2026-08-18](/findings/a-nats-binary-built-from-source-did-not-match-the-vendor-binary-on-2026-08-18--01a1838a6cfc.md).

## Related

* [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [The mssql image has 60 blocking findings and no triage](/issues/the-mssql-image-has-60-blocking-findings-and-no-triage--01a1838a1626.md)
* [The whoami mirror has 54 blocking findings and no triage](/issues/the-whoami-mirror-has-54-blocking-findings-and-no-triage--01a1839ccc1d.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [A nats binary built from source did not match the vendor binary on 2026-08-18](/findings/a-nats-binary-built-from-source-did-not-match-the-vendor-binary-on-2026-08-18--01a1838a6cfc.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [postgres](/images/postgres--01a183832d06.md)
* [nexus3](/images/nexus3--01a183832d26.md)
* [mssql](/images/mssql--01a183832d44.md)
* [whoami](/images/whoami--01a183832d61.md)
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
