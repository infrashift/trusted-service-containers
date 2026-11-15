---
id: "01a1dee6-88b9-7013-b76f-4611260f87b0"
title: "ADR-010: Valkey builds from source on UBI, LiteLLM and Ollama mirror DHI"
type: "decision"
tags:
  - "decision"
  - "build"
  - "native"
  - "mirror"
  - "p-tsc-4"
created: "2026-11-15T05:10:12-06:00"
timestamp: "2026-11-15T05:10:12-06:00"
description: "HALO's non-Go images: Valkey compiles from pinned source on UBI as the new kind native; LiteLLM and Ollama (CUDA) mirror their DHI images in observe."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
    title: "scripts/mirror-leg.sh"
  - resource: "https://github.com/valkey-io/valkey"
    title: "Valkey"
  - resource: "https://github.com/BerriAI/litellm"
    title: "LiteLLM"
  - resource: "https://github.com/ollama/ollama"
    title: "Ollama"
  - resource: "https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo"
    title: "NVIDIA CUDA repository for RHEL 9"
x:
  adr: 10
  answers: "P-TSC-4 (HALO PLAN.md section 7), for LiteLLM, Ollama and Valkey"
---

# ADR-010: Valkey builds from source on UBI, LiteLLM and Ollama mirror DHI

HALO needs three images that are not static Go: Valkey (C), LiteLLM (Python) and Ollama (Go with cgo, C++ and CUDA). Valkey gets a new build kind, `native`, that compiles a pinned source commit on UBI. LiteLLM and Ollama use the mirror track with their Docker Hardened Images (DHI), in `observe`.

**Status:** Proposed, 2026-11-15. This ADR changes no code. The `native` kind needs its own pull request, with changes to `schemas/versions.schema.json` and `.github/pdp/policies.rego`, and a review by `@infrashift/security-admins`. Each new image entry needs its own pull request.

## Context

The build track compiles only static Go binaries. The schema holds `build.cgo` to the constant `false`, and `scripts/lint-containerfiles.sh` requires `CGO_ENABLED=0`. A cgo binary from the Debian toolchain image links glibc 2.41, and it cannot run on the glibc 2.34 of `ubi9-micro`. See [Build track](/architecture/build-track--01a18382f2d2.md).

[ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md) answered P-TSC-4 only for software that a vendor ships as signed RPMs. HALO also needs these images in production:

| Image | Language | HALO use |
|---|---|---|
| Valkey | C | The shared cache and state store: quotas, rate limits and turn coordination across replicas. LiteLLM can also use it. |
| LiteLLM | Python, with Node.js for Prisma and the admin UI | The OpenAI-compatible gateway to the model providers. |
| Ollama | Go with cgo, and C++ backends from llama.cpp | The local model server. Production needs NVIDIA GPUs. |

In development, HALO runs Ollama on the host and runs no LiteLLM and no Valkey.

## What we measured

The facts are in two findings. This is a summary.

* [UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15](/findings/ubi-9-and-epel-9-shipped-no-valkey-package-on-2026-11-15--01a1dee755a1.md). UBI9 AppStream has only `redis` 7.2.16. EPEL 9 removed Valkey when RHEL 9.7 added it, and UBI does not carry the RHEL 9.7 package. The Red Hat Valkey image needs an entitled pull.
* [On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none](/findings/on-2026-11-15-dhi-valkey-had-2-unfixed-criticals-dhi-litellm-4-node-findings-and-dhi-ollama-none--01a1dee755b1.md). Every DHI image verified against our pinned DHI key. The blocking counts on amd64 were:

| Candidate | Blocking | Cause | Who can clear it |
|---|---:|---|---|
| `dhi.io/valkey`, Debian 13 | 4 | Two Criticals in Debian `gawk`, with no fix | Debian, then Docker |
| `docker.io/valkey/valkey`, Debian 13, unsigned | 4 | `apt` and `zlib1g` Highs, with a fix | The Valkey image maintainers |
| `dhi.io/litellm`, Debian 13 | 4 | The bundled Node.js 24.19.0. Node 24.22.1 fixes all four. | Docker, with a rebuild |
| `ghcr.io/berriai/litellm`, Wolfi, `root` | 7 | Wolfi glibc and three Python modules | BerriAI |
| `dhi.io/ollama`, Debian 13 with CUDA, 0.40.13 | 0 | None | Not applicable |
| `dhi.io/ollama`, Alpine, CPU only, 0.40.16 | 0 | None | Not applicable |
| `docker.io/ollama/ollama`, Ubuntu 24.04, unsigned, `root` | Not scanned | 3240 MiB compressed | Not applicable |

## The options

