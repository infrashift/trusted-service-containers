---
id: "01a1df4d-8a41-7ab1-8e4d-3009301f2226"
title: "ADR-011: Ollama mirrors the DHI CUDA image in observe"
type: "decision"
tags:
  - "decision"
  - "mirror"
  - "ollama"
  - "p-tsc-4"
created: "2026-11-15T07:02:43-06:00"
timestamp: "2026-11-15T07:02:43-06:00"
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
    title: "scripts/mirror-leg.sh"
  - resource: "https://github.com/ollama/ollama"
    title: "Ollama"
  - resource: "https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo"
    title: "NVIDIA CUDA repository for RHEL 9"
description: "Proposed: Ollama for HALO's GPU nodes mirrors dhi.io/ollama debian13-cuda in observe; a native CPU build is the exit path."
x:
  adr: 11
  answers: "P-TSC-4 (HALO PLAN.md section 7), for Ollama"
---

# ADR-011: Ollama mirrors the DHI CUDA image in observe

Ollama for the HALO GPU nodes uses the mirror track with the Docker Hardened Image (DHI) variant `debian13-cuda`, in `observe`. The exit path is the kind `native` of ADR-010, CPU only first.

**Status:** Proposed, 2026-11-15. The owner has not decided yet. This ADR changes no code. It came out of [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md), which the owner accepted for Valkey and LiteLLM only.

## Context

Ollama is Go with cgo, and C++ backends from llama.cpp. HALO production needs NVIDIA GPUs. In development, HALO runs Ollama on the host. The build track compiles only static Go binaries (`build.cgo` is the constant `false`), so it cannot build Ollama. See [Build track](/architecture/build-track--01a18382f2d2.md).

The facts are in [On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none](/findings/on-2026-11-15-dhi-valkey-had-2-unfixed-criticals-dhi-litellm-4-node-findings-and-dhi-ollama-none--01a1dee755b1.md). On amd64, the blocking counts were:

| Candidate | Blocking | Notes |
|---|---:|---|
| `dhi.io/ollama`, Debian 13 with CUDA, 0.40.13 | 0 | Verified with the DHI key. UID 65532. amd64 and arm64. |
| `dhi.io/ollama`, Alpine, CPU only, 0.40.16 | 0 | Verified with the DHI key. No GPU. |
| `docker.io/ollama/ollama`, Ubuntu 24.04, 0.40.16 | Not scanned | No signature. No `USER`, so it runs as `root`. 3240 MiB compressed. |

## The options

| Criterion | A. Mirror DHI | B. Mirror the vendor image | D. `native` with CUDA | F. The release archive on UBI |
|---|---|---|---|---|
| Provenance | DHI signature, verified | No signature | Pinned commit. CUDA from the NVIDIA RHEL 9 repository (`gpgcheck=1`, key `D42D0685`, signed `repomd.xml`). | A `sha256sum.txt` on the same release page. No signature and no GitHub attestation. |
| Reproducibility | DHI builds it | The vendor builds it | Not bit-for-bit. The CUDA toolkit is several GB, and the CUDA kernels take a long time to compile in CI. | The vendor binary, exactly |
| SBOM and attestations | DHI CycloneDX, SLSA and VEX. The CUDA runtime is inside the package `ollama-cuda-backend`. | None | Ours. The CUDA RPMs are in the rpm database. | Ours. The bundled CUDA libraries are not in any package database, so the scan cannot see them. |
| CVE policy | 0 blocking on 2026-11-15 | Not scanned | UBI findings clear with a rebuild. | The scan is blind to the CUDA libraries. |
| GPU | CUDA 13.2 or later, amd64 and arm64. 0.40.13, three patch releases behind. | CUDA 12 and 13 and a ROCm tag. `root`. | CUDA only. CI has no GPU, so CI can test only the CPU path. | CUDA 12 and 13 |

## Proposed decision

Ollama uses option A, with the `debian13-cuda` variant. On 2026-11-15 it had no blocking finding, a non-root user, both architectures, and DHI SBOM, provenance and VEX attestations. It was the only candidate that met the CVE gate.

* The image holds the CUDA user-space runtime. The NVIDIA driver (`libcuda.so`) is not in the image. The NVIDIA Container Toolkit, or CDI, adds it from the host at run time. The host driver must support CUDA 13.2 or later (`NVIDIA_REQUIRE_CUDA`).
* The DHI CUDA variant was three patch releases behind the Ollama release on 2026-11-15. The drift workflow proposes a newer tag inside the track when DHI publishes one.
* ROCm and Vulkan are out of scope. AMD GPUs need a new decision.
* We do not mirror the Docker Hub image: it has no signature and runs as `root`. We do not unpack the release archive (option F): the CVE scan cannot see the CUDA libraries in it.

## When Ollama leaves the mirror track

Ollama stays a mirror while its DHI image can reach zero blocking findings. When the DHI image has a blocking finding that no DHI rebuild clears, and no waiver is acceptable, Ollama moves to the kind `native` in a reviewed pull request. Its first `native` image is CPU only. The CUDA variant follows when CI can build it in the time and disk of a runner, with the CUDA RPMs from the NVIDIA repository pinned as a `packageRepos` entry.

## Consequences

* The mirror adds one more Debian-based DHI image. The risk of Debian findings that only Docker can clear applies to it, as it does to postgres 16 and traefik. See [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md).
* The image is on `dhi.io`, so the mirror leg needs the DHI credentials. See [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md).
* No CI runner has a GPU. The CI scan covers the image, not the GPU path. HALO tests the GPU path in its own environment.

## Questions for the owner

1. Do you accept the DHI image (Debian 13) for Ollama, with the risk of Debian findings that only Docker can clear?
2. Do you accept the CUDA lag (DHI 0.40.13, upstream 0.40.16 on 2026-11-15)?
3. Is NVIDIA the only GPU vendor? AMD (ROCm) needs a new decision.

## Next steps

When the owner accepts this ADR: one pull request adds the `ollama` mirror entry from `dhi.io/ollama`, variant `debian13-cuda`, in `observe`, with a local scan first.

## Related

* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
