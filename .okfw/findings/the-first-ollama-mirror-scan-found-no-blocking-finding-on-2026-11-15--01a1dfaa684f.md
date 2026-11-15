---
id: "01a1dfaa-684f-7338-b47f-837790f66da8"
title: "The first ollama mirror scan found no blocking finding on 2026-11-15"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "ollama"
  - "cve"
  - "mirror"
created: "2026-11-15T08:44:09-06:00"
timestamp: "2026-11-15T08:44:09-06:00"
description: "dhi.io/ollama 0.40.13-debian13-cuda on amd64 and arm64: signature verified with the DHI key, both required attestations on each platform, 0 Critical, 0 fixable High, 18 unfixable Debian Highs per platform."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
---

# The first ollama mirror scan found no blocking finding on 2026-11-15

On 2026-11-15 we checked and scanned the pinned [ollama](/images/ollama--01a1dfaa6878.md) mirror image, `dhi.io/ollama:0.40.13-debian13-cuda`, on both platforms. The signature verified with the DHI key. Each platform had both required attestations. Neither platform had a blocking finding.

## Method

* Index digest: `regctl manifest head dhi.io/ollama:0.40.13-debian13-cuda` gave `sha256:25047db279f059d87c62607f351e7f2d4dec77c581adad34556b4ee13f4ffb7a`. The rolling tags `0.40-debian13-cuda` and `0-debian13-cuda` gave the same digest.
* Key: the live DHI keyring (`https://registry.scout.docker.com/keyring/dhi/latest.pub`) had sha256 `1d02bbcc…8a5f`, the same as the committed `.github/pdp/keyring/dhi-latest.pub`.
* Signature: `cosign verify --key .github/pdp/keyring/dhi-latest.pub --insecure-ignore-tlog=true --experimental-oci11=true dhi.io/ollama@<index digest>`, as `scripts/mirror-leg.sh` does. It verified.
* Attestations: `regctl artifact list` on each child manifest.
* Scan: `grype registry:dhi.io/ollama@<child digest>` for each platform, as the mirror leg scans each platform. grype 0.115.0, database built 2026-11-15T06:19:39Z. We did not pull the image into local storage.

## Result

| Platform | Child digest | Compressed size | Critical | High (fixable) | High (no fix) | Blocking |
|---|---|---:|---:|---:|---:|---:|
| `linux/amd64` | `sha256:5b0a466f4017…` | 788 MiB | 0 | 0 | 18 | 0 |
| `linux/arm64` | `sha256:88673e489315…` | 895 MiB | 0 | 0 | 18 | 0 |

* The 18 Highs on each platform are 9 package and CVE pairs that grype matched two times. All are `wont-fix` in Debian 13:
  * `libc6` `2.41-12+deb13u4+dhi1`: CVE-2026-19499, CVE-2026-5435, CVE-2026-84243.
  * `gcc-14-base`, `libgcc-s1` and `libstdc++6` `14.2.0-19+deb13u0+dhi7`: CVE-2026-102010, CVE-2026-95619.
* The policy records these Highs. It does not block them, because they have no fix.
* Two findings had a fix but no severity (`Unknown`), so the gate ignores them. Both are in the Go modules of the `ollama` binary: `GO-2026-6859` in `stdlib` `go1.27.3` (fixed in 1.27.4), and `GO-2026-5932` in `golang.org/x/crypto` `v0.58.0`. Only a DHI rebuild clears them.
* Other severities on each platform: 32 Medium, 14 Low and 20 Negligible, none with a fix.
* Each platform had these referrers, among others: CycloneDX 1.6 (`https://cyclonedx.org/bom/v1.6`), SLSA provenance v1 (`https://slsa.dev/provenance/v1`), OpenVEX, SPDX and the DHI scan and test attestations. The entry requires the first two.
* The image config: user `65532`, entrypoint `/usr/bin/ollama`, command `serve`, `OLLAMA_HOST=0.0.0.0:11434`, `NVIDIA_REQUIRE_CUDA=cuda>=13.2`, `NVIDIA_DRIVER_CAPABILITIES=compute,utility`, `HOME=/home/ollama`. No shell and no package manager (`com.docker.dhi.shell` and `com.docker.dhi.package-manager` are empty). DHI built it on 2026-10-29.

## What this does not cover

* The review. The CI mirror leg scans the same child digests. Its result can differ if the grype database changes.
* The GPU path. No CI runner and no local host had an NVIDIA GPU.
* The lag. Ollama 0.40.16 was the newest release on 2026-11-15. The owner accepted the lag. See [ADR-011: Ollama mirrors the DHI CUDA image in observe](/decisions/adr-011-ollama-mirrors-the-dhi-cuda-image-in-observe--01a1df4d8a41.md).

## Related

* [ollama](/images/ollama--01a1dfaa6878.md)
* [ADR-011: Ollama mirrors the DHI CUDA image in observe](/decisions/adr-011-ollama-mirrors-the-dhi-cuda-image-in-observe--01a1df4d8a41.md)
* [On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none](/findings/on-2026-11-15-dhi-valkey-had-2-unfixed-criticals-dhi-litellm-4-node-findings-and-dhi-ollama-none--01a1dee755b1.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
