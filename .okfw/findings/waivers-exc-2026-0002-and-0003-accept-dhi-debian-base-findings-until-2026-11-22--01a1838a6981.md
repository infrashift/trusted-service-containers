---
id: "01a1838a-6981-78e5-8997-c8971864f281"
title: "Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "postgres"
  - "traefik"
created: "2026-10-28T12:24:08-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "Two waivers accept Debian base-layer advisories in the DHI postgres images and traefik dev, because only a Docker rebuild can clear them."
x:
  github:
    - 6
  waivers:
    - "EXC-2026-0002"
    - "EXC-2026-0003"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-11-22T00:00:00Z"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/4"
    title: "PR #4"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/6"
    title: "GH #6"
---

# Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22

Waivers `EXC-2026-0002` and `EXC-2026-0003` accept Debian base-layer advisories in the DHI images of postgres and traefik. Both expire on 2026-11-22.

## Record

| Waiver | Image | Variant | Advisories | Issued | Expires |
|---|---|---|---:|---|---|
| `EXC-2026-0002` | postgres | `*` | 15 CVE ids | 2026-08-24 | 2026-11-22 |
| `EXC-2026-0003` | traefik | `dev` | 6 CVE ids | 2026-08-24 | 2026-11-22 |

* Package: `*` for both. Owner: `@ryancraig`. Ticket: GH #6.
* Added by `1400b58`, PR #4 (2026-08-24).
* The 6 traefik ids are also in the postgres list.

## What it covers

Critical and High findings in the Debian packages of the DHI base layers, for example `libc6`, `perl-base`, `libcurl4t64`, `libxml2` and `gawk`. `EXC-2026-0003` covers only the traefik `dev` variant. On 2026-08-24, the traefik runtime variant reported no findings.

## Why the waivers exist

* postgres and traefik are mirror track images with the trust class `dhi`. We copy the Docker Hardened Images by digest and do not rebuild them.
* Only a Docker rebuild on the same tag can clear these findings.
* On 2026-08-24, the four DHI tags resolved to the pinned digests.
* DHI publishes an OpenVEX attestation. If the scan reads it, some findings can close on evidence, not by a waiver.

## What removes the need

1. Move the DHI pins to the newest digests on their tags. The drift report of 2026-10-28 proposed new digests.
2. Read the DHI OpenVEX data in the scan, if the project decides to.
3. Remove the waivers, or renew them with a new review before 2026-11-22.

## Analysis

On 2026-10-28, `EXC-2026-0002` matched 7 of its 15 ids on each postgres leg. `EXC-2026-0003` matched none. `traefik-dev` had 86 blocking findings and `traefik-runtime` had 34. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md) and [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md).

## Related

* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md)
* [The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24](/findings/the-first-dhi-scans-found-critical-debian-findings-in-postgres-and-traefik-dev-on-2026-08-24--01a1838a6de3.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
