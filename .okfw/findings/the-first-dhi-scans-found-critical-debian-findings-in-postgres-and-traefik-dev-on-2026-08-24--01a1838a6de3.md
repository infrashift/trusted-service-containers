---
id: "01a1838a-6de3-77c2-b2e7-bc31ab6e8a69"
title: "The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "postgres"
  - "traefik"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "The first scans of the DHI mirrors found Critical Debian base findings in postgres runtime, postgres dev and traefik dev, and none in traefik runtime."
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
resource: "https://github.com/infrashift/trusted-service-containers/issues/6"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
---

# The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24

The first scans of the DHI mirror images found Critical findings in the Debian base layers of `postgres-runtime`, `postgres-dev` and `traefik-dev`. `traefik-runtime` had none.

## Source of the measurement

* GH #6, opened on 2026-08-25.
* Waivers `EXC-2026-0002` (postgres, 15 CVE ids) and `EXC-2026-0003` (traefik `dev`, 6 CVE ids), issued 2026-08-24.

## Result

| Leg | Result on 2026-08-24 |
|---|---|
| `postgres-runtime` | Critical findings in Debian packages |
| `postgres-dev` | Critical findings in Debian packages |
| `traefik-dev` | Critical findings in Debian packages |
| `traefik-runtime` | no findings |

* The packages include `libc6`, `perl-base`, `libcurl4t64`, `libxml2` and `gawk`.
* On 2026-08-24, the tags `3-debian13`, `3-debian13-dev`, `16-debian` and `16-debian-dev` resolved to the pinned digests.
* The review recorded `UPSTREAM_VEX_ABSENT` for these legs.

## Later measurement

On 2026-10-28, each postgres leg had 8 blocking findings, `traefik-dev` had 86 and `traefik-runtime` had 34. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

## Related

* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md)
* [On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl](/findings/on-2026-09-30-the-new-postgres-16-digest-had-fewer-findings-and-postgres-did-not-link-libcurl--01a1838a6ec1.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
