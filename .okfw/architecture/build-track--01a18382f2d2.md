---
id: "01a18382-f2d2-779c-b8ab-e40475dcd46d"
title: "Build track"
type: "component"
tags:
  - "architecture"
  - "build"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "How the build track compiles a pinned source commit onto our ubi9-micro base, and what each of the three Containerfile stages does."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/tree/main/Containerfiles"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/fetch-source.sh"
    title: "fetch-source.sh"
---

# Build track

The build track compiles each image from a pinned source commit onto our own `ubi9-micro` base. We use it when no official UBI variant of the image exists.

## Why we build

The Ory services, NATS and Dapr publish only distroless, Alpine and Windows variants. We verified that no official UBI variant exists. We did not assume it. The later images (Prometheus, Loki, SeaweedFS and the NATS exporter) have the same problem. Their vendor image is Alpine, Debian or distroless, or their UBI image needs an entitled pull. All these services are static Go binaries with `CGO_ENABLED=0`. Thus we build them from a pinned source commit, not from a tag.

## Images on the build track

| Group | Images | Source |
|---|---|---|
| Ory, lockstep | [kratos](/images/kratos--01a183832d7f.md), [hydra](/images/hydra--01a183832d9f.md), [keto](/images/keto--01a183832dc0.md), [oathkeeper](/images/oathkeeper--01a183832de0.md) | `sources.ory` |
| NATS | [nats](/images/nats--01a183832e00.md), [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md) | `sources.nats`, `sources.prometheus-nats-exporter` |
| Dapr, lockstep | [daprd](/images/daprd--01a183832e23.md), [dapr-placement](/images/dapr-placement--01a183832e48.md), [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md) | `sources.dapr` |
| Observability | [prometheus](/images/prometheus--01a183832e94.md), [loki](/images/loki--01a183832eba.md) | `sources.prometheus`, `sources.loki` |
| Storage | [seaweedfs](/images/seaweedfs--01a183832ee2.md) | `sources.seaweedfs` |
| infrashift, first-party | [keto-cue](/images/keto-cue--01a1dbce4e47.md), [chit](/images/chit--01a1dbd53dc3.md) | `sources.keto-cue`, `sources.chit` |

"Lockstep" means that one source tag produces all the images of the group. A partial bump is a defect. The drift workflow must propose all images of the group together.

## The three stages of a Containerfile

Each file in `Containerfiles/` has three stages. Each stage exists for a verified reason.

| Stage | From | What it does |
|---|---|---|
| `builder` | the pinned toolchain image | Compiles the pinned source commit with the flags of the vendor release pipeline, not the flags of the upstream development Dockerfile. |
| `certs` | the pinned `ubi9-minimal` | Gives the CA trust bundle. `ubi9-micro` has no CA trust paths, so each outbound TLS call fails without it. |
| runtime | the pinned `ubi9-micro` | Holds the binary. It has `bash` and coreutils but no package manager. |

The runtime stage does these steps:

1. Copy the CA bundle from `certs`.
2. Assert that the CA bundle is larger than 100000 bytes. Then a truncated bundle fails the build.
3. Copy the zoneinfo files from the toolchain image, because `ubi9-micro` has none. Without them, `time.LoadLocation()` fails for all zones except UTC.
4. Append a passwd entry for UID 1001 in group 0. `ubi9-micro` has no `useradd`.
5. Set group 0 on the writable paths.
6. Run `chmod g=u` on the writable paths. Then the image runs under the OpenShift arbitrary-UID SCC.
7. Run as `USER 1001`. Each port is above 1024, so the user needs no capability to bind it.

## First-party images

Some images are our own infrashift services. No vendor publishes them, so no vendor binary exists for the cross-check. Their entries declare `firstParty` with a reason in place of `crosscheck`:

```json
"firstParty": { "noVendorBinary": true, "reason": "<why no vendor binary exists>" }
```

1. Declare `firstParty` only for a source under `https://github.com/infrashift/`. The repo gate and the PDP deny it for any other source.
2. Do not delete `crosscheck` to get this mode. An entry without both blocks fails the schema and the repo gate.
3. Do not put crosscheck ARGs or the `io.infrashift.build.crosscheck.image` label in the Containerfile. `scripts/lint-containerfiles.sh` rejects them.

The pipeline records the hash of our binary as the observation `FIRST_PARTY_BUILD`.

A program without a version variable cannot get an `-X` stamp. The Go linker ignores `-X` for a symbol that does not exist. For such a program, set `build.noVersionSymbol` to the reason and set `ldflagsVars` to `{}`. The schema accepts an empty `ldflagsVars` only with that reason, and `scripts/lint-containerfiles.sh` then rejects any `-X`. Chit uses this. See [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md).

## Smoke tests

Each builder stage runs the new binary once, for example with `--version` or `--help`. This test finds a binary that links but does not run. For example, `daprd` without its component tag compiles, but it panics at its first start. Some smoke tests also compare the version output with the expected value. They capture the output and do not pipe it into `grep -q`, because SIGPIPE under `pipefail` fails the build.

## Source fetch

`scripts/fetch-source.sh` fetches the pinned commit, not the tag, and asserts that the tag resolves to that commit. Some upstreams stamp a short commit whose length git chooses dynamically. A shallow clone gives a shorter value, so `versions.json` pins `shortCommit` as data.

## Related

* [Required labels on built images](/architecture/required-labels-on-built-images--01a18382f2eb.md)
* [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md)
* [Pins and tracks in versions.json](/architecture/pins-and-tracks-in-versions-json--01a18382f304.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md): the binary cross-check against the vendor image.
* [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md): the mode for our own services.
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Eight build Containerfiles say that fetch-source.sh removes .git](/issues/eight-build-containerfiles-say-that-fetch-source-sh-removes-git--01a18395b4ba.md)
