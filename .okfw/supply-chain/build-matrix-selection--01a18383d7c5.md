---
id: "01a18383-d7c5-7da7-b06e-bc0ef11ee80b"
title: "Build matrix selection"
type: "component"
tags:
  - "supply-chain"
  - "build"
  - "matrix"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "How build.yml selects the legs to rebuild, and why a change to scripts/, the PDP, tools.lock or rootfs/ rebuilds every image."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
    title: "scripts/lint-workflows.sh (check 11)"
---

# Build matrix selection

The `Compute Matrix` job of `build.yml` selects the legs that a pull request rebuilds. A change to policy, orchestration or a shared input rebuilds every image. Other changes rebuild only the legs that they affect.

## The rules, in order

1. **Policy or orchestration changed: full matrix.** If the diff touches `scripts/`, `.github/pdp/`, `review.yml`, `release.yml`, `tools.lock` or `rootfs/`, every leg runs. The job prints `policy/orchestration changed -> full matrix`. A gate result is valid only for the policy and the scripts that made it.
2. **An image entry changed: those legs.** The job compares each image entry in `versions.json` with the base branch as a whole object. A new field cannot pass without a rebuild.
3. **A referenced pin changed: every image that references it.** A build-track image refers to a `source`, a `toolchain`, a `base` and a `caSource` entry. A change to one of them selects the image. A toolchain bump thus rebuilds every Go image that uses it.
4. **Only a Containerfile changed: the legs that own it.** The job maps `Containerfiles/<service>.Containerfile` to the service.
5. **Nothing matched: full matrix.** If no rule selects a leg, the job selects every leg.

The job intersects the result with the list of all legs, so a deleted entry cannot come back.

## Why rule 3 exists

Before rule 3, a toolchain bump that also touched one image entry rebuilt only that image. Every other Go image kept the vulnerable compiler. The pull request was green, because the legs that would fail did not run.

Check 11 of `scripts/lint-workflows.sh` extracts the `CHANGED` jq expression from `build.yml` and runs it against a fixture. It checks five cases: toolchain plus one image, base only, CA donor only, one source only, and nothing.

## Legs

| Track | One leg is | Matrix fields |
|---|---|---|
| mirror | one service and one variant, over the full multi-arch index | `kind`, `service`, `variant`, `leg`, `trust_class` |
| build | one service and one architecture, variant `runtime` | the same fields plus `arch` |

The value of `leg` is always the service, a hyphen, and the variant. The job writes the result to `build-matrix.json`, then checks it with the [matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md).

## Analysis

A change to a shared input costs a full rebuild of all images. A pull request that changes only `.okfw/`, `docs/` or `.ai/` starts no build. A change to `scripts/`, for example a fix to `scripts/lint-skills.sh`, rebuilds all images. Plan such a fix together with other work that rebuilds all images.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [Matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md)
* [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md)
* [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md)
* [Re-pin a base image](/operations/re-pin-a-base-image--01a18383da79.md)
