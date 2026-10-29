---
id: "01a1838a-6d6d-7371-a0a8-5a43a0c16762"
title: "The first nexus3 scan found 32 blocking findings on 2026-08-24"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "nexus3"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "The first scan of the nexus3 3.90.5-ubi mirror found 32 blocking findings, 2 of them Critical, in the Sonatype jar files."
x:
  github:
    - 5
  waivers:
    - "EXC-2026-0001"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/5"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
---

# The first nexus3 scan found 32 blocking findings on 2026-08-24

The first scan of the nexus3 mirror image found 32 blocking findings, 2 of them Critical, on both platforms.

## Source of the measurement

* GH #5, opened on 2026-08-25. The scan was of the pin `3.90.5-ubi`.
* Waiver `EXC-2026-0001` (issued 2026-08-24) lists the same 32 advisories.

## Result

| Leg | Platforms | Blocking | Critical |
|---|---|---:|---:|
| `nexus3-runtime` | amd64, arm64 | 32 | 2 |

* The findings are in Java libraries inside the vendor image: netty, jackson, spring-security, jetty, bcprov, shiro and others.
* On 2026-08-24, the tag `3.90.5-ubi` resolved to the pinned digest. No newer tag was available.

## Later measurement

On 2026-10-28, the review of PR #39 showed Blocking 88 and Waived 66 for `nexus3-runtime`. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

## Related

* [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md)
* [Waiver EXC-2026-0001 accepts the nexus3 Java library findings until 2026-11-22](/findings/waiver-exc-2026-0001-accepts-the-nexus3-java-library-findings-until-2026-11-22--01a1838a690c.md)
* [The day-one CVE count of nexus3 was unknown](/issues/the-day-one-cve-count-of-nexus3-was-unknown--01a1838a15d7.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [nexus3](/images/nexus3--01a183832d26.md)
