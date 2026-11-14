---
id: "01a1dc1c-cc29-71f3-9d54-3b6119ec07c2"
title: "Three waivers accept GO-2026-6860 in hydra, keto and kratos until 2026-11-27"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "ory"
created: "2026-11-14T16:10:37-06:00"
timestamp: "2026-11-14T16:10:37-06:00"
description: "Three waivers accept the x/net/html advisory GO-2026-6860 in hydra, keto and kratos v26.2.0; the owner must decide again at expiry."
x:
  waivers:
    - "EXC-2026-0030"
    - "EXC-2026-0031"
    - "EXC-2026-0032"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-11-27T00:00:00Z"
---

# Three waivers accept GO-2026-6860 in hydra, keto and kratos until 2026-11-27

Three waivers accept `GO-2026-6860` in `golang.org/x/net` in three Ory images at `v26.2.0`. All three expire on 2026-11-27.

## Record

| Waiver | Image | Package | Advisory |
|---|---|---|---|
| `EXC-2026-0030` | hydra | `golang.org/x/net` v0.48.0 | `GO-2026-6860` |
| `EXC-2026-0031` | keto | `golang.org/x/net` v0.48.0 | `GO-2026-6860` |
| `EXC-2026-0032` | kratos | `golang.org/x/net` v0.48.0 | `GO-2026-6860` |

* Variant `*`. Issued 2026-11-14. Expires 2026-11-27. Owner `@ryancraig`.
* The ticket is [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md).
* oathkeeper needs no waiver for this advisory. Its legs passed the reviews of PR #46 and PR #49.

## What it covers

* `GO-2026-6860` (CVE-2026-78661, published 2026-10-27) is a quadratic-complexity denial of service in `x/net/html`, when it coalesces text nodes of crafted HTML.
* The fix is in `x/net` v0.62.0.
* The reviews of PR #46 and PR #49 on 2026-11-14 blocked hydra, keto and kratos with this advisory, as `CVE_HIGH_FIXABLE`.

## Why the waivers exist

* On 2026-11-14, `v26.2.0` was still the newest release of the Ory services.
* On 2026-11-14, the Ory `master` branches of hydra, keto and kratos required `x/net` v0.56.0. Thus a pin of an untagged commit does not clear the finding.
* HALO and Chit use kratos and hydra. They moved from keto to keto-cue (PR #47). No known consumer needs the keto image. Remove it rather than renew its waiver.
* The waivers expire with the October `x/net` waivers, so the owner decides on the whole Ory register at one time.

## What removes the need

1. An Ory release on the track with `x/net` v0.62.0 or later.
2. Or the removal of an Ory image. The keto image is the first candidate.
3. At 2026-11-27, decide again. Do not renew without a decision.
