---
id: "01a1838a-135e-735e-acd7-f9192138eb03"
title: "The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "cve"
  - "waiver"
  - "postgres"
  - "ory"
  - "dapr"
created: "2026-10-28T12:23:46-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "PR #21 waived libcurl, grpc and amqp091-go findings until 2026-12-29; dapr v1.18.9 later cleared the dapr part."
x:
  github: 22
  waivers:
    - "EXC-2026-0008"
    - "EXC-2026-0009"
    - "EXC-2026-0010"
    - "EXC-2026-0011"
    - "EXC-2026-0012"
    - "EXC-2026-0013"
    - "EXC-2026-0014"
    - "EXC-2026-0015"
    - "EXC-2026-0016"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/22"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/21"
    title: "PR #21"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/38"
    title: "PR #38"
---

# The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears

## Problem

The 2026-09-30 drift (PR #21) left blocking findings that no bump inside the tracks clears. These findings are in `libcurl4t64` in postgres, in `google.golang.org/grpc` in the Ory and dapr images, and in `github.com/rabbitmq/amqp091-go` in `daprd`. PR #21 added nine waivers for them. These waivers expire on 2026-12-29.

## Context

* Each finding was also present in the digest that was in `trusted/` before PR #21. The new pins did not add a finding.
* postgres: Debian has no fixed `libcurl4t64` package. Neither `/usr/bin/postgres` nor its JIT links libcurl. See [On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl](/findings/on-2026-09-30-the-new-postgres-16-digest-had-fewer-findings-and-postgres-did-not-link-libcurl--01a1838a6ec1.md) and [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md).
* grpc: Ory `v26.2.0` vendors grpc v1.79.3. dapr `v1.18.4` vendored v1.82.1. The fix is in grpc 1.82.2 and 1.83.1. See [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md).
* amqp091-go: dapr `v1.18.4` pinned v1.10.0. The fix is in 1.13.0. `daprd` compiles the RabbitMQ component because the build uses `-tags allcomponents`. The one consumer does not load a RabbitMQ component. See [Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29](/findings/waiver-exc-2026-0016-accepts-amqp091-go-findings-in-daprd-until-2026-12-29--01a1838a6b8d.md).
* On 2026-10-28, dapr `v1.18.9` cleared the grpc and amqp091-go findings on all three dapr images. Thus `EXC-2026-0013` to `EXC-2026-0016` waive no finding now. See [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md) and [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md).
* On 2026-10-28, `EXC-2026-0008` still waived 2 findings on each postgres leg, and `EXC-2026-0009` to `EXC-2026-0012` still waived grpc findings on the Ory legs. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

## Acceptance criteria

- [ ] A change removes `EXC-2026-0013` to `EXC-2026-0016`, because dapr `v1.18.9` cleared their findings.
- [ ] Before 2026-12-29, a new scan of postgres and of the Ory images gives the current findings.
- [ ] A new review renews each remaining waiver, or a change removes it.
- [ ] A decision records whether a `daprd` build without `allcomponents` is worth its maintenance cost.

## Related

* [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29](/findings/waiver-exc-2026-0016-accepts-amqp091-go-findings-in-daprd-until-2026-12-29--01a1838a6b8d.md)
* [On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl](/findings/on-2026-09-30-the-new-postgres-16-digest-had-fewer-findings-and-postgres-did-not-link-libcurl--01a1838a6ec1.md)
* [The 2026-09-30 drift proposal had wrong crosscheck pins and stale hashes](/issues/the-2026-09-30-drift-proposal-had-wrong-crosscheck-pins-and-stale-hashes--01a1838a12ff.md)
* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [postgres](/images/postgres--01a183832d06.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
