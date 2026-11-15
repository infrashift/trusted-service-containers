---
id: "01a1dce6-a75b-717b-ba03-5f47df12279e"
title: "daprd and prometheus carry brotli and compress findings until upstream releases a fix"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "cve"
  - "waiver"
  - "dapr"
  - "prometheus"
created: "2026-11-14T19:51:06-06:00"
timestamp: "2026-11-14T19:51:06-06:00"
description: "On 2026-11-14, dapr v1.18.10 and prometheus v3.15.1 carried GO-2026-6888 and GO-2026-6865, and no release in the track had the fix."
---

# daprd and prometheus carry brotli and compress findings until upstream releases a fix

## Problem

On 2026-11-14, the reviews of PR #46 to PR #52 blocked two build images on Go module findings in their pinned upstream source:

| Image | Upstream pin | Finding | Package |
|---|---|---|---|
| daprd | dapr `v1.18.10` | `GO-2026-6888` (Critical) | `github.com/andybalholm/brotli` |
| daprd | dapr `v1.18.10` | `GO-2026-6865` (High) | `github.com/klauspost/compress` |
| prometheus | prometheus `v3.15.1` | `GO-2026-6865` (High) | `github.com/klauspost/compress` |

## Context

* On 2026-11-14, `v1.18.10` was the newest dapr release in its track, and `v3.15.1` was the newest prometheus release in its track. PR #52 pins dapr `v1.18.10`.
* We build upstream source without changes. Thus only an upstream release with the fixed modules clears the findings.
* Waivers `EXC-2026-0039` (daprd) and `EXC-2026-0040` (prometheus) accept the findings until 2026-12-14.

## Acceptance criteria

- [ ] An upstream release in the track clears the findings, and a re-pin removes the waivers.
- [ ] Or, before 2026-12-14, a new review renews or removes the waivers.
