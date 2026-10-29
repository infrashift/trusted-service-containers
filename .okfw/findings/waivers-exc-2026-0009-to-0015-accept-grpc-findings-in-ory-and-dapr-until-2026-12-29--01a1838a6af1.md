---
id: "01a1838a-6af1-7ca2-ac40-ce692f4c4c3d"
title: "Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "ory"
  - "dapr"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "Seven waivers accept two High grpc advisories in the Ory and dapr images; dapr v1.18.9 cleared the dapr part on 2026-10-28."
x:
  github:
    - 22
  waivers:
    - "EXC-2026-0009"
    - "EXC-2026-0010"
    - "EXC-2026-0011"
    - "EXC-2026-0012"
    - "EXC-2026-0013"
    - "EXC-2026-0014"
    - "EXC-2026-0015"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-12-29T00:00:00Z"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/21"
    title: "PR #21"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/22"
    title: "GH #22"
---

# Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29

Waivers `EXC-2026-0009` to `EXC-2026-0015` accept two High `google.golang.org/grpc` advisories in the Ory and dapr images. All seven expire on 2026-12-29.

## Record

| Waiver | Image | grpc version (2026-09-30) |
|---|---|---|
| `EXC-2026-0009` | hydra | v1.79.3 (Ory `v26.2.0`) |
| `EXC-2026-0010` | kratos | v1.79.3 |
| `EXC-2026-0011` | keto | v1.79.3 |
| `EXC-2026-0012` | oathkeeper | v1.79.3 |
| `EXC-2026-0013` | `daprd` | v1.82.1 (dapr `v1.18.4`) |
| `EXC-2026-0014` | `dapr-placement` | v1.82.1 |
| `EXC-2026-0015` | `dapr-scheduler` | v1.82.1 |

* Advisories: `GHSA-2v4p-qf9q-27wj` and `GHSA-vp52-pcj8-j9qc` (High). Package `google.golang.org/grpc`. Variant `*`.
* Issued 2026-09-30. Expires 2026-12-29. Owner `@ryancraig`. Ticket GH #22.
* Added by `670d7d7`, PR #21 (2026-09-30).

## Why the waivers exist

* The fix is in grpc 1.82.2 and 1.83.1.
* On 2026-09-30, Ory `v26.2.0` and dapr `v1.18.4` were the newest upstream releases.
* We build the upstream source without changes at a pinned commit. To clear the findings, we need an upstream release or a fork of `go.mod`.
* The same findings were in the digests in `trusted/` before PR #21.

## What removes the need

1. dapr: dapr `v1.18.9` cleared these findings on 2026-10-28. Remove `EXC-2026-0013` to `EXC-2026-0015`. See [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md).
2. Ory: an Ory release on the track with grpc 1.82.2 or later, or the removal of the Ory images. See [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md).
3. Before 2026-12-29, renew the Ory waivers with a new review, or remove them.

## Related

* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md)
* [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
