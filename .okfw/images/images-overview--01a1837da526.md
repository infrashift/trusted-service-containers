---
id: "01a1837d-a526-7bdc-bf99-902458b3d609"
title: "Images overview"
type: "overview"
tags:
  - "hub"
  - "images"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "One concept for each image in versions.json: what it is, its track, its trust class, and its open issues and waivers."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Images overview

This bundle holds one concept for each image in the `images` map of `versions.json`. Each concept gives the track, the trust class, the enforcement, the variants and the special notes.

Do not put a pin, a digest or the current version here. Read them in `versions.json`. Do not put a waiver here. Give its id and read it in `.github/pdp/exceptions.yaml`.

## Find concepts

* List this bundle: read `.okfw/images/index.md`.
* Search the images: `okfw search "<words>" --type image`.
* Find an image group: `okfw search "<words>" --tag ory` or `--tag dapr`.

## Add a concept

1. Add the image to `versions.json` first. Follow the procedure for a new upstream. See [Operations overview](/operations/operations-overview--01a1837da594.md).
2. Run `okfw create "<image>" --type image --path images -d "<one sentence>" --tags image,<image>,<mirror|build>`.
3. Add a row for the new image to the table below.
4. Obey the [wiki conventions](/guides/wiki-conventions--01a1837da62e.md) and [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Concepts

The enforcement column shows a state that can change. See `versions.json` for the current value. The values below are from 2026-10-28.

| Image | Track | Trust class | Enforcement (2026-10-28) | Group |
|---|---|---|---|---|
| [traefik](/images/traefik--01a183832cbc.md) | mirror | `dhi` | `enforce` | |
| [postgres](/images/postgres--01a183832d06.md) | mirror | `dhi` | `enforce` | |
| [nexus3](/images/nexus3--01a183832d26.md) | mirror | `none` | `observe` | |
| [mssql](/images/mssql--01a183832d44.md) | mirror | `notation` | `observe` | |
| [whoami](/images/whoami--01a183832d61.md) | mirror | `none` | `observe` | |
| [kratos](/images/kratos--01a183832d7f.md) | build | `internal` | `enforce` | Ory |
| [hydra](/images/hydra--01a183832d9f.md) | build | `internal` | `enforce` | Ory |
| [keto](/images/keto--01a183832dc0.md) | build | `internal` | `enforce` | Ory |
| [oathkeeper](/images/oathkeeper--01a183832de0.md) | build | `internal` | `enforce` | Ory |
| [nats](/images/nats--01a183832e00.md) | build | `internal` | `enforce` | NATS |
| [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md) | build | `internal` | `enforce` | NATS |
| [daprd](/images/daprd--01a183832e23.md) | build | `internal` | `enforce` | Dapr |
| [dapr-placement](/images/dapr-placement--01a183832e48.md) | build | `internal` | `enforce` | Dapr |
| [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md) | build | `internal` | `enforce` | Dapr |
| [prometheus](/images/prometheus--01a183832e94.md) | build | `internal` | `enforce` | Observability |
| [loki](/images/loki--01a183832eba.md) | build | `internal` | `observe` | Observability |
| [seaweedfs](/images/seaweedfs--01a183832ee2.md) | build | `internal` | `observe` | Storage |

The trust class of a built image is `internal`, because the upstream signature that we verify is the signature of our `ubi9-micro` base. The vendor image of the binary cross-check has its own trust class, given in each concept.

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md): what `observe` means.
