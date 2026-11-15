---
id: "01a1df60-16ea-7d3a-9071-b8be035acde5"
title: "The first valkey scan found no Critical and 14 krb5-libs Highs on 2026-11-15"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "valkey"
  - "cve"
  - "native"
created: "2026-11-15T07:22:58-06:00"
timestamp: "2026-11-15T07:22:58-06:00"
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/valkey.Containerfile"
sources:
  - resource: "https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/baseos/os/repodata/repomd.xml"
    title: "UBI 9 BaseOS repository metadata"
description: "The first local build of valkey 9.1.3 on amd64 had no Critical, 14 fixable krb5-libs Highs that UBI does not carry yet, and 5 unfixable Highs."
---

# The first valkey scan found no Critical and 14 krb5-libs Highs on 2026-11-15

On 2026-11-15, the first local build of [valkey](/images/valkey--01a1df5f8878.md) 9.1.3 on amd64 had no Critical. It had 14 fixable Highs, all in `krb5-libs`, and 5 Highs with no fix. All findings are in UBI packages. The scan found no finding in Valkey.

## Method

* We ran `scripts/build-leg.sh` for `valkey-runtime` on amd64, with stubs only for the registry push and for cosign. The build fetched the pinned commit, checked the release archive (1925 files, tree equal), compiled on the pinned `ubi9-minimal` builder and ran both smoke tests (a TLS `PING` in the builder, a `PING` with persistence off in the runtime stage).
* The scan is the `grype` step of the build leg on the OCI copy of the image. grype 0.115.0, database built 2026-11-15T06:19:39Z.
* We then ran `scripts/review-leg.sh` with the same stubs, so the policy evaluated the real evidence.

## Result

| Severity | Count | With a fix |
|---|---:|---:|
| Critical | 0 | 0 |
| High | 19 | 14 |
| Medium | 88 | 9 |
| Low | 80 | 0 |

* The 14 fixable Highs are the same `krb5-libs` CVEs as in postgresql17: CVE-2026-71199, CVE-2026-71200, CVE-2026-107364, CVE-2026-112315 to CVE-2026-112323, CVE-2026-118380 and CVE-2026-119079. The image has `krb5-libs-1.21.1-10.el9_8.1`, and grype gives the fix as `1.21.1-10.el9_9.2`. On 2026-11-15, `ubi-9-baseos` had only `1.21.1-10.el9_8.1` (x86_64 revision 1794413174, aarch64 1794416385). Thus no rebuild clears them yet.
* `krb5-libs` comes from the `ubi9-minimal` base. Valkey does not link it.
* The 5 Highs with no fix: CVE-2026-119373, CVE-2026-119374, CVE-2026-119379 and CVE-2026-119586 in `sqlite-libs-3.34.1-11.el9_8`, and CVE-2026-120194 in `json-glib-1.6.6-1.el9`. Both packages come from the base.
* The review gave `PASS` (the entry is in `observe`), namespace `quarantine`, 14 blocking, 0 waived, 5 recorded, and the observation `NATIVE_BUILD`. The only violations were the 14 `CVE_HIGH_FIXABLE`.
* The image was 185 MB. `valkey-server` had sha256 `d716bd5d7d5d3dbc68f8bd6d28aee78ea8b94f0871a8a5be0b81db088c9d906d`.

## What this does not cover

* arm64. The local host has no arm64 emulation. The CI build job builds arm64 on a native arm64 runner.
* A waiver. No waiver covers valkey. See [The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17](/issues/the-ubi-repositories-do-not-yet-carry-the-krb5-libs-fix-for-14-highs-in-postgresql17--01a1dd21edb8.md).

## Related

* [valkey](/images/valkey--01a1df5f8878.md)
* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [The first postgresql17 scan found no Critical and 14 krb5-libs Highs on 2026-11-14](/findings/the-first-postgresql17-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-14--01a1dd2247cf.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
