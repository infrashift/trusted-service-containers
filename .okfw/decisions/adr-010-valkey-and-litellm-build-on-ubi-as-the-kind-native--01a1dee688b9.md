---
id: "01a1dee6-88b9-7013-b76f-4611260f87b0"
title: "ADR-010: Valkey and LiteLLM build on UBI as the kind native"
type: "decision"
tags:
  - "decision"
  - "build"
  - "native"
  - "python"
  - "litellm"
  - "valkey"
  - "p-tsc-4"
created: "2026-11-15T05:10:12-06:00"
timestamp: "2026-11-15T07:02:21-06:00"
description: "Accepted: Valkey (C) and LiteLLM (Python) build on UBI as the new kind native, from a pinned commit or a hash-locked wheel set; Ollama moved to ADR-011."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
    title: "scripts/mirror-leg.sh"
  - resource: "https://github.com/valkey-io/valkey"
    title: "Valkey"
  - resource: "https://github.com/BerriAI/litellm"
    title: "LiteLLM"
  - resource: "https://github.com/valkey-io/valkey-hashes"
    title: "valkey-hashes"
  - resource: "https://pypi.org/project/litellm/"
    title: "LiteLLM on PyPI"
x:
  adr: 10
  answers: "P-TSC-4 (HALO PLAN.md section 7), for Valkey and LiteLLM"
  accepted: "2026-11-15"
---

# ADR-010: Valkey and LiteLLM build on UBI as the kind native

Valkey (C) and LiteLLM (Python) are built in this repository on UBI, as a new image kind, `native`. Valkey compiles from a pinned source commit. LiteLLM installs a hash-locked set of wheels onto the Python 3.12 of UBI. Ollama is not part of this decision: see [ADR-011: Ollama mirrors the DHI CUDA image in observe](/decisions/adr-011-ollama-mirrors-the-dhi-cuda-image-in-observe--01a1df4d8a41.md).

**Status:** Accepted, 2026-11-15, for Valkey and LiteLLM. On 2026-11-15 the owner decided that LiteLLM is built in this repository, not mirrored from DHI ("You can build LiteLLM into the TSC"). The first version of this ADR proposed a DHI mirror for LiteLLM and for Ollama. Ollama is still open and moved to ADR-011. This ADR changes no code. The kind `native` and each image entry come in their own pull requests, with a review by `@infrashift/security-admins`.

## Context

HALO needs images that are not static Go. The build track compiles only static Go binaries. The schema holds `build.cgo` to the constant `false`, and `scripts/lint-containerfiles.sh` requires `CGO_ENABLED=0`. See [Build track](/architecture/build-track--01a18382f2d2.md). [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md) answered P-TSC-4 only for software that a vendor ships as signed RPMs.

| Image | Language | HALO use |
|---|---|---|
| Valkey | C | The shared cache and state store: quotas, rate limits and turn coordination across replicas. LiteLLM uses it for its router and rate-limit store. |
| LiteLLM | Python. The DHI and vendor images add Node.js for Prisma. | The OpenAI-compatible gateway to the model providers. |

## What we measured

The facts are in three findings. This is a summary.

* [UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15](/findings/ubi-9-and-epel-9-shipped-no-valkey-package-on-2026-11-15--01a1dee755a1.md). UBI9 AppStream has only `redis` 7.2.16. EPEL 9 removed Valkey when RHEL 9.7 added it, and UBI does not carry the RHEL 9.7 package.
* [On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none](/findings/on-2026-11-15-dhi-valkey-had-2-unfixed-criticals-dhi-litellm-4-node-findings-and-dhi-ollama-none--01a1dee755b1.md). The blocking counts on amd64 were 4 for `dhi.io/valkey` (Debian `gawk`, no fix), 4 for `valkey/valkey`, 4 for `dhi.io/litellm` (all in its Node.js 24.19.0) and 7 for `ghcr.io/berriai/litellm` (runs as `root`).
* [UBI 9 AppStream shipped Python 3.12.15 and the LiteLLM 1.109.1 wheel carried its admin UI on 2026-11-15](/findings/ubi-9-appstream-shipped-python-3-12-15-and-the-litellm-1-109-1-wheel-carried-its-admin-ui-on-2026-11-15--01a1df4d8a53.md). UBI9 AppStream has `python3.12` 3.12.15 on both architectures. The admin UI is static files inside the wheel. Only Prisma needs Node.js, and the proxy runs without Prisma when it has no database. The `litellm[proxy]` set resolves to 117 wheels, the same for amd64 and arm64, with the Redis client.

