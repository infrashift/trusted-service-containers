---
id: "01a1838a-6a7d-7c66-a345-395f9e1728e7"
title: "Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "postgres"
created: "2026-10-28T12:24:08-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "EXC-2026-0008 waives two Critical libcurl4t64 advisories in all postgres variants; Debian has no fix and postgres does not link libcurl."
x:
  github:
    - 22
  waivers:
    - "EXC-2026-0008"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-12-29T00:00:00Z"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/21"
    title: "PR #21"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/22"
    title: "GH #22"
---

# Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29

Waiver `EXC-2026-0008` accepts two Critical `libcurl4t64` advisories in all postgres variants. It expires on 2026-12-29.

## Record

| Field | Value |
|---|---|
| Waiver | `EXC-2026-0008` |
| Image | postgres, variant `*`, package `libcurl4t64` |
| Advisories | `CVE-2026-18924`, `CVE-2026-19931` (Critical) |
| Issued | 2026-09-30 |
| Expires | 2026-12-29 |
| Owner | `@ryancraig` |
| Ticket | GH #22 |
| Added by | `670d7d7`, PR #21 (2026-09-30) |

## Why the waiver exists

* postgres is a DHI mirror. We do not rebuild it. Debian has no fixed package.
* Neither the server (`/usr/bin/postgres`) nor its JIT links libcurl. A `readelf` check on 2026-09-30 showed this. libcurl is in the image only as a package dependency of `postgresql-16` and `llvm-19`. See [On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl](/findings/on-2026-09-30-the-new-postgres-16-digest-had-fewer-findings-and-postgres-did-not-link-libcurl--01a1838a6ec1.md).
* The same findings were in the digest that the 2026-09-30 pins replaced.
* The waiver lists two ids only. A new libcurl advisory stays blocking.

## What removes the need

1. A DHI rebuild with a fixed libcurl. The drift workflow proposes DHI rebuilds.
2. Before 2026-12-29, renew the waiver with a new review, or remove it.

## Analysis

PR #16 (opened 2026-09-15, still open on 2026-10-28) proposed an earlier waiver for the same two advisories with the same id. PR #21 replaced it. On 2026-10-28, this waiver still matched both advisories on each of the four postgres legs. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

## Related

* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md)
* [On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl](/findings/on-2026-09-30-the-new-postgres-16-digest-had-fewer-findings-and-postgres-did-not-link-libcurl--01a1838a6ec1.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [postgres](/images/postgres--01a183832d06.md)
