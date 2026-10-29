---
id: "01a1838a-6ec1-7eb7-b9eb-08786553c173"
title: "On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "postgres"
created: "2026-10-28T12:24:10-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "The proposed postgres 16-debian digest had 18 Critical and 84 High findings against 42 and 156; readelf showed no libcurl link."
x:
  github:
    - 22
  waivers:
    - "EXC-2026-0008"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/22"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/21"
    title: "PR #21"
---

# On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl

On 2026-09-30, a local grype scan showed that the new DHI digest of postgres `16-debian` had fewer findings than the pinned digest. A `readelf` check showed that the postgres server did not link libcurl.

## Source of the measurement

* GH #22, opened on 2026-09-30. The scan was part of the triage of drift PR #21.

## Result

| postgres `16-debian` digest | Critical | High |
|---|---:|---:|
| Pinned before PR #21 | 42 | 156 |
| Proposed by PR #21 | 18 | 84 |

* Every blocking finding in PR #21 was also present in the digest that was in `trusted/`. The new pins added no finding.

## libcurl link check

`readelf -d` listed the `NEEDED` libraries:

| Binary | Links libcurl |
|---|---|
| `/usr/bin/postgres` | no |
| `llvmjit.so`, through `libLLVM.so.19.1` | no |

libcurl is in the image only as a package dependency of `postgresql-16` and `llvm-19`. Debian had no fixed package for `CVE-2026-18924` and `CVE-2026-19931`.

## Related

* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md)
* [The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24](/findings/the-first-dhi-scans-found-critical-debian-findings-in-postgres-and-traefik-dev-on-2026-08-24--01a1838a6de3.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [postgres](/images/postgres--01a183832d06.md)
