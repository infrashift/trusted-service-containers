---
id: "01a1df4d-8a53-7146-8cc2-c9eb88e655bb"
title: "UBI 9 AppStream shipped Python 3.12.15 and the LiteLLM 1.109.1 wheel carried its admin UI on 2026-11-15"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "litellm"
  - "native"
  - "p-tsc-4"
created: "2026-11-15T07:02:43-06:00"
timestamp: "2026-11-15T07:02:43-06:00"
status: "draft"
resource: "https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/appstream/os/repodata/repomd.xml"
sources:
  - resource: "https://pypi.org/project/litellm/1.109.1/"
    title: "LiteLLM 1.109.1 on PyPI"
  - resource: "https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/aarch64/appstream/os/repodata/repomd.xml"
    title: "UBI9 AppStream aarch64 repodata"
description: "UBI9 AppStream had python3.12 3.12.15 on both arches; the LiteLLM 1.109.1 wheel holds the admin UI as static files and needs Node.js only for Prisma."
---

# UBI 9 AppStream shipped Python 3.12.15 and the LiteLLM 1.109.1 wheel carried its admin UI on 2026-11-15

On 2026-11-15, UBI9 AppStream had Python 3.12.15 for both architectures. The LiteLLM 1.109.1 wheel holds the admin UI as prebuilt static files. LiteLLM needs Node.js only for Prisma, and only the `extra-proxy` extra installs Prisma.

## Method

* UBI: for each repository, we downloaded `repodata/repomd.xml`, then the `primary.xml.gz` file that it names. Then we searched the `<name>` elements, as for Valkey in [UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15](/findings/ubi-9-and-epel-9-shipped-no-valkey-package-on-2026-11-15--01a1dee755a1.md).
* LiteLLM: we read the PyPI JSON API for `litellm`, downloaded the `manylinux_2_28_x86_64` wheel, compared its sha256 with the PyPI value, and listed its files.
* The dependency set: `uv pip compile --python-version 3.12 --only-binary :all: --generate-hashes` for the requirements `litellm[proxy]==1.109.1` and `redis`, once with `--python-platform x86_64-manylinux_2_34` and once with `aarch64-manylinux_2_34`. uv was 0.12.1.

## Result: UBI 9

| Repository | `repomd.xml` revision | Python 3.12 packages |
|---|---|---|
| UBI9 AppStream, x86_64 | 1794480320 | `python3.12-3.12.15-1.el9_8`, `python3.12-libs`, `python3.12-devel` (same version), `python3.12-pip-23.2.1-5.el9`, `python3.12-pip-wheel`, `python3.12-setuptools-68.2.2-5.el9_6` |
| UBI9 AppStream, aarch64 | 1794466179 | The same NEVRAs, for aarch64 |
| UBI9 BaseOS, x86_64 | 1794413174 | None. BaseOS has `python3-3.9.25-16.el9_9`, the system Python. |
| UBI9 BaseOS, aarch64 | 1794416385 | None. The same `python3` 3.9.25. |

Other facts from the same metadata:

* The packages are not modular. A plain `microdnf install python3.12` installs them.
* UBI9 AppStream had no Python 3.13. It had `python3.14-3.14.8-1.el9_8`.
* The compilers for the C build were present on both architectures: `gcc-11.5.0-17.el9_9` and `openssl-devel-3.5.9-1.el9_9` in AppStream, and `make-4.3-8.el9` and `openssl-libs-3.5.9-1.el9_9` in BaseOS.
* AppStream had the `nodejs:24` module stream at `nodejs-24.22.1-5.module+el9.8.0+25292+33251f3b`. That is the Node.js release that fixes the four findings of the DHI LiteLLM image.

## Result: the LiteLLM 1.109.1 wheel

* LiteLLM 1.109.1 was the newest release on PyPI that is not a pre-release (uploaded 2026-11-12). It requires Python `>=3.10,<3.16`.
* The release has `cp310-abi3` wheels for `manylinux_2_28` x86_64 and aarch64. The x86_64 wheel had sha256 `1c8b4dd671fa0cd0850aa751678704ff77e595fb1e6085b2dc3be39ee19bdaaf`, the same as PyPI.
* The wheel holds 4075 files. 834 of them are the admin UI under `litellm/proxy/_experimental/out/`, with `index.html`. The UI is a static Next.js export. No `node_modules` directory and no Node.js binary are in the wheel.
* The one native module is `litellm/rust_bridge/_native.abi3.so`.
* The proxy imports `prisma` only under `if TYPE_CHECKING:` in `litellm/proxy/utils.py` and `litellm/proxy/proxy_server.py`, and in the code paths that use a database. Prisma is in the `extra-proxy` extra, not in the `proxy` extra.
* The proxy serves `/health/liveliness` and `/health/liveness` without authentication.

## Result: the dependency set

* Both platforms resolved to the same 117 packages, with wheels only. The two lock files were byte-identical: uv writes the hash of every file of each pinned version, and pip picks the file for the platform.
* The set has `redis` 8.1.0, `hiredis` 3.5.0 and `rq` 2.12.0. LiteLLM uses `redis` for its cache, router and rate limits, so it can use Valkey.
* The set has no `prisma`, `nodeenv` or Node.js package.

## Related

* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none](/findings/on-2026-11-15-dhi-valkey-had-2-unfixed-criticals-dhi-litellm-4-node-findings-and-dhi-ollama-none--01a1dee755b1.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
