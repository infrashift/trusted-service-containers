---
id: "01a1838a-6a0e-7a4d-b0fc-6df5e38755d3"
title: "Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22"
type: "finding"
tags:
  - "finding"
  - "waiver"
  - "cve"
  - "ory"
created: "2026-10-28T12:24:08-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "Four waivers accept the vendored Go module advisories in hydra, kratos, keto and oathkeeper at v26.2.0, the newest Ory release."
x:
  github:
    - 7
  waivers:
    - "EXC-2026-0004"
    - "EXC-2026-0005"
    - "EXC-2026-0006"
    - "EXC-2026-0007"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-11-22T00:00:00Z"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/4"
    title: "PR #4"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/7"
    title: "GH #7"
---

# Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22

Waivers `EXC-2026-0004` to `EXC-2026-0007` accept the vendored Go dependency advisories in the four Ory images at `v26.2.0`. All four expire on 2026-11-22.

## Record

| Waiver | Image | Advisories |
|---|---|---:|
| `EXC-2026-0004` | hydra | 8 |
| `EXC-2026-0005` | kratos | 7 |
| `EXC-2026-0006` | keto | 6 |
| `EXC-2026-0007` | oathkeeper | 6 |

* Variant `*`, package `*`. Issued 2026-08-24. Expires 2026-11-22. Owner `@ryancraig`. Ticket GH #7.
* Added by `1400b58`, PR #4 (2026-08-24).

## What it covers

Findings in vendored Go modules. The review of PR #39 showed these packages: `google.golang.org/grpc`, `golang.org/x/net`, `golang.org/x/text`, `github.com/go-jose/go-jose/v3` and `/v4`, `go.opentelemetry.io/otel` and `github.com/jackc/pgx/v5`. The pgx advisory `GHSA-xgrm-4fwx-7qm8` is Critical. hydra also had `GHSA-r9w3-57w2-gch2` against `github.com/ory/hydra/v2`.

## Why the waivers exist

* On 2026-10-28, `v26.2.0` (2026-03-20) was the newest Ory release. The four services release together from one tag, so no partial bump exists.
* We build the upstream source without changes. To clear the findings, we must fork the source and change `go.mod`.
* The justification says: waived to a date, not accepted. Decide before the expiry whether to keep the Ory stack.

## What removes the need

1. An Ory release on the track updates the vendored modules.
2. Or the project removes the Ory images. See [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md).
3. Before 2026-11-22, renew the waivers with a new review, or remove them.

## Related

* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md)
* [The first Ory scans found vendored Go findings in all four images on 2026-08-24](/findings/the-first-ory-scans-found-vendored-go-findings-in-all-four-images-on-2026-08-24--01a1838a6e4f.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
