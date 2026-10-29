---
id: "01a1838a-11fc-7bfb-aa5d-a670c0733746"
title: "The DHI postgres and traefik images have Debian base findings that only Docker can clear"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "postgres"
  - "traefik"
  - "cve"
  - "waiver"
created: "2026-10-28T12:23:46-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "postgres and traefik are DHI mirrors with Critical Debian base findings that only a Docker rebuild clears; their waivers expire on 2026-11-22."
x:
  github: 6
  waivers:
    - "EXC-2026-0002"
    - "EXC-2026-0003"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/6"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39 review comment"
---

# The DHI postgres and traefik images have Debian base findings that only Docker can clear

## Problem

The DHI images of postgres and traefik have Critical findings in their Debian base layers, for example in `libc6`, `perl-base`, `libcurl4t64`, `libxml2` and `gawk`. Both images are mirror track images with the trust class `dhi`. We copy Docker Hardened Images by digest and do not rebuild them. Only a new Docker build on the same tag can clear the findings.

## Context

* On 2026-08-25, GH #6 recorded Critical findings in `postgres-runtime`, `postgres-dev` and `traefik-dev`. See [The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24](/findings/the-first-dhi-scans-found-critical-debian-findings-in-postgres-and-traefik-dev-on-2026-08-24--01a1838a6de3.md).
* Waivers `EXC-2026-0002` (postgres) and `EXC-2026-0003` (traefik `dev`) cover these findings until 2026-11-22. See [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md).
* Both images have the enforcement `enforce`. A leg with a blocking finding gets a `FAIL` verdict and goes to `quarantine/`.
* On 2026-10-28, the review of PR #39 gave these rows. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

| Leg | Verdict | Blocking | Waived |
|---|---|---:|---:|
| `postgres-runtime`, `postgres-dev`, `postgres-runtime17`, `postgres-dev17` | `FAIL` | 8 each | 36 each |
| `traefik-dev` | `FAIL` | 86 | 0 |
| `traefik-runtime` | `FAIL` | 34 | 0 |

* `EXC-2026-0003` waived no finding on 2026-10-28. The justification of `EXC-2026-0003` says that the traefik runtime variant reports no findings. On 2026-10-28 it had 34 blocking findings.
* The review records `UPSTREAM_VEX_ABSENT` for these legs. DHI publishes an OpenVEX attestation. If the scan reads that VEX data, some findings can close on evidence, not by a waiver.
* The drift report of 2026-10-28 proposed new digests for all six DHI variants. That change is not merged. See [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md).

## Acceptance criteria

- [ ] A PR moves the DHI pins to the newest digests on their tags, and a review gives the new blocking counts.
- [ ] A decision records whether the scan reads the DHI OpenVEX attestation.
- [ ] A new pin clears each blocking finding, or a waiver with a current justification covers it.
- [ ] Before 2026-11-22, a new review renews `EXC-2026-0002` and `EXC-2026-0003`, or a change removes them.

## Related

* [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md)
* [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md)
* [The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24](/findings/the-first-dhi-scans-found-critical-debian-findings-in-postgres-and-traefik-dev-on-2026-08-24--01a1838a6de3.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
