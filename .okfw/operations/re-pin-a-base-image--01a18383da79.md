---
id: "01a18383-da79-7ef3-8c80-c1d998559fc8"
title: "Re-pin a base image"
type: "runbook"
tags:
  - "runbook"
  - "base"
  - "pin"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:42-05:00"
description: "Move a base pin to the newest sibling release with drift-base.sh, check the toolchain at the same time, and rebuild every build-track image."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:42-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-base.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/0361ba8"
    title: "Re-pin ubi9-micro for pcre2 (2026-10-14)"
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/729c0e8"
    title: "Re-pin ubi9-minimal and go1.26 (2026-10-28)"
---

# Re-pin a base image

This runbook moves a base pin in the `bases` map of `versions.json` to the newest release of the sibling repository `infrashift/trusted-base-images`. A base change rebuilds every build-track image that uses the base.

## Examples

* Commit `0361ba8` (2026-10-14) moved `ubi9-micro` to a release that fixed three `pcre2` Highs. Those Highs were all six blocking findings per architecture of prometheus-nats-exporter.
* Commit `729c0e8` (2026-10-28) moved `ubi9-minimal`, the CA donor, to a new sibling release. The same commit moved the go1.26 toolchain, because the base change also rebuilt every image.

## Procedure

1. Create a branch from `main`.
2. Run `scripts/drift-base.sh`. It writes the per-architecture child digests of `:latest` into `versions.json`. The daily drift workflow makes the same edit on `automation/base-drift`.
3. Make sure that each new digest verifies against the release key of the sibling, `.github/pdp/public-keys/upstream/trusted-base-images-release.pub`. `scripts/build-leg.sh` does the same check.
4. Make sure that each new image reports its declared architecture.
5. Scan each new base. Look for High and Critical findings.
6. Check that the new base still lacks the CA bundle, tzdata and UID 1001. The Containerfiles compensate for these. See `SETUP-ENVIRONMENTS.md` §8.
7. Run `make -f Ops.mk verify-build-pins`. If a toolchain is stale, re-pin it in the same pull request. See [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md).
8. Run `make -f Ops.mk validate`.
9. Open the pull request. Make sure that the build runs every build-track image.
10. Read the review comment. Blocking must be 0, or the pull request must say why `quarantine/` is the correct result.

## Why rebuild with a current toolchain

A base change rebuilds every image. If the toolchain is stale, every image gets a superseded compiler. That is the same mistake that commit `76d0c0f` fixed.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Base Image Drift workflow](/supply-chain/base-image-drift-workflow--01a18383d780.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md)
* [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md)
