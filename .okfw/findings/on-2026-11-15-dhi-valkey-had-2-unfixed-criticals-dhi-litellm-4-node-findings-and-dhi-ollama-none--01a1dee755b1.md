---
id: "01a1dee7-55b1-725b-b7ba-ab075f88c50f"
title: "On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "mirror"
  - "valkey"
  - "litellm"
  - "ollama"
  - "p-tsc-4"
created: "2026-11-15T05:11:05-06:00"
timestamp: "2026-11-15T05:11:05-06:00"
description: "Signature checks and amd64 grype scans of the DHI and vendor images for Valkey, LiteLLM and Ollama, the candidates for the mirror track."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
sources:
  - resource: "https://github.com/BerriAI/litellm/blob/main/cosign.pub"
    title: "LiteLLM cosign.pub"
  - resource: "https://github.com/ollama/ollama/blob/main/Dockerfile"
    title: "Ollama Dockerfile"
  - resource: "https://github.com/valkey-io/valkey-hashes"
    title: "valkey-hashes"
---

# On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none

On 2026-11-15, we checked the signature of seven candidate images for Valkey, LiteLLM and Ollama, and scanned six of them. Only the DHI Ollama images had no blocking finding. No candidate is in `versions.json`.

## Method

* DHI signatures: `cosign verify --key .github/pdp/keyring/dhi-latest.pub --insecure-ignore-tlog=true --experimental-oci11=true <repo>@<index digest>`, as `scripts/mirror-leg.sh` does.
* LiteLLM signature: `cosign verify --key cosign.pub`, with the `cosign.pub` file from the default branch of `BerriAI/litellm`.
* Other vendor images: we listed the tags with `regctl tag ls` and looked for `sha256-<digest>.sig` and `.att` tags. We also read the index for `attestation-manifest` entries.
* Scans: `grype registry:<repo>@<amd64 child digest>`. The grype database was built on 2026-11-15T06:19:39Z. "Blocking" counts the matches that the PDP blocks: each Critical, and each High with a fix. We scanned amd64 only.

## Result

The digests are the first 12 hex digits of the index digest.

| Image | Index digest | Signature | Base, user | Critical | Fixable High | Blocking |
|---|---|---|---|---:|---:|---:|
| `dhi.io/valkey:9.1.3-debian13` | `30ad0b49d349` | Verified, DHI key | Debian 13, 65532 | 4 | 0 | 4 |
| `docker.io/valkey/valkey:9.1.3` | `3add1a336a92` | None found | Debian 13 | 0 | 4 | 4 |
| `dhi.io/litellm:1.109.1-debian13` | `e26b617f7d8d` | Verified, DHI key | Debian 13, 65532 | 1 | 3 | 4 |
| `ghcr.io/berriai/litellm:v1.109.1` | `11175975a309` | Verified, `cosign.pub` of LiteLLM | Wolfi, `root` | 0 | 7 | 7 |
| `dhi.io/ollama:0.40.13-debian13-cuda` | `25047db279f0` | Verified, DHI key | Debian 13, 65532 | 0 | 0 | 0 |
| `dhi.io/ollama:0.40.16-alpine3.24` | `122a622245b3` | Verified, DHI key | Alpine 3.24 | 0 | 0 | 0 |
| `docker.io/ollama/ollama:0.40.16` | `910d0d8107b5` | None found | Ubuntu 24.04, no `USER` (root) | not scanned | not scanned | not scanned |

### The blocking findings

* DHI Valkey: `CVE-2026-40468` and `CVE-2026-40469` in the Debian package `gawk` (`1:5.2.1-2+deb13u0+dhi2`). Neither has a fix. Each CVE matched two times.
* Valkey on Docker Hub: `CVE-2026-109518` in `apt` and `libapt-pkg7.0` (fixed in 3.0.4), and `CVE-2026-76844` and `CVE-2026-85091` in `zlib1g` (fixed in `deb13u1`).
* DHI LiteLLM: the Critical `CVE-2026-111497` and the Highs `CVE-2026-105482`, `CVE-2026-105483` and `CVE-2026-106069`, all in the bundled `node` binary 24.19.0. Node 24.22.1 fixes all four.
* LiteLLM from BerriAI: `CVE-2026-84243` in four Wolfi glibc packages (fixed in `2.44-r16`), and `GHSA-3jp2-3mrg-2vxc` (oauthlib), `GHSA-v4x8-3wr5-3wq8` (filelock) and `GHSA-vvf4-9x63-8xvv` (dnspython).

## Other facts

* The newest DHI Ollama image with CUDA was 0.40.13. The newest Ollama release and the newest DHI Alpine image were 0.40.16. The DHI CUDA image sets `NVIDIA_REQUIRE_CUDA=cuda>=13.2`, has amd64 and arm64, and is 788 MiB compressed on amd64.
* On amd64, the DHI LiteLLM and DHI Ollama CUDA images have OCI referrers for CycloneDX 1.6 (`https://cyclonedx.org/bom/v1.6`), SLSA provenance v1 (`https://slsa.dev/provenance/v1`) and OpenVEX. These include the two predicates that `requiredPredicates` asks for on the DHI mirror entries.
* `syft` lists the CUDA runtime of the DHI Ollama image inside the Debian package `ollama-cuda-backend`, not as separate CUDA packages.
* The Ollama image on Docker Hub is 3240 MiB compressed on amd64. We did not scan it. The Ollama release archives have only a `sha256sum.txt` on the same release page. The GitHub attestations API answered 404 for the hash of `ollama-linux-amd64.tar.zst`.
* The LiteLLM signature has no certificate. It is a keyed signature with a Rekor bundle. The last change to `cosign.pub` in the LiteLLM repository was on 2026-10-23.
* The Valkey tag `9.1.3` is a lightweight tag on commit `29173b67508b`. It has no signed tag object. The repository `valkey-io/valkey-hashes` publishes the sha256 of each release archive.

## Related

* [ADR-010: Valkey builds from source on UBI, LiteLLM and Ollama mirror DHI](/decisions/adr-010-valkey-builds-from-source-on-ubi-litellm-and-ollama-mirror-dhi--01a1dee688b9.md)
* [UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15](/findings/ubi-9-and-epel-9-shipped-no-valkey-package-on-2026-11-15--01a1dee755a1.md)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
