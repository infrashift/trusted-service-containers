---
id: "01a1dc27-b857-7993-be36-71a70044ca14"
title: "Six waivers renew the 2026-11-22 expiries; traefik needs none"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
created: "2026-11-14T16:22:33-06:00"
timestamp: "2026-11-14T16:22:33-06:00"
description: "On 2026-11-14, EXC-2026-0033 to 0038 renewed the waivers that expired on 2026-11-22, with only the CVEs that still match; EXC-2026-0003 for traefik was not renewed."
x:
  waivers:
    - "EXC-2026-0033"
    - "EXC-2026-0034"
    - "EXC-2026-0035"
    - "EXC-2026-0036"
    - "EXC-2026-0037"
    - "EXC-2026-0038"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-12-14T00:00:00Z"
---

# Six waivers renew the 2026-11-22 expiries; traefik needs none

On 2026-11-14, six new waivers replaced `EXC-2026-0001` to `EXC-2026-0007`, which expire on 2026-11-22. Each new waiver lists only the CVEs that still match a finding.

## Record

| New waiver | Replaces | Image | CVEs kept | CVEs dropped | Expires |
|---|---|---|---|---|---|
| `EXC-2026-0033` | `EXC-2026-0001` | nexus3 | 32 of 32 | none | 2027-02-12 |
| `EXC-2026-0034` | `EXC-2026-0002` | postgres | 7 of 15 | 8 | 2026-12-14 |
| none | `EXC-2026-0003` | traefik | 0 of 6 | 6 | not renewed |
| `EXC-2026-0035` | `EXC-2026-0004` | hydra | 7 of 8 | `GHSA-x744-4wpc-v9h2` | 2026-12-29 |
| `EXC-2026-0036` | `EXC-2026-0005` | kratos | 6 of 7 | `GHSA-x744-4wpc-v9h2` | 2026-12-29 |
| `EXC-2026-0037` | `EXC-2026-0006` | keto | 5 of 6 | `GHSA-x744-4wpc-v9h2` | 2026-12-29 |
| `EXC-2026-0038` | `EXC-2026-0007` | oathkeeper | 6 of 6 | none | 2026-12-29 |

* Issued 2026-11-14. Owner `@ryancraig`.
* The build legs come from the review of PR #49. The mirror legs come from the scan evidence of the PR #46 build, because the review comment lists no waived mirror finding.

## Why each window

* nexus3: `verify-pins` reports `3.90.5-ubi` current. Only a Sonatype release clears the findings, so the window is 90 days.
* postgres: `verify-pins` reports all four DHI pins stale. Two of the seven Criticals have a fix in `libcurl` `8.14.1-2+deb13u7`. A re-pin can clear part of the set, so the window is 30 days.
* Ory: the owner keeps all four Ory images. The window ends with the Ory grpc waivers, on 2026-12-29.

## What to do next

1. Re-pin the postgres DHI digests, and read the scan. Then renew or remove `EXC-2026-0034` before 2026-12-14.
2. The review comment omits the waived findings of mirror legs. Fix the table, so that a reviewer can see each waived mirror finding.
