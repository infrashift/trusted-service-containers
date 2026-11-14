---
id: "01a1dbce-4e47-71b7-8fc6-4595f486c88e"
title: "keto-cue"
type: "image"
tags:
  - "image"
  - "keto-cue"
  - "build"
  - "first-party"
created: "2026-11-14T14:44:53-06:00"
timestamp: "2026-11-14T14:44:59-06:00"
description: "The infrashift fork of Ory Keto with CUE permission schemas, built first-party from a pinned infrashift commit onto ubi9-micro."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-11-14T14:44:59-06:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/keto-cue.Containerfile"
    title: "keto-cue.Containerfile"
---

# keto-cue

keto-cue is the infrashift fork of Ory Keto that reads permission schemas in CUE. We build it from our own pinned commit, and no vendor image of it exists.

## Track

Build track. We compile `keto` from the pinned `sources.keto-cue` commit onto our `ubi9-micro` base, with `Containerfiles/keto-cue.Containerfile`. See [Build track](/architecture/build-track--01a18382f2d2.md).

keto-cue publishes no release tags. Thus `sources.keto-cue.ref` is the Go pseudo-version of the pinned commit, and the track admits only that shape. `scripts/drift-upstream.sh` finds no tag to propose. A person bumps `commit` and `ref` together, in a reviewed pull request.

keto-cue is not in the Ory lockstep group. Its source is not `sources.ory`.

## Trust class and provenance mode

`internal`. The upstream signature that we verify is the signature of our `ubi9-micro` base. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

The entry declares `firstParty`, because infrashift is the only publisher of keto-cue. No binary cross-check runs. The pipeline records the hash of our binary as the observation `FIRST_PARTY_BUILD`. See [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md).

## Enforcement

See `versions.json` for the current value. On 2026-11-14 the value was `observe`.

## Variants and platforms

One variant, `runtime`. Architectures: `amd64`, `arm64`. On 2026-11-14, only `amd64` was built locally.

## Runtime

* Ports: 4466 (read) and 4467 (write).
* Command: `keto serve`. The binary is `/usr/bin/keto`.
* User: 1001, group 0, home `/home/ory`, with tzdata.
* Build: `CGO_ENABLED=0`, `-trimpath`, `-tags=json1`, `-s -w`, `GOTOOLCHAIN=local`. The ldflags stamp the version, the commit and the date into `github.com/ory/keto/internal/driver/config`.
* The CUE base schema is compiled into the binary. The image has no CUE file. Mount your `namespaces.cue` and set `namespaces.location` to it.

## Smoke tests on 2026-11-14

We ran these tests on the local amd64 image:

1. `keto version` gave the pseudo-version `ref` and the full pinned commit.
2. `keto namespace validate` accepted a sample schema with three namespaces and a permission. It rejected a schema that names an undeclared namespace, with the line and the column.
3. `keto migrate up --yes` applied all migrations to a SQLite file in `/home/ory`. The SQLite driver is pure Go, so the CGO-free build works.
4. `keto serve` on that database answered `/health/ready`. A written relation tuple gave `allowed: true` through a CUE permission, and another subject gave `allowed: false`.

## Issues

* [The keto-cue pin has a Critical and 13 fixable High Go module findings](/issues/the-keto-cue-pin-has-a-critical-and-13-fixable-high-go-module-findings--01a1dbce4e57.md)

## Related

* [keto](/images/keto--01a183832dc0.md): the Ory image that keto-cue replaces for HALO.
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Required labels on built images](/architecture/required-labels-on-built-images--01a18382f2eb.md)
* [Images overview](/images/images-overview--01a1837da526.md)
