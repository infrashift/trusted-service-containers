---
id: "01a1838a-6c08-7185-a6c3-2b1860afec1d"
title: "Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "dapr"
  - "ory"
  - "seaweedfs"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "Six 30-day waivers accept the go-jose JWK parsing advisory on the dapr images, kratos, oathkeeper and seaweedfs until upstream ships v4.1.6."
x:
  github:
    - 37
  waivers:
    - "EXC-2026-0017"
    - "EXC-2026-0018"
    - "EXC-2026-0019"
    - "EXC-2026-0026"
    - "EXC-2026-0028"
    - "EXC-2026-0029"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-11-27T00:00:00Z"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/38"
    title: "PR #38"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/37"
    title: "GH #37"
---

# Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27

Six waivers accept the High advisory `GHSA-mgcc-cww5-fp2q` in `github.com/go-jose/go-jose/v4` on the dapr, Ory and seaweedfs images. All six expire on 2026-11-27.

## Record

| Waiver | Image | go-jose version (indirect) | Source | Added by |
|---|---|---|---|---|
| `EXC-2026-0017` | `daprd` | v4.1.4 | dapr `v1.18.9` | `003409d`, PR #38 |
| `EXC-2026-0018` | `dapr-placement` | v4.1.4 | dapr `v1.18.9` | `003409d`, PR #38 |
| `EXC-2026-0019` | `dapr-scheduler` | v4.1.4 | dapr `v1.18.9` | `003409d`, PR #38 |
| `EXC-2026-0026` | kratos | v4.1.3 | Ory `v26.2.0` | `501d001`, PR #39 |
| `EXC-2026-0028` | oathkeeper | v4.1.3 | Ory `v26.2.0` | `501d001`, PR #39 |
| `EXC-2026-0029` | seaweedfs | v4.1.5 | seaweedfs `4.51` | `501d001`, PR #39 |

* Variant `*`, package `github.com/go-jose/go-jose/v4`. Issued 2026-10-28. Expires 2026-11-27. Owner `@ryancraig`. Ticket GH #37.
* The window is 30 days. The policy permits 90. The short window is intentional, because the upstream fixes were in progress.

## What it covers

`GHSA-mgcc-cww5-fp2q` is a denial of service when go-jose parses a JWK that contains RSA keys. It was published on 2026-10-27, after each pinned release shipped. The fix is in go-jose v4.1.6.

## Why the waivers exist

* On 2026-10-28, each pinned release was the newest release on its track.
* dapr: on 2026-10-28, the `release-1.18` branch still required v4.1.4. The upstream bump dapr/dapr#10945 was open.
* Ory: on 2026-10-28, no newer release existed. See [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md).
* seaweedfs: on 2026-10-28, the `master` branch already required v4.1.6, but `4.51` was the newest tag.
* We build the upstream source without changes at a pinned commit.

## What removes the need

1. Take the first release on each track that carries go-jose v4.1.6 or later.
2. Delete the waiver for that image.
3. Before 2026-11-27, renew each remaining waiver with a new review, or remove it.

## Related

* [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md)
* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md)
* [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
* [seaweedfs](/images/seaweedfs--01a183832ee2.md)
