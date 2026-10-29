---
id: "01a1838a-6c7a-7e10-90ea-4b7cabb81880"
title: "Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "ory"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "Seven waivers accept the October x/net HTTP/2 and x/text advisories in the four Ory images; the owner must decide again at expiry."
x:
  github:
    - 7
  waivers:
    - "EXC-2026-0020"
    - "EXC-2026-0021"
    - "EXC-2026-0022"
    - "EXC-2026-0023"
    - "EXC-2026-0024"
    - "EXC-2026-0025"
    - "EXC-2026-0027"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-11-27T00:00:00Z"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/7"
    title: "GH #7"
---

# Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27

Seven waivers accept the October `golang.org/x/net` and `golang.org/x/text` advisories in the four Ory images at `v26.2.0`. All seven expire on 2026-11-27.

## Record

| Waiver | Image | Package | Advisories |
|---|---|---|---|
| `EXC-2026-0020` | hydra | `golang.org/x/net` v0.48.0 | `GO-2026-6603`, `-6611`, `-6612` (Critical), `-6617` |
| `EXC-2026-0021` | hydra | `golang.org/x/text` v0.32.0 | `GO-2026-6629` |
| `EXC-2026-0022` | keto | `golang.org/x/net` v0.48.0 | `GO-2026-6603`, `-6611`, `-6612` (Critical), `-6617` |
| `EXC-2026-0023` | keto | `golang.org/x/text` v0.32.0 | `GO-2026-6629` |
| `EXC-2026-0024` | kratos | `golang.org/x/net` v0.48.0 | `GO-2026-6603`, `-6611`, `-6612` (Critical), `-6617` |
| `EXC-2026-0025` | kratos | `golang.org/x/text` v0.32.0 | `GO-2026-6629` |
| `EXC-2026-0027` | oathkeeper | `golang.org/x/net` v0.48.0 | `GO-2026-6603`, `-6610`, `-6611`, `-6612` (Critical), `-6617` |

* Variant `*`. Issued 2026-10-28. Expires 2026-11-27. Owner `@ryancraig`. Ticket GH #7.
* Added by `501d001`, PR #39 (merged 2026-10-28).

## What it covers

* The `x/net` advisories of 2026-10-08 are HTTP/2 denial-of-service issues: memory, CPU and flow control. `GO-2026-6612` is Critical. The fix is in `x/net` v0.60.0.
* `GO-2026-6629` (2026-10-07) is a panic on crafted input to `x/text/secure/precis`. The fix is in `x/text` v0.41.0.

## Why the waivers exist

* On 2026-10-28, `v26.2.0` (2026-03-20) was still the newest release of all four services.
* On 2026-10-28, the last commits on the Ory `master` branches were from 2026-07-27 to 2026-07-29. These branches required `x/net` v0.56.0. Thus a pin of an untagged commit does not clear the findings either.
* On 2026-10-28, the owner accepted the risk so that the stack could ship on the current base and toolchain. GH #7 still asks whether to keep Ory.
* The justification says: decide again at the expiry. Do not renew without a decision.

## What removes the need

1. An Ory release on the track with `x/net` v0.60.0 and `x/text` v0.41.0 or later.
2. Or the removal of the Ory images. See [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md).
3. At 2026-11-27, decide again. `EXC-2026-0004` to `EXC-2026-0007` expire five days earlier, so review the whole Ory register at the same time.

## Related

* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md)
* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
