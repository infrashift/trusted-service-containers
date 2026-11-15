---
id: "01a1dce6-a76a-783e-85a9-2e25a4c6a68e"
title: "Two waivers accept the dapr and prometheus module findings until 2026-12-14"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "dapr"
  - "prometheus"
created: "2026-11-14T19:51:06-06:00"
timestamp: "2026-11-14T19:51:06-06:00"
description: "EXC-2026-0039 and EXC-2026-0040 accept GO-2026-6888 and GO-2026-6865 in daprd and prometheus until 2026-12-14."
x:
  waivers:
    - "EXC-2026-0039"
    - "EXC-2026-0040"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-12-14T00:00:00Z"
---

# Two waivers accept the dapr and prometheus module findings until 2026-12-14

Two waivers accept the Go module findings of dapr `v1.18.10` and prometheus `v3.15.1` until 2026-12-14.

## Record

| Waiver | Image | Advisories |
|---|---|---|
| `EXC-2026-0039` | daprd | `GO-2026-6888` (Critical, `andybalholm/brotli`), `GO-2026-6865` (High, `klauspost/compress`) |
| `EXC-2026-0040` | prometheus | `GO-2026-6865` (High, `klauspost/compress`) |

* Issued 2026-11-14. Expires 2026-12-14. Owner `@ryancraig`.
* The ticket is [daprd and prometheus carry brotli and compress findings until upstream releases a fix](/issues/daprd-and-prometheus-carry-brotli-and-compress-findings-until-upstream-releases-a-fix--01a1dce6a75b.md).

## Why the waivers exist

* PR #52 moved dapr to `v1.18.10`, the newest release in the track. Its review still showed both findings on daprd.
* prometheus `v3.15.1` is the newest release in its track.
* The fixed module versions exist, so a release is probably near. Thus the window is 30 days, not 90.

## What removes the need

1. A dapr or prometheus release in the track with the fixed modules. Re-pin it, and delete the waiver.
2. At 2026-12-14, decide again. Do not renew without a decision.
