---
id: "01a1838a-6b8d-79e3-9fda-e5c368f0df1c"
title: "Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "dapr"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "EXC-2026-0016 waives 10 amqp091-go advisories that daprd compiles but does not run; dapr v1.18.9 cleared them on 2026-10-28."
x:
  github:
    - 22
  waivers:
    - "EXC-2026-0016"
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

# Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29

Waiver `EXC-2026-0016` accepts 10 advisories in `github.com/rabbitmq/amqp091-go` v1.10.0 in `daprd`. It expires on 2026-12-29.

## Record

| Field | Value |
|---|---|
| Waiver | `EXC-2026-0016` |
| Image | `daprd`, variant `*`, package `github.com/rabbitmq/amqp091-go` |
| Advisories | 10 GHSA ids: 3 Critical, 7 High |
| Issued | 2026-09-30 |
| Expires | 2026-12-29 |
| Owner | `@ryancraig` |
| Ticket | GH #22 |
| Added by | `670d7d7`, PR #21 (2026-09-30) |

## Why the waiver exists

* dapr `v1.18.4` pinned amqp091-go v1.10.0. The fix is in 1.13.0.
* `daprd` compiles the RabbitMQ pubsub and binding only because the build uses `-tags allcomponents`.
* Dapr runs the code of a component only when a manifest of that type is loaded.
* The one consumer, `infrashift/ansible-collection-infrashift-hashistack`, loads `pubsub.jetstream`, `pubsub.kafka` and `bindings.cron`. It loads no RabbitMQ component.
* The same findings were in the digest in `trusted/` before PR #21.

## What removes the need

1. dapr `v1.18.9` cleared these findings on 2026-10-28. See [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md).
2. Remove the waiver. See [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md).

## Related

* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [daprd](/images/daprd--01a183832e23.md)
