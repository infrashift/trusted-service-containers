---
id: "01a1df9f-1d8d-7115-9ed5-7a92a3214cf1"
title: "Two waivers accept the krb5-libs Highs in valkey and litellm until 2026-12-15"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "valkey"
  - "litellm"
created: "2026-11-15T08:31:49-06:00"
timestamp: "2026-11-15T08:31:49-06:00"
description: "EXC-2026-0042 and EXC-2026-0043 accept the 14 krb5-libs Highs of the ubi9-minimal base in valkey and litellm until 2026-12-15, by the owner's decision of 2026-11-15."
x:
  waivers:
    - "EXC-2026-0042"
    - "EXC-2026-0043"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-12-15T00:00:00Z"
status: "draft"
---

# Two waivers accept the krb5-libs Highs in valkey and litellm until 2026-12-15

Two waivers accept the 14 fixable `krb5-libs` Highs of the `ubi9-minimal` base in [valkey](/images/valkey--01a1df5f8878.md) and [litellm](/images/litellm--01a1df710394.md) until 2026-12-15.

## Record

| Waiver | Image | Package | Advisories |
|---|---|---|---|
| `EXC-2026-0042` | valkey | `krb5-libs` | the 14 CVEs below |
| `EXC-2026-0043` | litellm | `krb5-libs` | the 14 CVEs below |

* The CVEs: CVE-2026-71199, CVE-2026-71200, CVE-2026-107364, CVE-2026-112315 to CVE-2026-112323, CVE-2026-118380 and CVE-2026-119079. It is the same set as `EXC-2026-0041` for postgresql17.
* Both images have `krb5-libs-1.21.1-10.el9_8.1`. grype gives the fix as `1.21.1-10.el9_9.2`.
* Issued 2026-11-15. Expires 2026-12-15 (30 days, as `EXC-2026-0041`). Owner `@ryancraig`.
* The ticket is [The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17](/issues/the-ubi-repositories-do-not-yet-carry-the-krb5-libs-fix-for-14-highs-in-postgresql17--01a1dd21edb8.md).

## Why the waivers exist

* On 2026-11-15 the owner decided: "Waive krb5-libs for Valkey and LiteLLM".
* On 2026-11-15 `ubi-9-baseos` still had only `krb5-libs-1.21.1-10.el9_8.1` (x86_64 revision 1794413174, aarch64 1794416385). The runtime stage of each image already upgrades the base from UBI. Thus no rebuild and no re-pin clears the findings.
* `krb5-libs` is a base package. It is not a Valkey dependency and not a locked wheel.
* The first reviews (PR #59 and PR #60) had these 14 findings as the only blocking findings on each leg. With the waivers, the legs have 0 blocking findings and go to `trusted/`, also in `observe`.

## What the waivers do not cover

* Another package, or a CVE outside the set. The policy tests `test_register_krb5_waiver_is_package_scoped` and `test_register_krb5_waiver_is_cve_scoped` hold the scope.
* The Highs with no fix (`sqlite-libs`, `json-glib`, `expat`, `python3.12-pip-wheel`). They are recorded, not blocking.

## What removes the need

1. UBI publishes `krb5-libs-1.21.1-10.el9_9.2` or later. Rebuild valkey and litellm, and delete both entries and the `test_register_*` tests.
2. At 2026-12-15, decide again. Do not renew without a decision.

## Related

* [The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17](/issues/the-ubi-repositories-do-not-yet-carry-the-krb5-libs-fix-for-14-highs-in-postgresql17--01a1dd21edb8.md)
* [The first valkey scan found no Critical and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-valkey-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-15--01a1df6016ea.md)
* [The first litellm scan found no Python finding and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-litellm-scan-found-no-python-finding-and-14-krb5-libs-highs-on-2026-11-15--01a1df7103a8.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
