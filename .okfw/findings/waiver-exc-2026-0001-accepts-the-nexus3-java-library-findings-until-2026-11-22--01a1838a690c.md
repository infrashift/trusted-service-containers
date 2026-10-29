---
id: "01a1838a-690c-7524-b09c-cf6e64613ca7"
title: "Waiver EXC-2026-0001 accepts the nexus3 Java library findings until 2026-11-22"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "nexus3"
created: "2026-10-28T12:24:08-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "EXC-2026-0001 waives 32 advisories in the Sonatype jar files of the nexus3 mirror, because only a Sonatype release can clear them."
x:
  github:
    - 5
  waivers:
    - "EXC-2026-0001"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-11-22T00:00:00Z"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/4"
    title: "PR #4"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/5"
    title: "GH #5"
---

# Waiver EXC-2026-0001 accepts the nexus3 Java library findings until 2026-11-22

Waiver `EXC-2026-0001` accepts 32 advisories in the Java libraries of the nexus3 image. It applies to all variants and all packages of nexus3, and it expires on 2026-11-22.

## Record

| Field | Value |
|---|---|
| Waiver | `EXC-2026-0001` |
| Image | nexus3, variant `*`, package `*` |
| Advisories | 32 GHSA ids |
| Issued | 2026-08-24 |
| Expires | 2026-11-22 |
| Owner | `@ryancraig` |
| Ticket | GH #5 |
| Added by | `1400b58`, PR #4 (2026-08-24) |

## What it covers

The findings are in the jar files that Sonatype ships in the image. The review of PR #39 showed these packages:

* netty: handler, codec-http, codec-http2, codec-dns, codec-compression, resolver-dns and transport
* jackson-core and jackson-databind
* spring-security-web, spring-security-saml2-service-provider and spring-expression
* jetty-http and jetty-ee8-security
* bcprov and bcpg
* commons-io, plexus-utils, the postgresql JDBC driver and shiro-core

Two advisories are Critical: one in bcprov and one in spring-security-web.

## Why the waiver exists

* nexus3 is a mirror track image. We copy the Sonatype image by digest and do not rebuild it. Only a Sonatype release can change the jar files.
* On 2026-08-24, the pinned tag `3.90.5-ubi` resolved to the pinned digest. No newer tag was available.
* The waiver keeps each finding visible in every signed verdict. It does not hide it.

## What removes the need

1. A Sonatype release on the track (`3.90.x` or `3.91`) clears the findings. The drift report of 2026-10-28 proposed `3.90.6-ubi`.
2. A review of the new pin shows which findings remain.
3. Remove the waiver, or renew it with a new review before 2026-11-22. An expired waiver waives nothing.

## Analysis

On 2026-10-28, the waiver matched 66 waived findings on `nexus3-runtime`, and 88 findings were still blocking. The waiver covers the August set only. The leg still has blocking findings, so it goes to `quarantine/`. The `observe` mode changes only the verdict to `PASS (observe)`. A leg with no blocking finding goes to `trusted/` in both modes.

## Related

* [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md)
* [The first nexus3 scan found 32 blocking findings on 2026-08-24](/findings/the-first-nexus3-scan-found-32-blocking-findings-on-2026-08-24--01a1838a6d6d.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [nexus3](/images/nexus3--01a183832d26.md)
