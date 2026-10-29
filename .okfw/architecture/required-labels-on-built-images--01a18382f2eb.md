---
id: "01a18382-f2eb-7088-a9d7-97ff0174d47b"
title: "Required labels on built images"
type: "component"
tags:
  - "architecture"
  - "build"
  - "labels"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The five labels that each built image must carry, and why the ARGs behind them must be declared again after the runtime FROM."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-containerfiles.sh"
    title: "lint-containerfiles.sh"
---

# Required labels on built images

Each built image must carry five labels. The PDP denies a built image if a label is missing, is empty, or disagrees with the pinned base digest.

## The five required labels

| Label | Value |
|---|---|
| `org.opencontainers.image.source` | The upstream source URL |
| `org.opencontainers.image.revision` | The pinned source commit |
| `org.opencontainers.image.version` | The source version |
| `io.infrashift.image.upstream.digest` | The digest of the base image |
| `io.infrashift.image.upstream.source` | The base image reference |

The set is `required_build_labels` in `.github/pdp/policies.rego`. A mirrored image gets none of these labels, because a label changes its digest. See [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md).

## Declare the ARGs again after the runtime FROM

WARNING: Declare each ARG again after the runtime `FROM`. An ARG before the first `FROM` is a global build argument. It is not in scope inside a stage, and the labels expand to empty strings.

The reference repository had this defect and had to correct it. Each file in `Containerfiles/` declares the ARGs again after the runtime `FROM`, with a comment that tells why.

## The checks

* `BUILD_LABEL_MISSING` denies if a required label is absent.
* `BUILD_LABEL_EMPTY` denies if a required label is present but empty. This is the usual symptom of an ARG that the Containerfile does not declare again.
* `BUILD_LABEL_DIGEST_DISAGREES` denies if `io.infrashift.image.upstream.digest` is not equal to the base digest that the build recorded.
* The policy also compares both values with the pin in `versions.json`.
* `scripts/lint-containerfiles.sh` finds the same defect before the build.

## Related

* [Build track](/architecture/build-track--01a18382f2d2.md)
* [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
