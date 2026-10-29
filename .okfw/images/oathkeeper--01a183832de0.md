---
id: "01a18383-2de0-79f3-815a-8ab0c96fb007"
title: "oathkeeper"
type: "image"
tags:
  - "image"
  - "oathkeeper"
  - "ory"
  - "build"
created: "2026-10-28T12:16:14-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "Ory Oathkeeper, the identity and access proxy, built from the pinned Ory source onto ubi9-micro in lockstep with the Ory images."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/oathkeeper.Containerfile"
    title: "oathkeeper.Containerfile"
---

# oathkeeper

oathkeeper is Ory Oathkeeper, the identity and access proxy. We build it from source, because no official UBI-based Ory image exists.

## Track

Build track. We compile `oathkeeper` from the pinned `sources.ory` commit onto our `ubi9-micro` base, with `Containerfiles/oathkeeper.Containerfile`. Ory publishes no UBI-based image. See [Build track](/architecture/build-track--01a18382f2d2.md).

One shared tag releases the four Ory images in lockstep. The source track is the v26 release line. A partial bump is a defect. `drift-upstream.yml` must propose all four images together.

## Trust class

`internal`. The upstream signature that we verify is the signature of our `ubi9-micro` base, against the release key of `infrashift/trusted-base-images`. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

The binary cross-check compares our binary with the binary in `docker.io/oryd/oathkeeper`, trust class `none`, tier `best-effort`. Ory signs with cosign, but the signature has `Cert: false` and `Chain: false`, and Ory publishes no public key. Thus we pin the vendor image by digest and do not claim to verify it. See [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md).

## Enforcement

See `versions.json` for the current value. On 2026-10-28 the value was `enforce`.

## Variants and platforms

One variant, `runtime`. Architectures: `amd64`, `arm64`.

## Runtime

* Ports: 4455 and 4456.
* Command: `oathkeeper serve`.
* User: 1001, with tzdata.
* Build: `CGO_ENABLED=0`, `-tags=json1`, `-s -w`. The ldflags stamp the version, the commit and the date.

## Notes

* Oathkeeper stamps its version into the package `x`, not into driver/configuration. Its `.goreleaser.yml` confirms this. If the path is wrong, the build does not fail. The binary compiles and reports `dev`.
* The upstream .docker/Dockerfile-build has a defect in its `COPY` of the `go.sum` files. We do not use it.

## Issues and waivers

Open issues:

* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md)
* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [Eight build Containerfiles say that fetch-source.sh removes .git](/issues/eight-build-containerfiles-say-that-fetch-source-sh-removes-git--01a18395b4ba.md)

Resolved issues:

* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md)
* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md)
* [The ubi9-micro base pins were behind the sibling repository on 2026-10-14](/issues/the-ubi9-micro-base-pins-were-behind-the-sibling-repository-on-2026-10-14--01a1838a1439.md)

Waivers (see `.github/pdp/exceptions.yaml` for the entries):

* [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md)
* [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md)

Measurements:

* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [The first Ory scans found vendored Go findings in all four images on 2026-08-24](/findings/the-first-ory-scans-found-vendored-go-findings-in-all-four-images-on-2026-08-24--01a1838a6e4f.md)

## Related

* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Required labels on built images](/architecture/required-labels-on-built-images--01a18382f2eb.md)
* [Images overview](/images/images-overview--01a1837da526.md)
