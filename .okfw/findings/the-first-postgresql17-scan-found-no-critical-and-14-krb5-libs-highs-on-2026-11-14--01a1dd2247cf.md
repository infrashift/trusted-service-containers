---
id: "01a1dd22-47cf-7716-81c2-723ab6078e54"
title: "The first postgresql17 scan found no Critical and 14 krb5-libs Highs on 2026-11-14"
type: "finding"
tags:
  - "finding"
  - "cve"
  - "waiver"
  - "postgresql17"
created: "2026-11-14T20:56:13-06:00"
timestamp: "2026-11-14T20:56:13-06:00"
description: "The local amd64 build had 0 Critical and 14 fixable Highs, all in krb5-libs from the base; EXC-2026-0041 waives them until 2026-12-14."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-12-14T00:00:00Z"
x:
  waivers:
    - "EXC-2026-0041"
---

# The first postgresql17 scan found no Critical and 14 krb5-libs Highs on 2026-11-14


On 2026-11-14 the first local amd64 build of [postgresql17](/images/postgresql17--01a1dd2247ba.md) had no Critical finding and 14 fixable High findings. All 14 are in `krb5-libs`, which comes from the base image. `EXC-2026-0041` waives them until 2026-12-14.

## Method

1. Build `Containerfiles/postgresql17.Containerfile` for `linux/amd64` with buildah, with the pins of `versions.json`.
2. Copy the image to an OCI layout with skopeo.
3. Run the two scans of step 6 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md): `grype --fail-on critical` and `grype --only-fixed --fail-on high`.

The local grype was 0.115.0 with the database of 2026-11-14. CI uses the `tools.lock` version, 0.117.0. The review comment gives the CI result.

## Result

| Scan | Result |
|---|---|
| `grype --fail-on critical` | Pass. 0 Critical. |
| `grype --only-fixed --fail-on high` | Fail. 14 fixable High, all `krb5-libs-1.21.1-10.el9_8.1`. |
| All findings | 0 Critical, 22 High, 259 Medium, 99 Low |

The 8 Highs without a fix are in `sqlite-libs` (4), `expat` (2), `json-glib` (1) and `python3-pip-wheel` (1). The policy records them and does not block on them.

For comparison, the review of PR #52 gave 144 blocking findings on each DHI postgres 17 leg.

## Why the 14 Highs are there

* grype gives the fix as `krb5-libs-1.21.1-10.el9_9.2`, from the RHEL 9 data.
* The pinned `ubi9-minimal` carried `1.21.1-10.el9_8`. It was current with the sibling repository.
* The Containerfile upgrades the base from the UBI repositories first. That upgrade gave `1.21.1-10.el9_8.1`, the newest build in `ubi-9-baseos` on 2026-11-14.
* Thus the fix exists in RHEL but not yet in UBI. No rebuild and no re-pin clears it now.

The upgrade step itself was the result of this scan. Without it, the image kept the base's `krb5-libs-1.21.1-10.el9_8`, with the same 14 Highs and 22 more Medium findings.

## Decision

`EXC-2026-0041` waives the 14 CVEs on `krb5-libs` for `postgresql17` for 30 days, until 2026-12-14. The window is short because UBI already carries other `el9_9` builds. See [The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17](/issues/the-ubi-repositories-do-not-yet-carry-the-krb5-libs-fix-for-14-highs-in-postgresql17--01a1dd21edb8.md).

## Related

* [postgresql17](/images/postgresql17--01a1dd2247ba.md)
* [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