| Option | What it is | Policy change |
|---|---|---|
| A. Mirror a DHI image | Copy by digest, keep the DHI signature and attestations. Trust class `dhi`. | None |
| B. Mirror the vendor image | Copy by digest. Trust class `none`, or a new class for a keyed vendor signature. | A new class for LiteLLM |
| C. Package kind (ADR-009) | Install signed vendor RPMs at pinned NEVRAs onto UBI. | None |
| D. A new kind, `native` | Compile C, C++ or cgo from a pinned source commit on a UBI builder. Compilers and libraries come from signed RPMs. | A new kind |
| E. A new kind for Python | Install a hash-locked Python dependency set onto UBI Python. | A new kind |
| F. A vendor release archive on UBI | Unpack a vendor archive, pinned by sha256, onto UBI. | A new kind |

### Valkey

| Criterion | A. DHI | B. Vendor | C. Package | D. `native` |
|---|---|---|---|---|
| Provenance | DHI signature, verified | No signature | Not possible: no free signed EL9 RPM | Pinned commit. The release archive sha256 from `valkey-io/valkey-hashes` is an independent check. The tag is not signed. |
| Reproducibility | DHI builds it | The vendor builds it | Not applicable | Not bit-for-bit. The commit, the builder digest and the RPM set are pinned or recorded. |
| SBOM and attestations | DHI CycloneDX, SLSA and VEX | None | Not applicable | Our SPDX SBOM, SLSA provenance and signed verdict, as for every built image |
| CVE policy | 4 blocking with no fix. Quarantine until Debian and Docker act. | 4 blocking | Not applicable | UBI findings clear with a rebuild. Valkey findings clear with a source bump. |
| GPU | Not applicable | Not applicable | Not applicable | Not applicable |

### LiteLLM

| Criterion | A. DHI | B. BerriAI | E. Python kind |
|---|---|---|---|
| Provenance | DHI signature, verified | Keyed cosign signature, verified with the `cosign.pub` of the repository. TOFU, and the key changed on 2026-10-23. | UBI Python RPMs, and `uv.lock` hashes for each wheel. The wheels are binaries built by third parties, without signatures. Prisma downloads its engines at build time. |
| Reproducibility | DHI builds it | BerriAI builds it | The dependency set is hash-locked. The image also needs Node.js, a Next.js UI build and a pgbouncer compile. |
| SBOM and attestations | DHI CycloneDX, SLSA and VEX | BuildKit attestation manifests and a cosign `.att` | Ours |
| CVE policy | 4 blocking, all in Node.js. A DHI rebuild clears them. | 7 blocking. A BerriAI release clears them. Runs as `root`. | We own every Python and Node.js finding. |
| GPU | Not applicable | Not applicable | Not applicable |

### Ollama

| Criterion | A. DHI | B. Vendor | D. `native` with CUDA | F. Release archive |
|---|---|---|---|---|
| Provenance | DHI signature, verified | No signature | Pinned commit. CUDA from the NVIDIA RHEL 9 repository (`gpgcheck=1`, key `D42D0685`, signed `repomd.xml`). | A `sha256sum.txt` on the same release page. No signature and no GitHub attestation. |
| Reproducibility | DHI builds it | The vendor builds it | Not bit-for-bit. The CUDA toolkit is several GB, and the CUDA kernels take a long time to compile in CI. | The vendor binary, exactly |
| SBOM and attestations | DHI CycloneDX, SLSA and VEX. The CUDA runtime is inside the package `ollama-cuda-backend`. | None | Ours. The CUDA RPMs are in the rpm database. | Ours. The bundled CUDA libraries are not in any package database, so the scan cannot see them. |
| CVE policy | 0 blocking on 2026-11-15 | Not scanned | UBI findings clear with a rebuild. | The scan is blind to the CUDA libraries. |
| GPU | CUDA 13.2 or later, amd64 and arm64. 0.40.13, three patch releases behind. | CUDA 12 and 13 and a ROCm tag. `root`. | CUDA only. CI has no GPU, so CI can test only the CPU path. | CUDA 12 and 13 |

## Decision

### Valkey: the new `native` kind

Valkey uses option D. The other options fail: no free signed RPM exists, the vendor image has no signature, and the DHI image has Criticals that only Debian and Docker can clear. That is the reason that moved PostgreSQL 17 from DHI to UBI. Valkey is a small C program with its dependencies in its own tree (`deps/`: jemalloc, Lua, libvalkey and others), so the compile is short.

A `native` entry is a build entry with these differences:

