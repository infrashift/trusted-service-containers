---
id: "01a1df71-0394-7037-8895-05bcec42eea5"
title: "litellm"
type: "image"
tags:
  - "image"
  - "litellm"
  - "native"
  - "python"
created: "2026-11-15T07:41:28-06:00"
timestamp: "2026-11-15T07:41:28-06:00"
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/litellm.Containerfile"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/locks/litellm/requirements.txt"
    title: "locks/litellm/requirements.txt"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/rootfs/litellm/etc/litellm/config.yaml"
    title: "rootfs/litellm/etc/litellm/config.yaml"
  - resource: "https://pypi.org/project/litellm/"
    title: "LiteLLM on PyPI"
description: "The LiteLLM proxy 1.109.1 from a hash-locked wheel set on the Python 3.12 of UBI; native python (ADR-010), no Node.js, no database."
---

# litellm

litellm is the LiteLLM proxy: an OpenAI-compatible gateway to the model providers. We install a hash-locked set of wheels onto the Python 3.12 of UBI, on our own `ubi9-minimal`. HALO uses it as its model gateway.

## Track

Native track (kind `native`, language `python`). See [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md). The owner decided on 2026-11-15 to build LiteLLM in this repository, not to mirror the DHI image.

* **Interpreter.** `python3.12` from UBI9 AppStream, from the Red Hat signed UBI repositories. The builder also installs `python3.12-pip`. The runtime stage installs `python3.12` only. See [UBI 9 AppStream shipped Python 3.12.15 and the LiteLLM 1.109.1 wheel carried its admin UI on 2026-11-15](/findings/ubi-9-appstream-shipped-python-3-12-15-and-the-litellm-1-109-1-wheel-carried-its-admin-ui-on-2026-11-15--01a1df4d8a53.md).
* **Lock.** `locks/litellm/requirements.txt`, generated from `locks/litellm/requirements.in` (`litellm[proxy]==1.109.1` and `redis`) with `uv pip compile --only-binary :all: --generate-hashes`. It pins 117 distributions with the sha256 of each of their files. The same lock serves amd64 and arm64. `versions.json` pins its sha256 in `native.lock.sha256`, and `scripts/check-locks.sh` holds the file to the pin.
* **Install.** The builder creates the venv `/opt/litellm` with `--without-pip`. Then pip installs the lock with `--require-hashes --no-deps --only-binary=:all:`: each file must have a hash in the lock, pip resolves nothing, and no package builds from source. `pip check` then confirms that the dependencies are complete.
* **Proof.** The build asks the venv interpreter, inside the pushed image, which distributions it sees. The review reads the lock in the checkout, the copy of the lock in the image (`/opt/litellm/requirements.txt`) and the distributions under the venv (syft) from the image on GHCR. The policy requires that the three sets are equal and that the lock pins `litellm==<version>`.
* **No Node.js and no Prisma.** The admin UI is static files in the wheel. Only the database features need Prisma and Node.js, and this image has neither.

## Trust class

`internal`. The build leg verifies the `ubi9-minimal` builder and runtime base against the release key of the sibling repository. The wheels have no signatures. The lock pins their bytes, not how their publishers built them.

## Enforcement

See `versions.json` for the current value. The image starts in `observe`. For the first scan, see [The first litellm scan found no Python finding and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-litellm-scan-found-no-python-finding-and-14-krb5-libs-highs-on-2026-11-15--01a1df7103a8.md).

The 14 fixable `krb5-libs` Highs of the `ubi9-minimal` base are waived by `EXC-2026-0043` until 2026-12-15, by the owner's decision of 2026-11-15. UBI did not carry the fix (`1.21.1-10.el9_9.2`) on that date. With the waiver, a leg with no other blocking finding goes to `trusted/`. See [Two waivers accept the krb5-libs Highs in valkey and litellm until 2026-12-15](/findings/two-waivers-accept-the-krb5-libs-highs-in-valkey-and-litellm-until-2026-12-15--01a1df9f1d8d.md).

## Interface

| Item | Value |
|---|---|
| Image | `ghcr.io/infrashift/trusted-service-containers/trusted/litellm:<version>` (for example `1.109.1`), also `<version>-<shortsha>` and `<version>-<YYYYMMDD>` |
| User | UID 1001, primary group GID 0. `HOME=/var/lib/litellm` is the only writable path that the image prepares. The code in `/opt/litellm` belongs to root. |
| Port | 4000 |
| Entrypoint | `litellm`, command `--config /etc/litellm/config.yaml --host 0.0.0.0 --port 4000` |
| Health | `/health/liveliness` and `/health/liveness` need no key. `/health/readiness` also exists. |
| Environment | `LITELLM_MASTER_KEY` (required, see below). `LITELLM_LOCAL_MODEL_COST_MAP=True` is set, so the proxy uses the model cost map from the wheel and does not fetch it from GitHub at start. |

### The configuration

`rootfs/litellm/etc/litellm/config.yaml` is ours. It has no model, and it reads the master key from `LITELLM_MASTER_KEY`.

WARNING: Set `LITELLM_MASTER_KEY`. Without a master key, the proxy accepts every request without authentication.

To add models and the shared Redis state, mount a config over `/etc/litellm/config.yaml`. Do not set `DATABASE_URL`: the image has no Prisma.

### Smoke tests

The runtime stage starts the proxy with a throwaway config and a fake model. It requires `200` from `/health/liveliness` without a key, and the list `["smoke"]` from `/v1/models` with the key. The builder runs `litellm --version` and `pip check`.

## What HALO sets

* `LITELLM_MASTER_KEY`, from a secret.
* The model list in a mounted config.
* The router and rate-limit store on [valkey](/images/valkey--01a1df5f8878.md): `router_settings.redis_host`, `redis_port` and `redis_password`. The lock has `redis` 8.1.0 and `hiredis` 3.5.0.

## Not in this image

* The database features: virtual keys, spend logs and the admin UI login against a database. They need Prisma, its query engine and Node.js. That needs a new decision (ADR-010).
* A release bump from the drift workflow. See [drift-upstream.sh does not propose new LiteLLM releases](/issues/drift-upstream-sh-does-not-propose-new-litellm-releases--01a1df7103b9.md).

## Related

* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [valkey](/images/valkey--01a1df5f8878.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Images overview](/images/images-overview--01a1837da526.md)
