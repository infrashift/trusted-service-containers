---
id: "01a18395-b56b-797c-9fd7-7110dad4c67d"
title: "The notes in versions.json are stale"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "docs"
  - "pins"
  - "loki"
  - "prometheus"
  - "seaweedfs"
created: "2026-10-28T12:36:29-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "The versions.json _comment describes placeholder digests that no longer exist, and the loki, prometheus and seaweedfs notes name older versions."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
    title: "Ops.mk"
---

# The notes in versions.json are stale

## Problem

Some notes in `versions.json` are stale. The top `_comment` describes placeholder digests that no longer exist. The notes of loki, prometheus and seaweedfs name older versions than their current source refs.

## Context

On 2026-10-28:

* The `_comment` says that digests marked with an all-zero value need an authenticated `dhi.io` login, see `SETUP-ENVIRONMENTS.md` step 7. No pin in `versions.json` has the all-zero value. The only match is the `_comment` itself.
* The `_comment` also says that the other digests "were resolved live on 2026-08-18". Many pins changed after that date.
* The loki notes say that the ldflags are those of the upstream Makefile at v3.7.8, and that the vendor binary reports 3.7.8. The loki source ref was v3.7.9.
* The prometheus notes say that the binaries and ldflags are those of `.promu.yml` at v3.15.0, and that promu stamps 3.15.0. The prometheus source ref was v3.15.1.
* The seaweedfs notes say that the ldflags are those of the upstream release workflow at 4.48. The seaweedfs source ref was 4.51.
* The loki and seaweedfs notes say that the toolchain "has since moved to 1.26.9". On 2026-10-28, `toolchains.go1.26.goVersion` was 1.26.10.
* The `verify-mirror-pins` target in `Ops.mk` still has a branch for the all-zero placeholder digest.

## Acceptance criteria

- [ ] The `_comment` in `versions.json` does not describe placeholder digests.
- [ ] Each note that names an upstream version names the version of the current ref, or names no version.
- [ ] A note that refers to the toolchain refers to `toolchains.go1.26.goVersion` and does not name a patch.

## Analysis

* The notes possibly still describe the build correctly. A bump inside the track usually keeps the same ldflags. But a reader cannot tell if somebody checked the notes at the new version.
* A change to the note of a source rebuilds each image that uses that source. A change to `_comment` alone matches no selection rule, so the build runs every leg. See [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md). Do this fix with the next bump of these images.

## Related

* [Pins and tracks in versions.json](/architecture/pins-and-tracks-in-versions-json--01a18382f304.md)
* [loki](/images/loki--01a183832eba.md)
* [prometheus](/images/prometheus--01a183832e94.md)
* [seaweedfs](/images/seaweedfs--01a183832ee2.md)
* [The four DHI digests and attestationRepo were placeholders](/issues/the-four-dhi-digests-and-attestationrepo-were-placeholders--01a1838a1552.md)
* [Bump an upstream source within its track](/operations/bump-an-upstream-source-within-its-track--01a18383da54.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