## The options

| Option | What it is | Policy change |
|---|---|---|
| A. Mirror a DHI image | Copy by digest, keep the DHI signature and attestations. Trust class `dhi`. | None |
| B. Mirror the vendor image | Copy by digest. Trust class `none`, or a new class for a keyed vendor signature. | A new class for LiteLLM |
| C. Package kind (ADR-009) | Install signed vendor RPMs at pinned NEVRAs onto UBI. | None |
| D. A new kind, `native` | Build on a pinned UBI builder, with compilers or the interpreter from signed UBI RPMs, from inputs pinned by hash: a source commit, or a hash-locked dependency set. | A new kind |

The first version of this ADR had the Python install as a separate option. It is now a form of option D: the builder, the runtime base, the signed UBI toolchain, the labels and the review are the same. Only the pinned input differs.

### Valkey

| Criterion | A. DHI | B. Vendor | C. Package | D. `native` |
|---|---|---|---|---|
| Provenance | DHI signature, verified | No signature | Not possible: no free signed EL9 RPM | Pinned commit. The release archive sha256 from `valkey-io/valkey-hashes` is an independent check. The tag is not signed. |
| Reproducibility | DHI builds it | The vendor builds it | Not applicable | Not bit-for-bit. The commit, the builder digest and the RPM set are pinned or recorded. |
| SBOM and attestations | DHI CycloneDX, SLSA and VEX | None | Not applicable | Our SPDX SBOM, SLSA provenance and signed verdict, as for every built image |
| CVE policy | 4 blocking with no fix. Quarantine until Debian and Docker act. | 4 blocking | Not applicable | UBI findings clear with a rebuild. Valkey findings clear with a source bump. |

### LiteLLM

| Criterion | A. DHI | B. BerriAI | D. `native`, Python |
|---|---|---|---|
| Provenance | DHI signature, verified | Keyed cosign signature, verified with the `cosign.pub` of the repository. TOFU, and the key changed on 2026-10-23. | Python 3.12 from signed UBI RPMs. Each wheel is pinned by its PyPI sha256 in a committed lock file. The wheels are binaries that third parties built, without signatures. |
| Reproducibility | DHI builds it | BerriAI builds it | The wheel set is hash-locked. pip installs exactly the lock, with no resolution. |
| SBOM and attestations | DHI CycloneDX, SLSA and VEX | BuildKit attestation manifests and a cosign `.att` | Ours |
| CVE policy | 4 blocking, all in Node.js. A DHI rebuild clears them. | 7 blocking. A BerriAI release clears them. Runs as `root`. | We own every Python finding. A lock bump clears a wheel finding, and a rebuild clears a UBI finding. No Node.js is in the image. |

## Decision

### The kind `native`

A `native` entry is a built image with these properties:

1. **The builder.** The builder stage is a base from `bases`, named by the field `builder`, pinned by digest. It installs the compilers or the interpreter from the Red Hat signed UBI repositories, with `gpgcheck=1`. The Containerfile lint rejects every way to turn a signature check off, as for the package kind. The builder installs packages by name: UBI packages are not pinned by NEVRA, as on the package kind. The build records the builder digest in its provenance, and the review holds it against the pin.
2. **The runtime base** is `ubi9-minimal`. Valkey with TLS links the OpenSSL of UBI dynamically, and LiteLLM needs the Python 3.12 RPMs. `ubi9-micro` has no `libssl` and no package manager. The runtime stage upgrades the base from the signed UBI repositories.
3. **The pinned input** depends on `native.language`:
   * `c`: `source` names a `sources` entry with a 40-hex commit, as on the build track. That entry also pins the vendor release archive by sha256 (`archive`). The build fetches both and fails if their file trees differ. For Valkey, the sha256 comes from `valkey-io/valkey-hashes`.
   * `python`: a lock file in this repository, generated with `--generate-hashes` and pinned by sha256 in `versions.json`. The builder runs `pip install --require-hashes --no-deps --only-binary=:all:`, so pip installs exactly the lock, from wheels only, and runs no build step. The image carries the lock file. The review reads the lock file and the installed Python distributions from the image on GHCR, and the policy requires that the two sets are equal.
