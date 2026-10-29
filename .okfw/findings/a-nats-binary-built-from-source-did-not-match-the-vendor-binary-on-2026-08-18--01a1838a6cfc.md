---
id: "01a1838a-6cfc-703f-be5d-5d6789c40405"
title: "A nats binary built from source did not match the vendor binary on 2026-08-18"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "dual-provenance"
  - "nats"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:48:14-05:00"
description: "We matched every input that go version -m shows for nats-server v2.14.5, and the binary hash still differed from the vendor binary."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:48:14-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/b4e833038557338c882ef72e90bd02b71d9aafab/docs/build-track/dual-provenance.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.ai/skills/dual-provenance.md"
    title: ".ai/skills/dual-provenance.md"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39 review comment"
---

# A nats binary built from source did not match the vendor binary on 2026-08-18

On 2026-08-18, we tried to build a `nats-server` v2.14.5 binary that is identical to the vendor binary. We matched every build input that `go version -m` shows, and the sha256 of the binary was still different.

## Source of the measurement

* The document `docs/build-track/dual-provenance.md`, added in `b00f854` (2026-08-18) and updated in `97e858c` (2026-09-30). Read the old text with `git show 97e858c:docs/build-track/dual-provenance.md`.
* The file is now a pointer. The decision is in [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md), and the measurement is in this finding.
* The cross-check compares two hashes. Hash A is the binary that we compile from the pinned source. Hash B is the same binary from the pinned vendor image.

## Inputs that matched

| Input | Result |
|---|---|
| Go toolchain | go1.26.5 on both sides |
| Dependency set | identical: 10 modules, identical hashes |
| `-trimpath` | true on both sides |
| `CGO_ENABLED`, `GOARCH`, `GOOS`, `GOAMD64` | `0`, `amd64`, `linux`, `v1` on both sides |
| `DefaultGODEBUG` | identical |
| `mod` | `v2.14.5` on both sides |
| `vcs.revision`, `vcs.time`, `vcs.modified` | identical, `modified=false` |
| Embedded short commit | `d3bc04533` (9 characters) on both sides |
| **sha256 of the binary** | **different**: A `f2b1d11e…`, B `e1a2f9ba…` |

## Defects that the measurement found

To get this far, three defects had to be fixed. Each one showed only when the comparison ran.

1. The short commit had 7 characters, not 9. A `--depth 1` clone gives the shortest abbreviation. `versions.json` now pins `shortCommit`, and `Ops.mk` asserts that it is a prefix of the full commit.
2. `scripts/fetch-source.sh` wrote metadata inside the checkout. Go then stamped `vcs.modified=true`. The metadata now goes to a directory outside the checkout.
3. `scripts/fetch-source.sh` deleted `.git`. The binary lost the module version and all `vcs.*` data. The script now keeps `.git`.

An earlier version of `scripts/binary-crosscheck.sh` also printed two empty strings, and the caller recorded a `MATCH`. The script now asserts that each hash has 64 hex characters.

## Result

* The remaining difference is not visible in `go version -m`.
* `versions.json` records nats with the `reproducibilityTier` value `best-effort`, not `flag-matched`.
* On 2026-08-18, the vendor release tarball hash for nats matched the hash in the `nats-docker` Dockerfile. The binary in the vendor image was byte-identical to the tarball. Commit `9600a87` (2026-10-28) records the same check for v2.14.9.

## Later observation

On 2026-10-28, the review of PR #39 listed the cross-check for 24 build legs. No leg matched, and every leg had the tier `best-effort`. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

## Related

* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [nats](/images/nats--01a183832e00.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md)
