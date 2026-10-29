---
id: "01a1838a-14d3-7cde-ab08-9bad976b557d"
title: "The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "cve"
  - "waiver"
  - "dapr"
  - "ory"
  - "seaweedfs"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "dapr, kratos, oathkeeper and seaweedfs carry go-jose below v4.1.6 and no release on their tracks fixes it; six waivers expire 2026-11-27."
x:
  github: 37
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
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/37"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/38"
    title: "PR #38"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39"
---

# The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix

## Problem

The advisory `GHSA-mgcc-cww5-fp2q` (High) in `github.com/go-jose/go-jose/v4` blocks six images, and no upstream release on their tracks has the fix. The advisory is a denial of service when go-jose parses a JWK with RSA keys. It was published on 2026-10-27. The fix is in go-jose v4.1.6.

## Context

| Image | Source | go-jose version (indirect) | Waiver |
|---|---|---|---|
| `daprd`, `dapr-placement`, `dapr-scheduler` | dapr `v1.18.9` | v4.1.4 | `EXC-2026-0017` to `EXC-2026-0019` |
| `kratos`, `oathkeeper` | Ory `v26.2.0` | v4.1.3 | `EXC-2026-0026`, `EXC-2026-0028` |
| `seaweedfs` | `4.51` | v4.1.5 | `EXC-2026-0029` |

* The review of PR #36 rebuilt the dapr images on `v1.18.9`. The `x/net`, grpc and amqp091-go findings went away. This one High finding stayed on all three images and both architectures. See [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md).
* On 2026-10-28, dapr `v1.18.9` was the newest tag on the track, and the `release-1.18` branch still required v4.1.4. The upstream bump is dapr/dapr#10945, which was open.
* On 2026-10-28, Ory had no newer release. See [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md).
* On 2026-10-28, the seaweedfs `master` branch already required v4.1.6.
* All six waivers expire on 2026-11-27. See [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md).

## Acceptance criteria

- [ ] The dapr, Ory and seaweedfs pins move to releases that carry go-jose v4.1.6 or later.
- [ ] A change removes `EXC-2026-0017` to `EXC-2026-0019`, `EXC-2026-0026`, `EXC-2026-0028` and `EXC-2026-0029`.
- [ ] Before 2026-11-27, a new review renews each waiver that is still necessary.

## Analysis

The next seaweedfs release will probably clear the finding, because its `master` branch already requires v4.1.6.

## Related

* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md)
* [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md)
* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
* [seaweedfs](/images/seaweedfs--01a183832ee2.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
