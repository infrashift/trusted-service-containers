---
id: "01a1838a-1296-7eed-a96c-85f3836182bb"
title: "No Ory release clears the Go dependency findings in the four Ory images"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "ory"
  - "cve"
  - "waiver"
created: "2026-10-28T12:23:46-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "On 2026-10-28, Ory v26.2.0 was the newest release and carried blocking Go module findings; a keep-or-remove decision is due before 2026-11-22."
x:
  github: 7
  waivers:
    - "EXC-2026-0004"
    - "EXC-2026-0005"
    - "EXC-2026-0006"
    - "EXC-2026-0007"
    - "EXC-2026-0020"
    - "EXC-2026-0021"
    - "EXC-2026-0022"
    - "EXC-2026-0023"
    - "EXC-2026-0024"
    - "EXC-2026-0025"
    - "EXC-2026-0027"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/7"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39"
---

# No Ory release clears the Go dependency findings in the four Ory images

## Problem

The four Ory images (`hydra`, `kratos`, `keto` and `oathkeeper`) have blocking findings in vendored Go dependencies, and no upstream release clears them. On 2026-10-28, all four were pinned at Ory `v26.2.0` (2026-03-20), the newest release. The four services release together from one tag. Thus no partial bump is possible. A decision is necessary: keep the Ory stack under waivers, or remove it.

## Context

* On 2026-08-25, GH #7 recorded findings in `google.golang.org/grpc`, `golang.org/x/net`, `golang.org/x/text`, `go-jose`, `go.opentelemetry.io/otel`, `github.com/docker/docker` and `github.com/jackc/pgx/v5` (Critical). hydra also had `GHSA-r9w3-57w2-gch2` against `github.com/ory/hydra/v2`. See [The first Ory scans found vendored Go findings in all four images on 2026-08-24](/findings/the-first-ory-scans-found-vendored-go-findings-in-all-four-images-on-2026-08-24--01a1838a6e4f.md).
* We build upstream source without changes. To clear the findings, we must fork the source and change `go.mod`. That breaks the build track model.
* On 2026-10-28, the owner decided to release the Ory stack under waivers with a time limit. The October `x/net`, `x/text` and `go-jose` advisories also affect `v26.2.0`. The Ory `master` branch (last commit 2026-07-29) has `x/net` v0.56.0. The fix is in v0.60.0.
* After PR #39, all eight Ory legs got `PASS` and went to `trusted/`. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).
* The waivers that cite this issue expire on two dates:

| Waivers | Expiry | Finding |
|---|---|---|
| `EXC-2026-0004` to `EXC-2026-0007` | 2026-11-22 | [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md) |
| `EXC-2026-0020` to `EXC-2026-0025`, `EXC-2026-0027` | 2026-11-27 | [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md) |

* The Ory `grpc` waivers (`EXC-2026-0009` to `EXC-2026-0012`) cite GH #22, not this issue. They expire on 2026-12-29. See [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md).

## Acceptance criteria

- [ ] Before 2026-11-22, a decision records whether this project keeps the Ory images.
- [ ] If the project keeps them: a new review renews each Ory waiver before its expiry. Alternatively, an Ory release on the track clears the findings.
- [ ] If the project removes them: a change removes the Ory entries from `versions.json` and the Ory waivers.

## Related

* [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md)
* [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md)
* [The first Ory scans found vendored Go findings in all four images on 2026-08-24](/findings/the-first-ory-scans-found-vendored-go-findings-in-all-four-images-on-2026-08-24--01a1838a6e4f.md)
* [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
