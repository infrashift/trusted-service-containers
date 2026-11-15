---
id: "01a1df71-03a8-7ae4-a2c8-575d5edb88a0"
title: "The first litellm scan found no Python finding and 14 krb5-libs Highs on 2026-11-15"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "litellm"
  - "cve"
  - "native"
created: "2026-11-15T07:41:28-06:00"
timestamp: "2026-11-15T07:41:28-06:00"
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/litellm.Containerfile"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/locks/litellm/requirements.txt"
    title: "locks/litellm/requirements.txt"
description: "The first local build of litellm 1.109.1 on amd64 had no Critical and no finding in its 117 wheels; its 14 fixable Highs are the krb5-libs set of the UBI base."
---

# The first litellm scan found no Python finding and 14 krb5-libs Highs on 2026-11-15

On 2026-11-15, the first local build of [litellm](/images/litellm--01a1df710394.md) 1.109.1 on amd64 had no Critical and no finding in any of its 117 Python distributions. All its Highs are in UBI packages. The 14 fixable Highs are the `krb5-libs` set of the `ubi9-minimal` base.

## Method

* We ran `scripts/build-leg.sh` for `litellm-runtime` on amd64, with stubs only for the registry push and for cosign. The build checked the lock against its pin, installed it on the pinned `ubi9-minimal` builder, ran the runtime smoke test, and confirmed with the venv interpreter that the venv holds exactly the 117 locked distributions.
* The scan is the `grype` step of the build leg on the OCI copy of the image. grype 0.115.0, database built 2026-11-15T06:19:39Z.
* We then ran `scripts/review-leg.sh` with the same stubs. `scripts/native-python-observe.sh` read the lock and the venv from the OCI copy, as it reads them from GHCR in CI.
* We also ran the image as UID 1001 with `LITELLM_MASTER_KEY` and the default config: `/health/liveliness` gave 200 after 8 seconds, `/v1/models` gave 200 with the key and 401 without it, and `/ui/` gave 200. `import redis, hiredis` worked (8.1.0, 3.5.0). The image had no `node`, no `npm` and no `pip` command.

## Result

| Severity | Count | With a fix |
|---|---:|---:|
| Critical | 0 | 0 |
| High | 22 | 14 |
| Medium | 148 | 9 |
| Low | 87 | 0 |

* Python distributions: 0 findings of any severity.
* The 14 fixable Highs: `krb5-libs-1.21.1-10.el9_8.1` (fix `1.21.1-10.el9_9.2`), the same CVEs as in postgresql17 and valkey. UBI did not carry the fix on 2026-11-15.
* The 8 Highs with no fix: `sqlite-libs` (4), `expat` (2), `json-glib` (1) and `python3.12-pip-wheel` (CVE-2026-57585). `python3.12-libs` requires `python3.12-pip-wheel`, the wheel that `ensurepip` uses. The image has no `pip` command, and the venv has no pip.
* The 9 fixable Mediums are in `krb5-libs` (5) and `rpm`/`rpm-libs` (4), all from the base.
* The review gave `PASS` (the entry is in `observe`), namespace `quarantine`, 14 blocking, 0 waived, 8 recorded, and the observation `NATIVE_BUILD` with `litellm==1.109.1` and 117 distributions. The only violations were the 14 `CVE_HIGH_FIXABLE`. The checks "lock sha256 == versions.json pin" and "venv == lock (live)" passed.
* The image was 945 MB. Most of it is the wheels of the `proxy` extra (for example `polars`, `numpy`, `tokenizers` and `boto3`).

## What this does not cover

* arm64. The local host has no arm64 emulation. The CI build job builds arm64 on a native arm64 runner, from the same lock.
* A waiver. No waiver covers litellm. See [The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17](/issues/the-ubi-repositories-do-not-yet-carry-the-krb5-libs-fix-for-14-highs-in-postgresql17--01a1dd21edb8.md).

## Related

* [litellm](/images/litellm--01a1df710394.md)
* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [The first valkey scan found no Critical and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-valkey-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-15--01a1df6016ea.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
