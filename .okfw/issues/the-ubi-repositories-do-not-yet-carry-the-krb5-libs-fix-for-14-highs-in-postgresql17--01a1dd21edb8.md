---
id: "01a1dd21-edb8-753b-805c-4ff50371559e"
title: "The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "postgresql17"
  - "valkey"
  - "litellm"
  - "cve"
  - "waiver"
created: "2026-11-14T20:55:50-06:00"
timestamp: "2026-11-14T20:55:50-06:00"
description: "RHEL fixed 14 krb5-libs Highs in 1.21.1-10.el9_9.2; on 2026-11-14 the UBI repositories had only el9_8.1, so postgresql17 waives them until 2026-12-14."
x:
  waivers:
    - "EXC-2026-0041"
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
sources:
  - resource: "https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/baseos/os/repodata/repomd.xml"
    title: "UBI 9 BaseOS repository metadata"
---

# The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17

## Problem

The [postgresql17](/images/postgresql17--01a1dd2247ba.md) image has 14 High findings with a fix in `krb5-libs`. The fix is `krb5-libs-1.21.1-10.el9_9.2`. The UBI repositories do not carry that build. Thus no rebuild and no re-pin clears the findings.

## Context

* `krb5-libs` comes from the base image, `ubi9-minimal`. `libpq` and the server link `libgssapi_krb5`, so the package cannot be removed.
* The base pin was current with the sibling repository on 2026-11-14. That base carried `krb5-libs-1.21.1-10.el9_8`.
* The Containerfile upgrades the base from the signed UBI repositories before it installs PostgreSQL. On 2026-11-14 the newest `krb5-libs` in `ubi-9-baseos` was `1.21.1-10.el9_8.1`. grype (`redhat:distro:redhat:9`) gives the fix as `1.21.1-10.el9_9.2`.
* The UBI repositories already carry other `el9_9` builds, for example `expat-2.5.0-9.el9_9.4`. Thus the fix is probably near.
* The 14 findings: CVE-2026-71199, CVE-2026-71200, CVE-2026-107364, CVE-2026-112315 to CVE-2026-112323, CVE-2026-118380 and CVE-2026-119079.
* `EXC-2026-0041` waives them until 2026-12-14. See [The first postgresql17 scan found no Critical and 14 krb5-libs Highs on 2026-11-14](/findings/the-first-postgresql17-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-14--01a1dd2247cf.md).
* On 2026-11-15 the first [valkey](/images/valkey--01a1df5f8878.md) build had the same 14 findings. It is a native image on the same `ubi9-minimal`, and its runtime stage also upgrades the base from UBI. On 2026-11-15 `ubi-9-baseos` still had only `krb5-libs-1.21.1-10.el9_8.1` (x86_64 revision 1794413174, aarch64 1794416385). No waiver covers valkey: it is in `observe`, and its legs go to `quarantine/` until UBI publishes the fix or the owner decides on a waiver. See [The first valkey scan found no Critical and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-valkey-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-15--01a1df6016ea.md).

## Acceptance criteria

- [ ] `ubi-9-baseos` carries `krb5-libs-1.21.1-10.el9_9.2` or later.
- [ ] A rebuild of postgresql17 shows 0 `krb5-libs` findings.
- [ ] A rebuild of valkey shows 0 `krb5-libs` findings.
- [ ] A rebuild of litellm shows 0 `krb5-libs` findings.
- [ ] A change removes `EXC-2026-0041` from `.github/pdp/exceptions.yaml`.

## Related

* [postgresql17](/images/postgresql17--01a1dd2247ba.md)
* [valkey](/images/valkey--01a1df5f8878.md)
* [litellm](/images/litellm--01a1df710394.md): the same 14 findings on 2026-11-15, no waiver. See [The first litellm scan found no Python finding and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-litellm-scan-found-no-python-finding-and-14-krb5-libs-highs-on-2026-11-15--01a1df7103a8.md).
* [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
