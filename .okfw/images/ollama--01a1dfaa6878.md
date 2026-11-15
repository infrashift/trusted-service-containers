---
id: "01a1dfaa-6878-708b-8f39-b3948ba84314"
title: "ollama"
type: "image"
tags:
  - "image"
  - "ollama"
  - "mirror"
created: "2026-11-15T08:44:09-06:00"
timestamp: "2026-11-15T08:44:09-06:00"
description: "Ollama for the HALO NVIDIA GPU nodes, mirrored from the DHI Debian 13 CUDA image with its DHI signature and attestations; trust class dhi (ADR-011)."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://dhi.io/catalog/ollama"
    title: "DHI catalog: Ollama"
  - resource: "https://github.com/ollama/ollama"
    title: "Ollama"
---

# ollama

ollama is the Ollama model server for the HALO NVIDIA GPU nodes. We mirror the Docker Hardened Images (DHI) build of it, Debian 13 with CUDA, with its DHI signature and attestations.

## Track

Mirror track, from `dhi.io/ollama`. See [ADR-011: Ollama mirrors the DHI CUDA image in observe](/decisions/adr-011-ollama-mirrors-the-dhi-cuda-image-in-observe--01a1df4d8a41.md) and [Mirror track](/architecture/mirror-track--01a18382f29c.md). The build track cannot build Ollama: it is Go with cgo and the C++ backends of llama.cpp.

On 2026-11-15 the owner accepted ADR-011:

* The DHI image, on Debian 13, with the risk of Debian findings that only Docker can clear. See [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md).
* The lag behind the Ollama release. On 2026-11-15 the DHI CUDA variant was 0.40.13 and Ollama was 0.40.16.
* NVIDIA only. AMD (ROCm), Vulkan or another GPU vendor needs a new decision.

## Trust class

`dhi`. The mirror leg verifies the DHI signature against the committed keyring `.github/pdp/keyring/dhi-latest.pub`. The policy requires two attestations on each platform: a CycloneDX 1.6 SBOM and SLSA provenance v1. See [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md).

The mirror leg needs the DHI credentials. See [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md).

## Enforcement

See `versions.json` for the current value. The image starts in `observe`, as step 5 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md) requires. For the first scan, see [The first ollama mirror scan found no blocking finding on 2026-11-15](/findings/the-first-ollama-mirror-scan-found-no-blocking-finding-on-2026-11-15--01a1dfaa684f.md).

## Variants and platforms

| Variant | Tag | Track |
|---|---|---|
| `runtime` | `0.40.13-debian13-cuda` | `^0\.40\.[0-9]+-debian13-cuda$` |

Platforms: `linux/amd64`, `linux/arm64`.

* The track allows only the 0.40 patch releases of the `debian13-cuda` variant. It excludes `-dev`, `-fips`, the Alpine CPU variant and the tags without a distribution. `drift-upstream.yml` proposes a newer 0.40 tag when DHI publishes one, and a new digest when DHI rebuilds the tag.
* A new Ollama minor release (0.41) needs a change of the track in its own reviewed pull request.
* We do not mirror the `dev` variant.

## Interface

| Item | Value |
|---|---|
| Image | `ghcr.io/infrashift/trusted-service-containers/trusted/ollama:0.40.13-debian13-cuda` when a review gives 0 blocking findings |
| User | UID 65532 (DHI `nonroot`), `HOME=/home/ollama`. The models go to `$HOME/.ollama/models` unless `OLLAMA_MODELS` names another path. |
| Port | 11434 (`OLLAMA_HOST=0.0.0.0:11434`) |
| Entrypoint | `/usr/bin/ollama`, command `serve` |
| Shell | None. The image has no shell and no package manager. |
| GPU | `NVIDIA_REQUIRE_CUDA=cuda>=13.2`, `NVIDIA_DRIVER_CAPABILITIES=compute,utility`, `NVIDIA_VISIBLE_DEVICES=all`. The image has the CUDA user-space runtime (in the Debian package `ollama-cuda-backend`). It does not have the driver: the NVIDIA Container Toolkit or CDI adds `libcuda.so` from the host. |

## What HALO sets

* A volume for the models, for example at `/home/ollama/.ollama`, writable by UID 65532.
* The GPU through CDI (`--device nvidia.com/gpu=all`) or the NVIDIA Container Toolkit. The host driver must support CUDA 13.2 or later.
* In development, HALO runs Ollama on the host, not in this image.

## Notes

* No CI runner has a GPU. The CI scan covers the image, not the GPU path. HALO tests the GPU path in its own environment.
* DHI claims a near-zero baseline of known CVEs. Thus the PDP remediation hint says that a finding on a DHI image is probably a stale pin. Before you consider a waiver, resolve the digest again with `make -f Ops.mk verify-pins`.
* When the DHI image has a blocking finding that no DHI rebuild clears, and no waiver is acceptable, Ollama moves to the kind `native`, CPU only first. See ADR-011.

## Related

* [ADR-011: Ollama mirrors the DHI CUDA image in observe](/decisions/adr-011-ollama-mirrors-the-dhi-cuda-image-in-observe--01a1df4d8a41.md)
* [On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none](/findings/on-2026-11-15-dhi-valkey-had-2-unfixed-criticals-dhi-litellm-4-node-findings-and-dhi-ollama-none--01a1dee755b1.md)
* [traefik](/images/traefik--01a183832cbc.md) and [postgres](/images/postgres--01a183832d06.md): the other `dhi` images.
* [Images overview](/images/images-overview--01a1837da526.md)
