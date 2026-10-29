---
id: "01a1838a-17b7-7b4a-8886-86eb322455a8"
title: "Five waivers match no finding after the October rebuilds"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "waiver"
  - "cve"
  - "dapr"
  - "postgres"
  - "traefik"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "On 2026-10-28, EXC-2026-0003 and EXC-2026-0013 to 0016 waived nothing, and EXC-2026-0002 matched 7 of its 15 ids."
x:
  github:
    - 22
    - 6
  waivers:
    - "EXC-2026-0002"
    - "EXC-2026-0003"
    - "EXC-2026-0013"
    - "EXC-2026-0014"
    - "EXC-2026-0015"
    - "EXC-2026-0016"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/39"
    title: "PR #39 review comment"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/38"
    title: "PR #38"
---

# Five waivers match no finding after the October rebuilds

## Problem

Five waivers in `.github/pdp/exceptions.yaml` waive no finding, and one waives only part of its list. A waiver that matches nothing hides no risk now. But it can match a new finding with the same id later, and the old justification does not apply to that finding.

## Context

On 2026-10-28, the review of PR #39 listed every waived finding with its waiver id. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

| Waiver | Image | Waived on 2026-10-28 | Reason |
|---|---|---|---|
| `EXC-2026-0003` | traefik `dev` | 0 of 6 ids | The DHI image changed. `traefik-dev` had 86 blocking findings that no waiver covers. |
| `EXC-2026-0013` | `daprd` | 0 | dapr `v1.18.9` cleared the grpc findings. |
| `EXC-2026-0014` | `dapr-placement` | 0 | dapr `v1.18.9` cleared the grpc findings. |
| `EXC-2026-0015` | `dapr-scheduler` | 0 | dapr `v1.18.9` cleared the grpc findings. |
| `EXC-2026-0016` | `daprd` | 0 | dapr `v1.18.9` cleared the amqp091-go findings. |
| `EXC-2026-0002` | postgres | 7 of 15 ids | The DHI image changed. 8 ids are no longer reported. |

* PR #38 says that `EXC-2026-0013` to `EXC-2026-0016` waive nothing on `v1.18.9`, and leaves their removal to a separate change.
* The PDP does not report a waiver that matches no finding.

## Acceptance criteria

- [ ] A change removes `EXC-2026-0013` to `EXC-2026-0016`.
- [ ] A change removes `EXC-2026-0003`, or a new triage of `traefik-dev` replaces it.
- [ ] `EXC-2026-0002` lists only the ids that the current postgres digests report, or a new triage replaces it.
- [ ] A decision records whether the PDP or the review comment reports a waiver that matches no finding.

## Related

* [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29](/findings/waiver-exc-2026-0016-accepts-amqp091-go-findings-in-daprd-until-2026-12-29--01a1838a6b8d.md)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
