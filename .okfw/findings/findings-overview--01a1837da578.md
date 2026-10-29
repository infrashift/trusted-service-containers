---
id: "01a1837d-a578-790f-872c-e7b6a748b3b9"
title: "Findings overview"
type: "overview"
tags:
  - "hub"
  - "findings"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "Dated facts: waivers with an expiry date, CVE measurements, and the dual-provenance measurement."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Findings overview

This bundle holds dated facts: one concept for each group of waivers, and one concept for each measurement. A waiver finding goes stale on the expiry date of its first waiver.

Do not put a problem or a task here. Put it in `issues/`. Do not copy a waiver from `.github/pdp/exceptions.yaml`. Give its id and link to the file.

## Find concepts

* List this bundle: read `.okfw/findings/index.md`.
* Waivers: `okfw search --type finding --tag waiver`.
* Measurements: `okfw search --type finding --tag measurement`.

## Add a concept

1. Search the wiki first. Update a concept that exists, if possible.
2. Run `okfw create "<Title>" --type finding --path findings -d "<one sentence>" --tags finding,waiver` (or `finding,measurement`).
3. For a waiver, set `x.waivers` and run `okfw set-stale-after <id> <expires>T00:00:00Z`. Add a link in the list below.
4. Obey the [wiki conventions](/guides/wiki-conventions--01a1837da62e.md) and [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Concepts

### Waivers

The date after each link is the expiry. `.github/pdp/exceptions.yaml` is the source of truth.

* [Waiver EXC-2026-0001 accepts the nexus3 Java library findings until 2026-11-22](/findings/waiver-exc-2026-0001-accepts-the-nexus3-java-library-findings-until-2026-11-22--01a1838a690c.md): expires 2026-11-22.
* [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md): expires 2026-11-22.
* [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md): expires 2026-11-22.
* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md): expires 2026-11-27.
* [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md): expires 2026-11-27.
* [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md): expires 2026-12-29.
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md): expires 2026-12-29. On 2026-10-28, the dapr waivers in this group matched no finding.
* [Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29](/findings/waiver-exc-2026-0016-accepts-amqp091-go-findings-in-daprd-until-2026-12-29--01a1838a6b8d.md): expires 2026-12-29. On 2026-10-28, it matched no finding.

### Measurements

* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md): the newest full review of all legs.
* [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md)
* [Go 1.26.6 put 8 stdlib findings into prometheus-nats-exporter on 2026-10-13](/findings/go-1-26-6-put-8-stdlib-findings-into-prometheus-nats-exporter-on-2026-10-13--01a1838a6f27.md)
* [On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl](/findings/on-2026-09-30-the-new-postgres-16-digest-had-fewer-findings-and-postgres-did-not-link-libcurl--01a1838a6ec1.md)
* [The first nexus3 scan found 32 blocking findings on 2026-08-24](/findings/the-first-nexus3-scan-found-32-blocking-findings-on-2026-08-24--01a1838a6d6d.md)
* [The first DHI scans found Critical Debian findings in postgres and traefik-dev on 2026-08-24](/findings/the-first-dhi-scans-found-critical-debian-findings-in-postgres-and-traefik-dev-on-2026-08-24--01a1838a6de3.md)
* [The first Ory scans found vendored Go findings in all four images on 2026-08-24](/findings/the-first-ory-scans-found-vendored-go-findings-in-all-four-images-on-2026-08-24--01a1838a6e4f.md)
* [A nats binary built from source did not match the vendor binary on 2026-08-18](/findings/a-nats-binary-built-from-source-did-not-match-the-vendor-binary-on-2026-08-18--01a1838a6cfc.md)

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md): the issues that the waivers cite.
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
