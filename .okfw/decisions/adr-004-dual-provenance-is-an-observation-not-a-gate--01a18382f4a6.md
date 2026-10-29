---
id: "01a18382-f4a6-7591-8637-38c0ef5a2dc8"
title: "ADR-004: Dual provenance is an observation, not a gate"
type: "decision"
tags:
  - "decision"
  - "dual-provenance"
  - "build"
created: "2026-10-28T12:16:00-05:00"
timestamp: "2026-10-28T12:50:11-05:00"
description: "ADR-004 records our binary hash next to the vendor hash, gates only that the comparison is done and well-formed, and never gates on the result."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:50:11-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/b4e833038557338c882ef72e90bd02b71d9aafab/docs/build-track/dual-provenance.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/binary-crosscheck.sh"
    title: "binary-crosscheck.sh"
x:
  adr: 4
---

# ADR-004: Dual provenance is an observation, not a gate

ADR-004 records the hash of each binary that we build next to the hash of the vendor binary. The policy gates that the comparison was done and is well-formed. It never gates on the result.

**Status:** Accepted, 2026-08-18.

WARNING: If a person proposes to make the cross-check a gate, first read this ADR and the nats measurement. The measurement is in [A nats binary built from source did not match the vendor binary on 2026-08-18](/findings/a-nats-binary-built-from-source-did-not-match-the-vendor-binary-on-2026-08-18--01a1838a6cfc.md). A gate needs reproducible builds. We measured, and we do not have them.

## Context

For each built image, we can compare our binary with the same binary in the official vendor image. A match would show that an independent builder got the same output from the published source. But Go builds are not reproducible here. Thus a mismatch is the expected result.

## Decision

For each built image, record two hashes:

* **A:** the sha256 of the binary that we compiled from the pinned source commit.
* **B:** the sha256 of the same binary, extracted from the official vendor image. `versions.json` pins the vendor image by a per-platform digest.

The pipeline writes both hashes to these places:

* `crosscheck.json`.
* The signed attestation `https://infrashift.io/attestation/binary-crosscheck/v1`.
* `runDetails.byproducts` of the SLSA predicate.
* The table of the PR comment.

The policy gates three properties only:

* The comparison was done (`DUAL_PROVENANCE_NOT_RECORDED`).
* Its fields are well-formed (`DUAL_PROVENANCE_MALFORMED`).
* It compared against the pinned reference (`DUAL_PROVENANCE_REFERENCE_UNPINNED`).

A mismatch does not fail the build. Do not add the result to `violations` in `.github/pdp/policies.rego`.

## Why the well-formed check matters

An early version of `scripts/binary-crosscheck.sh` used `buildah from --pull=always`. That command fails for an image in local storage. The script printed two empty strings and exited 0. The caller compared `""` with `""` and recorded a MATCH. Now the script asserts that both hashes match `^[0-9a-f]{64}$` before it writes them. `scripts/build-leg.sh` validates them again before the comparison.

## The measurement

On 2026-08-18, we tried to reproduce the vendor binary of `nats-server` v2.14.5. We matched each build input that `go version -m` shows. The inputs were the Go toolchain, the dependency set, `-trimpath`, `CGO_ENABLED`, `GOARCH`, `GOOS`, `GOAMD64`, `DefaultGODEBUG`, `mod`, the `vcs.*` fields and the 9-character short commit. The sha256 was still different. See [A nats binary built from source did not match the vendor binary on 2026-08-18](/findings/a-nats-binary-built-from-source-did-not-match-the-vendor-binary-on-2026-08-18--01a1838a6cfc.md) for the measured values.

The attempt found three real defects. Each defect was visible only when the comparison ran:

1. **The short commit had 7 characters, not 9.** goreleaser stamps `{{.ShortCommit}}`. Its length is the dynamic abbreviation that git calculates for the full repository. We clone with `--depth 1`, and git then abbreviates to the minimum of 7 characters. Thus the build cannot derive the correct value at build time. `versions.json` pins it as data, in `sources.<key>.shortCommit`. `Ops.mk` asserts that it is a prefix of the full commit. On a bump, `scripts/drift-upstream.sh` calculates it again in a full bare clone. A blobless clone (`--filter=blob:none`) sees fewer objects and gives a shorter value. For nats v2.14.7, it gave 8 characters, but the release binaries have 9.
2. **`scripts/fetch-source.sh` wrote its metadata inside the checkout.** The untracked files made Go stamp `vcs.modified=true`. Now the metadata goes to the ignored directory src/.meta, outside the checkout.
3. **`scripts/fetch-source.sh` deleted `.git`.** This removed the module version (`(devel)` instead of `v2.14.5`) and all `vcs.*` provenance. The script deleted `.git` because of a pseudo-version problem. Now the script keeps `.git` and fetches the tag. The tag solves the pseudo-version problem, and the script keeps the provenance.

The remaining difference is not visible in `go version -m`. Thus NATS has the tier `best-effort`, not `flag-matched`. If a person finds the remaining input, raise the tier again. All other built images also have the tier `best-effort`.

## What the comparison is worth

* **A match** would be meaningful. It would show that an independent builder made bit-identical output from the published source. We do not get a match for any image now.
* **A mismatch proves nothing alone.** It is the expected result.
* **A change in the relation is the real signal.** Investigate if a leg matched for a long time and then stops. Also investigate if the hashes change without a source change. Use the hashes to find changes over time.
* **It is the only independent check of an upstream whose signature we cannot verify.** For example, Ory publishes no public key for its keyed signature. If a vendor starts to publish verifiable signatures, we already have the history.

## The stronger anchor for NATS

The official NATS image does not compile the binary. Its Dockerfile downloads the GitHub release tarball and verifies a sha256 that the Dockerfile holds. Two independent places publish that value. On 2026-08-18, we confirmed that the tarball hash matches. We also confirmed that the binary in the official image is byte-identical to the binary in the tarball. This is a real supply-chain check, and it is worth more than the comparison from source. `versions.json` records the tarball hashes as `crosscheck.releaseTarballSha256`.

## Consequences

* The cross-check never blocks a release.
* The PR comment shows the result, with a note that a mismatch is expected.
* A toolchain bump can increase the difference from the vendor binary. We accept that, because the comparison is an observation. For example, NATS uses `GOTOOLCHAIN=local` to clear advisories that the vendor's Go version has.

## Related

* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md)
* [nats](/images/nats--01a183832e00.md)
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md): the `none` trust class.
* [Findings overview](/findings/findings-overview--01a1837da578.md): the measurement as a finding.
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [A nats binary built from source did not match the vendor binary on 2026-08-18](/findings/a-nats-binary-built-from-source-did-not-match-the-vendor-binary-on-2026-08-18--01a1838a6cfc.md)
* [Eight build Containerfiles say that fetch-source.sh removes .git](/issues/eight-build-containerfiles-say-that-fetch-source-sh-removes-git--01a18395b4ba.md)
