---
id: "01a18395-b6bd-7cba-8df2-6c5e5ef67689"
title: "Close the GitHub issues that the wiki now tracks"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "okfw"
  - "github"
created: "2026-10-28T12:36:29-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "After the merge, comment each open GitHub issue with its wiki issue URL and close it, and close the superseded PR #16."
x:
  github:
    - 5
    - 6
    - 7
    - 16
    - 22
    - 24
    - 30
    - 37
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/issues"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/16"
    title: "PR #16"
---

# Close the GitHub issues that the wiki now tracks

## Problem

The state of the GitHub issues differs from the wiki. The wiki is the tracker of record, but seven GitHub issues and one PR are still open. Some of them describe work that is complete.

## Context

On 2026-10-28, `gh issue list` showed these open issues: #5, #6, #7, #22, #24, #30 and #37. Each has a wiki issue:

| GH | Wiki issue | Wiki state |
|---|---|---|
| #5 | [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md) | open |
| #6 | [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md) | open |
| #7 | [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md) | open |
| #22 | [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md) | open, partly done |
| #24 | [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md) | open |
| #30 | [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md) | resolved |
| #37 | [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md) | open |

* #30 is resolved in the repository by PR #31 (merged 2026-10-13). GitHub still shows it as open.
* #22 is partly done. dapr `v1.18.9` cleared the dapr findings, but `EXC-2026-0013` to `EXC-2026-0016` are still in `.github/pdp/exceptions.yaml`. The postgres and Ory waivers still match findings.
* PR #16, "waive the two unfixable libcurl Criticals in postgres", is still open. PR #21 added `EXC-2026-0008` for the same two findings and merged on 2026-09-30. Thus PR #21 replaced PR #16.
* `.github/pdp/exceptions.yaml` cites #5, #6, #7, #22 and #37 as the `ticket` of its waivers. The issue workflow keeps those tickets and closes the GitHub issue with a link to the wiki issue.

## Acceptance criteria

This work needs the approval of the maintainer. Do it after this wiki is on `main`, because the comments must give URLs on `main`.

- [ ] Each of #5, #6, #7, #22, #24, #30 and #37 has a comment with the GitHub URL of its wiki issue on `main`.
- [ ] Each of those GitHub issues is closed.
- [ ] PR #16 has a comment that names PR #21 and `EXC-2026-0008`, and PR #16 is closed.
- [ ] `gh issue list --state open` shows only issues that a bot opened after the merge.

## Analysis

A closed GitHub issue still works as the `ticket` of a waiver, because the comment points at the wiki issue. The drift bot reuses #24 for the next upstream drift report. After #24 is closed, the bot opens a new issue, and that issue needs its own wiki issue. See [Issue workflow](/guides/issue-workflow--01a1837da656.md).

## Related

* [ADR-007: The wiki is the tracker of record](/decisions/adr-007-the-wiki-is-the-tracker-of-record--01a18382f505.md)
* [Issue workflow](/guides/issue-workflow--01a1837da656.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
