---
id: "01a18383-d6f4-708b-b1b7-d5d5f5770e74"
title: "CI Build & Audit workflow"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "build"
created: "2026-10-28T12:16:57-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The build.yml workflow mirrors or builds each selected leg as Build-Actor, scans and signs it, and reports one aggregate build/gate check."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
    title: "scripts/mirror-leg.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/build-leg.sh"
    title: "scripts/build-leg.sh"
---

# CI Build & Audit workflow

The `CI Build & Audit` workflow (`.github/workflows/build.yml`) makes the image for each selected leg. It mirrors or builds the image, scans it, signs the evidence, and pushes it to `development/`. It is the only producer of images for both tracks.

## Trigger and actor

| Item | Value |
|---|---|
| Trigger | `pull_request` to `main`, filtered by `paths:` |
| Environment | `Build-Actor` for the two leg jobs |
| Top-level permissions | `permissions: {}` |
| Concurrency | One run for each pull request. A new push cancels the old run. |

The `paths:` filter lists these paths: `versions.json`, `Containerfiles/**`, `rootfs/**`, `scripts/**`, `tools.lock`, `.github/pdp/**`, `review.yml`, `release.yml` and `build.yml`. A change to the gate or to the promotion logic must check every leg again. If not, the verdict on file comes from different rules.

## Jobs

| Job | Runner | What it does |
|---|---|---|
| `Compute Matrix` | `ubuntu-latest` | Selects the legs and checks the matrix. See [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md). |
| `Mirror <leg>` | `ubuntu-latest` | Runs `scripts/mirror-leg.sh` for one mirror-track leg. |
| `Build <leg> (<arch>)` | native `amd64` or `arm64` | Runs `scripts/build-leg.sh` for one build-track leg and one architecture. |
| `build/gate` | `ubuntu-latest` | Aggregates the results into one check. |

## Mirror legs

A mirror leg always runs on an `amd64` runner. `syft` and `grype` read the layers and do not execute them, so an `amd64` runner can scan an `arm64` manifest. `scripts/mirror-leg.sh` does these steps:

1. Load the pin from `versions.json`. Stop if the digest is malformed or a zero placeholder.
2. Verify the upstream signature for the trust class.
3. Copy the full index by digest to `development/`, with its referrers.
4. Make sure that the copy has the same digest as the pin.
5. Scan each platform manifest, and write the evidence files.
6. Sign each evidence file, then sign a checksum file of all of them.

## Build legs

A build leg runs on a runner of its own architecture, because `buildah` executes the `RUN` steps. `scripts/build-leg.sh` does these steps:

1. Read the source, base, CA donor and toolchain pins from `versions.json`. The source ref must be a 40-hex commit.
2. Fetch the source at the pinned commit.
3. Verify the base image.
4. Build the image with `buildah`.
5. Make sure that the five required labels are present and not empty.
6. Run the dual-provenance cross-check. It is an observation, not a gate.
7. Scan the image, and write the SLSA provenance.
8. Sign, checksum and attest. The script does not pass `--replace` to `cosign attest`.

## Logins

Each login depends on the trust class of the leg. A Docker Hub problem does not stop a leg that does not use Docker Hub. See [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md).

## The aggregate check

The `build/gate` job runs with `if: always()`. It fails if `Compute Matrix` or a leg job has a result other than `success` or `skipped`.

Do not make one matrix leg a required check. Job names change with the matrix. A required context that stops reporting blocks every pull request.

## Why one workflow for both tracks

One workflow makes images for both tracks, by design. With two producer workflows, two review runs would write the same `review/cve-policy` status. The status of the last run would replace the other status. The release workflow would have to match two build runs. When no build run exists, the release workflow ends with no release. That rule works only with one producer workflow that has a path filter.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [Matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md)
* [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md)
* [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md)
