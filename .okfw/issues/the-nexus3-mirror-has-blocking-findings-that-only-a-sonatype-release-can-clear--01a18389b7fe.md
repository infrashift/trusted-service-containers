---
id: "01a18389-b7fe-76c5-bf1e-45cdb295fa97"
title: "The nexus3 mirror has blocking findings that only a Sonatype release can clear"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "nexus3"
  - "cve"
  - "waiver"
created: "2026-10-28T12:23:23-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "nexus3 is a mirror, so only a new Sonatype image clears its Java library findings; waiver EXC-2026-0001 expires on 2026-11-22."
x:
  github: 5
  waivers:
    - "EXC-2026-0001"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/5"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39 review comment"
---

# The nexus3 mirror has blocking findings that only a Sonatype release can clear

## Problem

The `nexus3-runtime` leg has blocking findings in the Java libraries inside the Sonatype image, for example netty, jackson, spring-security, jetty, bcprov and shiro. nexus3 is a mirror track image. We copy the vendor image by digest and do not rebuild it. Thus we cannot change these libraries. Only a new Sonatype release can clear the findings.

## Context

* On 2026-08-25, GH #5 recorded 32 blocking findings (2 Critical) on both platforms. See [The first nexus3 scan found 32 blocking findings on 2026-08-24](/findings/the-first-nexus3-scan-found-32-blocking-findings-on-2026-08-24--01a1838a6d6d.md).
* Waiver `EXC-2026-0001` covers these 32 advisories until 2026-11-22. See [Waiver EXC-2026-0001 accepts the nexus3 Java library findings until 2026-11-22](/findings/waiver-exc-2026-0001-accepts-the-nexus3-java-library-findings-until-2026-11-22--01a1838a690c.md).
* On 2026-10-28, the review of PR #39 showed this row for `nexus3-runtime` (both platforms): Blocking 88, Waived 66, Recorded 24. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).
* nexus3 has the enforcement `observe`, and it has blocking findings. Thus the verdict is `PASS (observe)`, and the release actor puts it in `quarantine/`, not in `trusted/`.
* On 2026-10-28, the upstream drift report proposed the tag `3.90.6-ubi`. That change is not merged. See [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md).
* The justification of `EXC-2026-0001` says that the pinned tag is the newest tag. That was true on 2026-08-24. The drift report of 2026-10-28 shows that it is no longer true.

## Acceptance criteria

- [ ] A review of the `3.90.6-ubi` pin, or of a newer tag on the track, gives the blocking count.
- [ ] The new pin clears each blocking finding, or a new waiver with a current justification covers it.
- [ ] Before 2026-11-22, a new review renews `EXC-2026-0001`, or a change removes it.

## Related

* [Waiver EXC-2026-0001 accepts the nexus3 Java library findings until 2026-11-22](/findings/waiver-exc-2026-0001-accepts-the-nexus3-java-library-findings-until-2026-11-22--01a1838a690c.md)
* [The first nexus3 scan found 32 blocking findings on 2026-08-24](/findings/the-first-nexus3-scan-found-32-blocking-findings-on-2026-08-24--01a1838a6d6d.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [The day-one CVE count of nexus3 was unknown](/issues/the-day-one-cve-count-of-nexus3-was-unknown--01a1838a15d7.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [Issue workflow](/guides/issue-workflow--01a1837da656.md)
* [nexus3](/images/nexus3--01a183832d26.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
