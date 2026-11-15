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
    - "EXC-2026-0034"
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

* **Decision, 2026-11-14:** the owner chose to build PostgreSQL 17 on UBI in this repository, in place of the DHI mirror. Until this repository trusts that image, the DHI postgres mirror runs in `observe` mode. Its images stay in `quarantine/` and never reach `trusted/`, as before. When HALO and Chit move to the UBI image, a change removes the DHI postgres entries and `EXC-2026-0034`.
* On 2026-11-14, the drift re-pin (PR #52) cleared every traefik finding. The postgres legs still had 8 (16) and 144 (17) blocking findings at the newest DHI digest.
* **Replacement ready, 2026-11-14 (PR #55):** [postgresql17](/images/postgresql17--01a1dd2247ba.md) builds PostgreSQL 17 from signed PGDG RPMs at pinned NEVRAs on our `ubi9-minimal`. See [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md). It keeps the `POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_DB` contract, has `psql` and `pg_isready`, and passed the HALO and Chit integration tests. Its first scan had 0 Critical and 14 fixable Highs, all in `krb5-libs`, against 144 blocking findings on each DHI 17 leg.
* **HALO and Chit moved, 2026-11-14:** Chit uses postgresql17 since Chit PR #8. HALO uses postgresql17 in its local tree. HALO does not push to GitHub before its v0.1.0 release.
* **The PostgreSQL 17 variants are removed, 2026-11-14 (PR #56):** the change removed `runtime17` and `dev17` from the DHI `postgres` entry in `versions.json`. No workflow builds, reviews, releases or drifts them now. The change did not delete the images on GHCR.
* **The PostgreSQL 16 variants stay.** `ansible-collection-infrashift-hashistack` pins the `trusted/postgres` 16 image by digest. Thus `runtime` and `dev` stay in `versions.json`.
* **`EXC-2026-0034` stays until the hashistack collection moves.** Its variant is `"*"`, so it covers the two 16 legs. The removal of the 17 variants does not make it narrower, and no policy rule requires that. On 2026-11-14, `make -f Ops.mk verify-mirror-pins` reported the two 16 pins current. Before 2026-12-14, read a scan of the newest 16 digests, then renew or remove the waiver.
* The remaining steps are:
  1. `ansible-collection-infrashift-hashistack` moves off the DHI postgres 16 image, with a dump and a restore of its data.
  2. Then a separate change removes the DHI `postgres` entry from `versions.json` and removes `EXC-2026-0034` (and the other postgres waivers) from `.github/pdp/exceptions.yaml`. The traefik part of this issue stays open.

## Acceptance criteria

- [ ] A PR moves the DHI pins to the newest digests on their tags, and a review gives the new blocking counts.
- [ ] A decision records whether the scan reads the DHI OpenVEX attestation.
- [ ] A new pin clears each blocking finding, or a waiver with a current justification covers it.
- [x] Before 2026-11-22, a new review renews `EXC-2026-0002` and `EXC-2026-0003`, or a change removes them. (2026-11-14: `EXC-2026-0034` renews 7 of the 15 postgres CVEs until 2026-12-14. `EXC-2026-0003` is not renewed: none of its 6 CVEs match. See [Six waivers renew the 2026-11-22 expiries; traefik needs none](/findings/six-waivers-renew-the-2026-11-22-expiries-traefik-needs-none--01a1dc27b857.md).)
- [ ] Before 2026-12-14, re-pin the postgres 16 DHI digests if they are stale, and read the scan. Then renew or remove `EXC-2026-0034`. (2026-11-14: the two 17 digests are removed, see PR #56. `verify-mirror-pins` reported the two 16 pins current.)
- [x] A trusted PostgreSQL 17 image on UBI exists in this repository: postgresql17 (2026-11-14).
- [x] HALO uses postgresql17 (2026-11-14, in the local HALO tree).
- [x] Chit uses postgresql17 (2026-11-14, Chit PR #8).
- [x] A change removes the DHI postgres 17 variants `runtime17` and `dev17` (2026-11-14, PR #56).
- [ ] `ansible-collection-infrashift-hashistack` moves off the DHI postgres 16 image.
- [ ] A change removes the DHI `postgres` entry and `EXC-2026-0034`.

## Related

* [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md)
* [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md)
* [The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24](/findings/the-first-dhi-scans-found-critical-debian-findings-in-postgres-and-traefik-dev-on-2026-08-24--01a1838a6de3.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [postgres](/images/postgres--01a183832d06.md)
* [postgresql17](/images/postgresql17--01a1dd2247ba.md): the UBI replacement for the DHI postgres 17 legs.
* [traefik](/images/traefik--01a183832cbc.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
