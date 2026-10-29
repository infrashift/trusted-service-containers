---
id: "01a18383-d8bc-77ee-a697-6e6de63a81a4"
title: "Containerfile policy"
type: "component"
tags:
  - "supply-chain"
  - "containerfile"
  - "build-track"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The rules for build-track Containerfiles that the lint enforces: three stages, ARGs after the runtime FROM, five labels, non-root, no digests."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-containerfiles.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/nats.Containerfile"
    title: "An example Containerfile"
---

# Containerfile policy

These rules apply to the Containerfiles of the build track, in `Containerfiles/`. `scripts/lint-containerfiles.sh` enforces them. It also compares each runtime declaration with `versions.json`.

Mirror-track images have no Containerfile and get no labels from this project. A label would change the digest.

## Shape

Each Containerfile has three stages. Each `FROM` pins its image by digest through a build arg.

| Stage | Content |
|---|---|
| `builder` | The Go toolchain. It compiles the source at the pinned commit. |
| `certs` | A `ubi9-minimal` donor for the CA trust bundle. |
| runtime | The trusted `ubi9-micro` base. |

The lint also checks that every Containerfile that `versions.json` declares exists, and that no Containerfile exists without an entry.

## Re-declare the ARGs after the runtime FROM

An `ARG` before the first `FROM` is a global build arg. It is not in scope inside a stage. If you do not declare `UPSTREAM_BASE` and `UPSTREAM_DIGEST` again after the last `FROM`, the labels expand to empty strings. The reference repository had this bug. The lint and the PDP rule `BUILD_LABEL_EMPTY` both catch it.

## What ubi9-micro does not have

A check of the layer showed three gaps. Every Containerfile compensates for them.

| Missing | Result | Fix |
|---|---|---|
| CA trust bundle | Every outbound TLS call fails with `x509: certificate signed by unknown authority`. | Copy the bundle from the `certs` stage, with the two usual symlinks and `SSL_CERT_FILE`. |
| tzdata | `time.LoadLocation()` fails for all zones except UTC. | Copy `/usr/share/zoneinfo` from the builder. |
| UID 1001 in `/etc/passwd` | `os/user` lookups fail, and `$HOME` is not set. | Append the entry. There is no `useradd`, because the image has no shadow-utils. |

The image has `bash` and coreutils, so `RUN` works and smoke tests in the image are possible. Only the package manager is absent.

Make sure that the copied CA bundle has more than 100000 bytes (`-gt 100000`). A truncated donor would give an image that fails TLS only in production.

## Non-root, group 0

`USER 1001` must be the last instruction. The passwd entry has GID 0, and owned directories get `chmod -R g=u`. Thus the image works under the arbitrary-UID SCC of OpenShift.

## Five required labels

The single `LABEL` instruction must set all five:

* `org.opencontainers.image.source`
* `org.opencontainers.image.revision`
* `org.opencontainers.image.version`
* `io.infrashift.image.upstream.digest`
* `io.infrashift.image.upstream.source`

The PDP denies a build leg without them (`BUILD_LABEL_MISSING`, `BUILD_LABEL_EMPTY`).

## No hardcoded digests

`versions.json` is the only place for a digest. The lint fails on a `sha256:` value in a Containerfile instruction. It checks the instructions only, not the comments, so a check cannot pass on its own documentation.

## Agreement with versions.json

The lint compares these items with the `runtime` and `build` blocks of the image entry:

* `EXPOSE`, `VOLUME`, `ENTRYPOINT` (exec form only) and `CMD`.
* `CGO_ENABLED=0`, the `-ldflags` symbols, `-trimpath`, `-tags`, the binary paths and the extra binaries.
* The release assets: if the source declares assets, the build must copy `src/.assets/<service>/`.

## The Go toolchain setting

`GOTOOLCHAIN` must be `local`, or equal to `go` plus the `goVersion` of the pinned toolchain. Any other version string makes `go` download that compiler and ignore the toolchain image. The lint fails on it.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Policy decision point](/supply-chain/policy-decision-point--01a18383d82e.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md)
* [Ops.mk validate targets](/supply-chain/ops-mk-validate-targets--01a18383d999.md)
* [Eight build Containerfiles say that fetch-source.sh removes .git](/issues/eight-build-containerfiles-say-that-fetch-source-sh-removes-git--01a18395b4ba.md)
