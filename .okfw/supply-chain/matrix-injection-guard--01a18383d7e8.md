---
id: "01a18383-d7e8-76d3-b089-cf45057f0544"
title: "Matrix injection guard"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "injection-guard"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The jq schema check on build-matrix.json, byte-identical in build.yml, review.yml and release.yml, and the lint check that keeps the three copies equal."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
    title: "build.yml"
---

# Matrix injection guard

The matrix injection guard is a `jq -e` schema check on `build-matrix.json`. The same guard, byte for byte, is in `build.yml`, `review.yml` and `release.yml`. If one copy differs, that trust boundary has no guard, and nothing else shows it.

## Why the guard exists

`build-matrix.json` crosses a trust boundary three times. The build workflow makes it from the pull request head. On a fork pull request, its values come from `versions.json` keys that an attacker controls. The values then go into `run:` blocks in all three workflows.

## What the guard checks

* The matrix is an array of 1 to 64 objects.
* `kind` is `mirror` or `build`.
* `service` and `variant` match `^[a-z0-9][a-z0-9._-]{0,63}$`.
* `leg` matches `^[a-z0-9][a-z0-9._-]{0,127}$` and is equal to the service, a hyphen, and the variant.
* `trust_class` is one of `dhi`, `none`, `internal`, `notation`.
* A build leg has exactly the keys `arch`, `kind`, `leg`, `service`, `trust_class`, `variant`, and `arch` is `amd64` or `arm64`.
* A mirror leg has exactly the keys `kind`, `leg`, `service`, `trust_class`, `variant`.

The guard uses one regex for each field. It does not use one character set for all fields. The upstream repository `sonatype/nexus3` contains a slash. One shared character set that allows a slash would weaken every field.

## How the lint enforces it

Check 3 of `scripts/lint-workflows.sh` extracts the guard from each of the three files. It removes leading spaces and empty lines, and compares the SHA-256 hashes. If one hash differs, or the build hash is empty, the lint fails.

WARNING: If you change the guard, change all three copies in the same commit. The lint fails on any difference.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [Workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md)
* [Check 3 of lint-workflows.sh has a dead empty-hash test](/issues/check-3-of-lint-workflows-sh-has-a-dead-empty-hash-test--01a18395b612.md)
