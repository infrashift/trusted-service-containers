---
id: "01a1838a-6e4f-77ef-adee-5181aff4aa8c"
title: "The first Ory scans found vendored Go findings in all four images on 2026-08-24"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "ory"
created: "2026-10-28T12:24:09-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "The first scans of hydra, kratos, keto and oathkeeper at v26.2.0 found blocking findings in seven vendored Go modules, one Critical."
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
resource: "https://github.com/infrashift/trusted-service-containers/issues/7"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
---

# The first Ory scans found vendored Go findings in all four images on 2026-08-24

The first scans of the four Ory images at `v26.2.0` found blocking findings in vendored Go modules. One finding, in `github.com/jackc/pgx/v5`, was Critical.

## Source of the measurement

* GH #7, opened on 2026-08-25.
* Waivers `EXC-2026-0004` to `EXC-2026-0007`, issued 2026-08-24.

## Result

| Image | Advisories in the waiver |
|---|---:|
| hydra | 8 |
| kratos | 7 |
| keto | 6 |
| oathkeeper | 6 |

* The modules are `google.golang.org/grpc`, `golang.org/x/net`, `golang.org/x/text`, `go-jose`, `go.opentelemetry.io/otel`, `github.com/docker/docker` and `github.com/jackc/pgx/v5`.
* hydra also had `GHSA-r9w3-57w2-gch2` against `github.com/ory/hydra/v2`.
* `v26.2.0` (2026-03-20) was the newest release of all four services.

## Later measurements

* 2026-09-30: PR #21 added waivers for two grpc advisories. See [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md).
* 2026-10-28: PR #39 added waivers for the October `x/net`, `x/text` and `go-jose` advisories. See [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md) and [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md).

## Related

* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md)
* [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
