---
id: "01a1838a-12ff-77d9-9717-89330623a7a0"
title: "The 2026-09-30 drift proposal had wrong crosscheck pins and stale hashes"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "resolved"
  - "drift"
  - "dapr"
  - "nats"
  - "postgres"
  - "traefik"
created: "2026-10-28T12:23:46-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "The 2026-09-30 drift found DHI rebuilds, dapr v1.18.4 and nats v2.14.7; PR #20, #21 and #23 fixed the proposal and merged it."
x:
  github: 19
status: "deprecated"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/19"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/20"
    title: "PR #20"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/21"
    title: "PR #21"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/23"
    title: "PR #23"
---

# The 2026-09-30 drift proposal had wrong crosscheck pins and stale hashes

## Problem

On 2026-09-30, the upstream drift workflow found newer upstream references inside the tracks. The DHI tags of traefik and postgres had new digests for all six variants. The dapr source moved from a pre-release ref of v1.18.4 to the `v1.18.4` tag, and nats moved from `v2.14.5` to `v2.14.7`. The proposal also had errors that a human had to correct before a merge.

## Context

* The bot opened GH #19 with the label `upstream-drift`. It updates one issue and does not open a new one.
* The proposal put the nats 2.14.7 index digest in the amd64 and the arm64 crosscheck slots. These slots must hold the per-platform digests.
* The proposal did not move the dapr crosscheck tags from `1.18.3-linux-*`. It did not update the nats `releaseTarballSha256` values.
* The `shortCommit` that the proposal computed for nats had 8 characters. The release binaries embed 9 characters. `scripts/drift-upstream.sh` used a blobless clone, which gives shorter abbreviations.

## Acceptance criteria

- [x] The drift proposal pins each crosscheck per platform.
- [x] The dapr crosscheck tags and the nats tarball hashes match the new source refs.
- [x] A PR merges the new pins, and the bot closes the issue.

## Resolution

Resolved on 2026-09-30.

* PR #20 (merged 2026-09-30): the drift job pins crosschecks per platform and flags the values that a bump cannot move.
* PR #21 (merged 2026-09-30): the drift proposal plus the hand re-pins of the dapr crosschecks, the nats tarball hashes and the nats `shortCommit`. PR #21 closed GH #19.
* PR #21 also added waivers `EXC-2026-0008` to `EXC-2026-0016` for findings that no in-track bump cleared. See [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md).
* PR #23 (merged 2026-09-30): `scripts/drift-upstream.sh` computes `shortCommit` in a full clone.

## Related

* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [On 2026-09-30 the new postgres 16 digest had fewer findings and postgres did not link libcurl](/findings/on-2026-09-30-the-new-postgres-16-digest-had-fewer-findings-and-postgres-did-not-link-libcurl--01a1838a6ec1.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [nats](/images/nats--01a183832e00.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
