---
id: "01a18382-f31f-785c-aaa2-87379230a0c8"
title: "Toolchain pins"
type: "component"
tags:
  - "architecture"
  - "build"
  - "toolchain"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "Why the Go toolchain pin goes stale, why a stdlib finding is our compiler's, and why GOTOOLCHAIN is never a version string."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-upstream.sh"
    title: "drift-upstream.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
    title: "lint-workflows.sh (check 11)"
---

# Toolchain pins

A toolchain pin goes stale when Go releases a security fix. A `stdlib` finding on a build leg comes from our compiler, so re-pin the toolchain.

## Why the pin goes stale

Each entry in the `toolchains` map of `versions.json` points to a rolling tag of the Go image. Go security releases move that tag. The pin stays on the old digest until a person re-pins it. The field `goVersion` records the patch version. Thus a reviewer can read the version without a pull of the image.

Before 2026-10-13, nothing watched the toolchain pin. Now `scripts/drift-upstream.sh` and `make -f Ops.mk verify-build-pins` both watch it.

## A stdlib finding is our compiler's

A `stdlib` finding on a build leg comes from our compiler. It does not come from the source or from the base. To remove it, re-pin the toolchain:

1. Set the new toolchain digests in `versions.json`.
2. Record the new patch version in `goVersion`.

## Never set GOTOOLCHAIN to a version

WARNING: Do not set `GOTOOLCHAIN` to a version string. If you do, Go downloads that compiler and ignores the new toolchain image.

The build-track Containerfiles that set `GOTOOLCHAIN` set it to `local`. Then the compiler is exactly the pinned toolchain image. If a `go.mod` needs a newer Go, the build fails. It does not download an unpinned compiler. The NATS Containerfile records the reason. A version string there would keep each advisory that the toolchain bump must clear.

## A change rebuilds every image that uses it

A change to a toolchain, a base or a source rebuilds each image that refers to it. Check 11 of `scripts/lint-workflows.sh` holds `.github/workflows/build.yml` to this rule. Before that check existed, a toolchain bump that also changed one image entry rebuilt only that image. The other Go images kept the old compiler, and the PR stayed green.

## Related

* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Pins and tracks in versions.json](/architecture/pins-and-tracks-in-versions-json--01a18382f304.md)
* [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md): the PR #29 review showed eight `stdlib` findings per architecture.
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md)
