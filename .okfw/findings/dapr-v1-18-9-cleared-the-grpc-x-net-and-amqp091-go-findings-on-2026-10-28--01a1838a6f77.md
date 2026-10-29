---
id: "01a1838a-6f77-7c14-ac30-a2ed6f639901"
title: "dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "cve"
  - "dapr"
created: "2026-10-28T12:24:10-05:00"
timestamp: "2026-10-28T12:24:34-05:00"
description: "The rebuild of the three dapr images on v1.18.9 removed the grpc, x/net and amqp091-go findings; one go-jose High finding stayed."
x:
  github:
    - 37
  waivers:
    - "EXC-2026-0017"
    - "EXC-2026-0018"
    - "EXC-2026-0019"
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:34-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues/37"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/36"
    title: "PR #36 review comment"
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/38"
    title: "PR #38 review comment"
---

# dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28

On 2026-10-28, the review of PR #36 rebuilt the three dapr images on dapr `v1.18.9`. The `x/net`, grpc and amqp091-go findings were gone. One High finding in go-jose stayed.

## Source of the measurement

* The review of PR #36 (dapr `v1.18.9` and loki `v3.7.9`, merged 2026-10-28), reported in GH #37.
* The review of PR #38 (2026-10-28) confirmed the result after waivers `EXC-2026-0017` to `EXC-2026-0019`.

## Result

| Image | Platforms | Remaining blocking finding |
|---|---|---|
| `daprd` | amd64, arm64 | `GHSA-mgcc-cww5-fp2q`, go-jose/v4 v4.1.4 |
| `dapr-placement` | amd64, arm64 | `GHSA-mgcc-cww5-fp2q`, go-jose/v4 v4.1.4 |
| `dapr-scheduler` | amd64, arm64 | `GHSA-mgcc-cww5-fp2q`, go-jose/v4 v4.1.4 |

* The fix for `GHSA-mgcc-cww5-fp2q` is in go-jose v4.1.6.
* After PR #38, all six dapr legs got `PASS` with Blocking 0 and Waived 1, and went to `trusted/`.
* `EXC-2026-0013` to `EXC-2026-0016` matched no finding on `v1.18.9`.

## Related

* [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md)
* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md)
* [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md)
* [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md)
* [Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29](/findings/waiver-exc-2026-0016-accepts-amqp091-go-findings-in-daprd-until-2026-12-29--01a1838a6b8d.md)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
