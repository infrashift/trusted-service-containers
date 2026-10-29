---
id: "01a18383-2cbc-7946-8561-0363a4db821d"
title: "traefik"
type: "image"
tags:
  - "image"
  - "traefik"
  - "mirror"
created: "2026-10-28T12:16:14-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The traefik reverse proxy, mirrored from Docker Hardened Images with its DHI signature and attestations; trust class dhi."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
---

# traefik

traefik is a reverse proxy and load balancer. We mirror the Docker Hardened Images (DHI) build of it, with its DHI signature and attestations.

## Track

Mirror track, from `dhi.io/traefik`. A rebuild would destroy the DHI signature and the DHI claim of zero known CVEs. See [Mirror track](/architecture/mirror-track--01a18382f29c.md).

## Trust class

`dhi`. The mirror leg verifies the DHI signature against the committed keyring `.github/pdp/keyring/dhi-latest.pub`. The policy requires two attestations: a CycloneDX 1.6 SBOM and SLSA provenance v1. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

DHI images need an authenticated session. `dhi.io` holds the image layers. It also holds the DHI attestations, as OCI referrers (`SETUP-ENVIRONMENTS.md` §7). The workflows also log in to `registry.scout.docker.com`. The docs disagree on the reason. See [The docs disagree on Docker Hub authentication and on where DHI keeps its attestations](/issues/the-docs-disagree-on-docker-hub-authentication-and-on-where-dhi-keeps-its-attestations--01a18395b5db.md). On 2026-08-24, we resolved the first digests with an authenticated `dhi.io` login.

## Enforcement

See `versions.json` for the current value. On 2026-10-28 the value was `enforce`.

## Variants and platforms

| Variant | Tag |
|---|---|
| `runtime` | `3-debian13` |
| `dev` | `3-debian13-dev` |

Platforms: `linux/amd64`, `linux/arm64`.

Each track is an exact match of the tag. DHI moves the `3-debian13` tag itself, so the tag string never changes and only the digest moves. `drift-upstream.yml` proposes the new digest.

## Notes

* The `dev` variant runs as root and has a shell and a package manager. Do not use it in production. See [ADR-002: No latest tag](/decisions/adr-002-no-latest-tag--01a18382f469.md).
* DHI claims a near-zero baseline of known CVEs. Thus the PDP remediation hint says that a finding on a DHI image is probably a stale pin. Before you consider a waiver, resolve the digest again with `make -f Ops.mk verify-pins`.

## Issues and waivers

Open issues:

* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md)
* [Nobody has measured whether Docker OIDC covers registry.scout.docker.com](/issues/nobody-has-measured-whether-docker-oidc-covers-registry-scout-docker-com--01a1838a159a.md)
* [The docs disagree on Docker Hub authentication and on where DHI keeps its attestations](/issues/the-docs-disagree-on-docker-hub-authentication-and-on-where-dhi-keeps-its-attestations--01a18395b5db.md)

Resolved issues:

* [The 2026-09-30 drift proposal had wrong crosscheck pins and stale hashes](/issues/the-2026-09-30-drift-proposal-had-wrong-crosscheck-pins-and-stale-hashes--01a1838a12ff.md)
* [The four DHI digests and attestationRepo were placeholders](/issues/the-four-dhi-digests-and-attestationrepo-were-placeholders--01a1838a1552.md)

Waivers (see `.github/pdp/exceptions.yaml` for the entries):

* [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md)

Measurements:

* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24](/findings/the-first-dhi-scans-found-critical-debian-findings-in-postgres-and-traefik-dev-on-2026-08-24--01a1838a6de3.md)

## Related

* [postgres](/images/postgres--01a183832d06.md): the other `dhi` image.
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md)
* [Pinned upstream keyrings and identities](/architecture/pinned-upstream-keyrings-and-identities--01a18382f417.md)
* [Images overview](/images/images-overview--01a1837da526.md)
