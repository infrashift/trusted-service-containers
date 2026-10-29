---
id: "01a18383-da2e-74ab-b374-3a51d448e424"
title: "Re-pin a toolchain"
type: "runbook"
tags:
  - "runbook"
  - "toolchain"
  - "pin"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:42-05:00"
description: "Move a Go toolchain pin to the current patch release, record goVersion, and rebuild every image that compiles with it."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:42-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/76d0c0f"
    title: "go1.26 1.26.6 to 1.26.9 (2026-10-13)"
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/729c0e8"
    title: "Base and go1.26 re-pin (2026-10-28)"
---

# Re-pin a toolchain

This runbook moves a Go toolchain pin in the `toolchains` map of `versions.json` to the current patch release. A toolchain sits on a rolling tag, for example `1.26-trixie`. Go security releases move the digest behind that tag.

A `stdlib` finding on a build leg comes from our compiler. It does not come from the source or the base. Re-pin the toolchain to clear it.

## Examples

* Commit `76d0c0f` (2026-10-13) moved go1.26 from 1.26.6 to 1.26.9. PR #29's review had shown one Critical and seven fixable Highs in `stdlib`. The pin had stayed on 1.26.6 for five days after the fix. The commit also changed `GOTOOLCHAIN` of nats to `local`, and made the Containerfile lint reject a version string.
* Commit `729c0e8` (2026-10-28) re-pinned a base and moved go1.26 to 1.26.10 at the same time. The base change rebuilt every image, so the commit took the current compiler too.

## What watches the toolchain

* `scripts/drift-upstream.sh` re-pins a moved toolchain each day and writes `goVersion`. See [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md).
* `make -f Ops.mk verify-build-pins` fails if the rolling tag moved, or if the pinned digest ships a Go version other than `goVersion`.

Before 2026-10-13, nothing watched the toolchains.

## Procedure

WARNING: Do not set `GOTOOLCHAIN` to a version string. If you do, Go downloads that compiler and ignores the new toolchain image. Use `local`.

1. Create a branch from `main`.
2. Run `make -f Ops.mk verify-build-pins`. Read the toolchain lines.
3. Read https://go.dev/doc/devel/release to see what the new patch fixes.
4. Set the new per-architecture digests in `toolchains.<name>` in `versions.json`. Or take them from the drift proposal on `automation/upstream-drift`.
5. Set `goVersion` to the patch version that the new digests ship.
6. Run `make -f Ops.mk verify-build-pins` again. Make sure that each architecture shows `current`.
7. Run `make -f Ops.mk validate`.
8. Open a pull request.
9. Make sure that the build runs every image that uses the toolchain. Check 11 of `scripts/lint-workflows.sh` holds `build.yml` to this rule.
10. Read the review comment. Blocking must be 0, or the pull request must say why `quarantine/` is the correct result.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md)
* [Re-pin a base image](/operations/re-pin-a-base-image--01a18383da79.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md)
