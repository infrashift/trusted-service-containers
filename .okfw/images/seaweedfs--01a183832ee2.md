---
id: "01a18383-2ee2-77fa-b725-0de8b144bdba"
title: "seaweedfs"
type: "image"
tags:
  - "image"
  - "seaweedfs"
  - "build"
created: "2026-10-28T12:16:14-05:00"
timestamp: "2026-10-28T12:23:41-05:00"
description: "The SeaweedFS object store with an S3 gateway, the replacement for MinIO, built from source onto ubi9-micro; it joined in observe mode."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:41-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/seaweedfs.Containerfile"
    title: "seaweedfs.Containerfile"
---

# seaweedfs

seaweedfs is the SeaweedFS object store: master, volume, filer and S3 gateway in one `weed` binary. It replaces MinIO as the S3 blob store of Sonatype Nexus.

## Track

Build track. We compile `weed` from the pinned `sources.seaweedfs` commit with `Containerfiles/seaweedfs.Containerfile`. The upstream tags have no leading `v`, and each release increments the minor version. Thus the source track is the whole 4.x line. See [Build track](/architecture/build-track--01a18382f2d2.md).

Since 2026-10-07, the MinIO public images return HTTP 401. The SeaweedFS vendor image is Alpine and unsigned. No UBI-based SeaweedFS exists.

## Trust class

`internal`. We verify our `ubi9-micro` base against the release key of `infrashift/trusted-base-images`. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

The binary cross-check compares our binary with the binary in `docker.io/chrislusf/seaweedfs`, trust class `none`, tier `best-effort`. The upstream builds without `-trimpath` on a floating Go patch. Thus a byte mismatch is expected and proves nothing. See [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md).

## Enforcement

See `versions.json` for the current value. On 2026-10-28 the value was `observe`.

On 2026-10-28, the seaweedfs legs had no blocking findings. Thus they went to `trusted/`, although the enforcement was `observe`. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

## Variants and platforms

One variant, `runtime`. Architectures: `amd64`, `arm64`. The upstream index also has 386 and arm/v7. We do not build them.

## Runtime

* Ports: S3 8333, filer 8888 (gRPC 18888), master 9333 (gRPC 19333), volume 8080 (gRPC 18080).
* Volume: /data. It holds the volume files, the master metadata and the filer store. Without a persistent mount, each restart loses all objects. Nothing shows the loss.
* Command: our command, not the upstream `mini`. It starts a single-node master, volume, filer and S3 gateway. The Iceberg and Lance REST endpoints are off.
* User: 1001.

WARNING: Without an `-s3.config` identity file, the S3 gateway allows anonymous access. A real deployment must give its own flags and an identity file.

## Notes

* The ldflags come from the upstream release workflow: `-s -w -extldflags -static`. `-trimpath` is ours. Only the commit is an ldflag. The build compiles the version number in from the source constants.
* The Containerfile checks the version output. This check finds an ldflags path that no longer matches. It also finds a ref whose source constants give a version that is different from the tag. The check captures the output and does not pipe it into `grep -q`.
* There are no build tags. This is the standard build, with a 30 GB volume size limit. The large-disk build writes volume files that a standard build cannot read. Thus a later change is a data migration, not only a rebuild.
* The image contains only the Go `weed` binary. The upstream image also has an optional Rust volume server and a maintenance worker.
* The smoke check runs `weed scaffold`. This command tests the flag parsing and the embedded templates without a port.
* Licence: Apache-2.0. We run it unmodified and internally.
* Consumer: `infrashift/ansible-collection-infrashift-hashistack`, terraform/live/nexus-uar.

## Issues and waivers

Open issues:

* [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md)
* [The notes in versions.json are stale](/issues/the-notes-in-versions-json-are-stale--01a18395b56b.md)

Resolved issues:

* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md)
* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md)
* [The ubi9-micro base pins were behind the sibling repository on 2026-10-14](/issues/the-ubi9-micro-base-pins-were-behind-the-sibling-repository-on-2026-10-14--01a1838a1439.md)

Waivers (see `.github/pdp/exceptions.yaml` for the entries):

* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md)

Measurements:

* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)

## Related

* [nexus3](/images/nexus3--01a183832d26.md): the consumer of the S3 store.
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Images overview](/images/images-overview--01a1837da526.md)
* [Bump an upstream source within its track](/operations/bump-an-upstream-source-within-its-track--01a18383da54.md)