1. The builder stage is a pinned UBI image, not the Debian Go toolchain. It installs `gcc`, `make` and the `-devel` packages from the Red Hat signed UBI repositories, with `gpgcheck=1`. Then the binary links the glibc of UBI 9.
2. The runtime base is `ubi9-minimal`. Valkey with TLS links OpenSSL dynamically, and `ubi9-micro` has no `libssl` or `libcrypto`.
3. `source` pins a 40-hex commit, as on the build track. When the vendor publishes archive hashes in a second place, the entry pins that sha256 too, and the build compares it with the archive of the commit. For Valkey, that place is `valkey-io/valkey-hashes`.
4. A third-party RPM repository, if the build needs one, is a `packageRepos` entry with a pinned key, as in ADR-009. The same Containerfile lint applies: no way to disable a signature check.
5. `cgo` or a C compiler is allowed only for this kind. The static-Go rules of the build track do not change.
6. The binary cross-check of [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md) compares our binary with the vendor binary when one exists. It is an observation, never a gate.
7. The review actor re-derives the source commit, the base and the installed RPM set from `versions.json` and from the image on GHCR, as `scripts/package-observe.sh` does for the package kind.
8. The CVE gate, the five required labels, a non-root `USER` in GID 0, and a smoke test in the builder stage are the same as on the build track.

Valkey is the first `native` image. The kind exists for C and C++ software that no free signed repository ships, and for a later Ollama build.

### LiteLLM: mirror DHI, in observe

LiteLLM uses option A. It needs no policy change, and the `dhi` trust class and the DHI key already exist. Its four blocking findings are all in the bundled Node.js, and a DHI rebuild with Node.js 24.22.1 clears them. Until then, the LiteLLM legs go to `quarantine/`, and HALO production does not use them.

We do not mirror the BerriAI image. It runs as `root`, its seven blocking findings depend on BerriAI, and its keyed signature needs a new trust class. We do not build LiteLLM now. Option E would make us the owner of every Python and Node.js finding, for an image that also needs Prisma engines, a UI build and pgbouncer.

### Ollama: mirror DHI with CUDA, in observe

Ollama uses option A, with the `debian13-cuda` variant for the GPU nodes. On 2026-11-15 it had no blocking finding, a non-root user, both architectures, and DHI SBOM, provenance and VEX attestations. It is the only candidate that met the CVE gate.

* The image holds the CUDA user-space runtime. The NVIDIA driver (`libcuda.so`) is not in the image. The NVIDIA Container Toolkit, or CDI, adds it from the host at run time. The host driver must support CUDA 13.2 or later (`NVIDIA_REQUIRE_CUDA`).
* The DHI CUDA variant was three patch releases behind the Ollama release on 2026-11-15. The drift workflow proposes a newer tag inside the track when DHI publishes one.
* ROCm and Vulkan are out of scope. AMD GPUs need a new decision.
* We do not mirror the Docker Hub image: it has no signature and runs as `root`. We do not unpack the release archive (option F): the CVE scan cannot see the CUDA libraries in it.

### When an image leaves the mirror track

A mirror entry stays a mirror while its DHI image can reach zero blocking findings. When a DHI image has a blocking finding that no DHI rebuild clears, and no waiver is acceptable, the image moves to a build kind in a reviewed pull request:

* Ollama moves to `native`, with the CUDA RPMs from the pinned NVIDIA repository. Its first `native` image is CPU only. The CUDA variant follows when CI can build it in the time and disk of a runner.
* LiteLLM needs a new ADR for option E first.

## Consequences

* The `native` kind adds a fourth image kind. Each tool that reads the build matrix must accept it, as ADR-009 found for `package`.
* A `native` image has a C toolchain in its builder stage. Its UBI dependencies are not pinned by NEVRA, as on the package kind. The SBOM and the review record each one.
* The LiteLLM and Ollama mirrors add two more Debian-based DHI images. The risk of Debian findings that only Docker can clear applies to them, as it does to postgres 16 and traefik. See [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md).
* The DHI images are on `dhi.io`, so the mirror legs need the DHI credentials. See [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md).
* No CI runner has a GPU. The CI smoke tests and scans cover the image, not the GPU path. HALO tests the GPU path in its own environment.
* No change in this ADR adds a waiver. Each blocking finding goes through [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md) or waits for a fix.

## Next steps

Each step is its own pull request.

1. The `native` kind: schema, policy rules with tests that fail without them, the Containerfile lint, the build and review actors, and the matrix.
2. The `valkey` entry on the `native` kind, in `observe`, with a local build and scan first.
3. The `litellm` mirror entry from `dhi.io/litellm`, in `observe`.
4. The `ollama` mirror entry from `dhi.io/ollama`, variant `debian13-cuda`, in `observe`.

## Related

* [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md)
* [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