4. **No vendor comparison.** A `native` image records the sha256 of the binary that it built (`c`) or the sha256 of its lock (`python`) as a change detector, as [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md) intends. It does not compare with a vendor binary: the vendor builds Valkey on Debian with another compiler and glibc, so a mismatch is certain and proves nothing.
5. **Not cgo for Go.** The static-Go rules of the build track do not change. A Go program that needs cgo, such as Ollama, needs its own decision.
6. **The review re-derives the facts.** The review actor reads the pins (commit, archive sha256, lock sha256, builder and base digests) from the checked-out `versions.json`, and reads the lock file and the installed packages from the image on GHCR.
7. **The same gates as every built image:** the CVE gate, the five required labels, a non-root `USER 1001` in GID 0, and a smoke test in the Containerfile.

### Valkey

Valkey uses option D, language `c`. The other options fail: no free signed RPM exists, the vendor image has no signature, and the DHI image has Criticals that only Debian and Docker can clear. That is the reason that moved PostgreSQL 17 from DHI to UBI. Valkey keeps its dependencies in its own tree (`deps/`: jemalloc, Lua, libvalkey and others), so the compile is short. HALO needs TLS, so the build sets `BUILD_TLS=yes` against the OpenSSL of UBI. Persistence stays configurable: the image starts with the Valkey defaults, and `--save "" --appendonly no` turns persistence off.

### LiteLLM

LiteLLM uses option D, language `python`, by the decision of the owner on 2026-11-15.

* Python is `python3.12` from UBI9 AppStream. The builder also installs `python3.12-pip`. The runtime stage installs `python3.12` only and copies the virtual environment from the builder.
* The lock holds `litellm[proxy]` at a pinned release and `redis`, with every transitive dependency. HALO points LiteLLM at Valkey for its router and rate-limit store, and LiteLLM uses the `redis` client for that.
* The image has no Node.js. LiteLLM needs Node.js only for Prisma, which the `extra-proxy` extra installs for the database features. The image runs the stateless proxy: a config file, a master key, and Redis for the shared state. The admin UI files are in the wheel, and the proxy serves them. The UI features that need a database do not work without one.
* The DHI image had four blocking findings, all in its bundled Node.js. This image does not carry Node.js, so those findings do not apply.

If HALO needs the database features (virtual keys, spend logs, the UI login against the database), that needs a new decision. Prisma then needs its query engine binaries and Node.js. UBI9 AppStream has Node.js 24.22.1 in the `nodejs:24` module stream.

## Consequences

* `native` is a fourth image kind. Each tool that reads the build matrix must accept it, as ADR-009 found for `package`. The matrix emits a `native` image as a `build` leg, so the matrix guard in `review.yml` and `release.yml`, which runs from the default branch, does not change.
* A `native` image has a C compiler or pip in its builder stage, never in its runtime stage.
* We own every finding in a `native` image: the UBI packages, the Valkey source, and each Python wheel. A wheel finding clears with a lock bump in a reviewed pull request.
* The wheels are binaries that the PyPI publishers built. The lock pins their bytes, not how they were built.
* The UBI packages are not pinned by NEVRA. The SBOM and the review record each one, as on the package kind.
* No change in this ADR adds a waiver. Each blocking finding goes through [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md) or waits for a fix.

## Next steps

Each step is its own pull request.

1. The kind `native` for language `c` (schema, policy rules with tests that fail without them, the Containerfile lint, the build and review actors, the matrix), and the `valkey` entry in `observe`, with a local build and scan first.
2. The language `python` for the kind `native` (schema, policy rules with tests), and the `litellm` entry in `observe`, with a local build and scan first.

## Related

* [ADR-011: Ollama mirrors the DHI CUDA image in observe](/decisions/adr-011-ollama-mirrors-the-dhi-cuda-image-in-observe--01a1df4d8a41.md)
* [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md)
* [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
