---
id: "01a18396-ce3c-7481-93f8-017444dbfe60"
title: "Roadmap"
type: "plan"
tags:
  - "plan"
  - "roadmap"
created: "2026-10-28T12:37:40-05:00"
timestamp: "2026-10-28T12:37:41-05:00"
description: "The open issues and waiver expiry dates in time order, from the 2026-11-22 waiver decisions to the 2027-10-31 mssql identity check."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:37:41-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
stale_after: "2026-11-22T00:00:00Z"
---

# Roadmap

## Goal

This plan puts the open issues and the waiver expiry dates of this repository in time order, so that each decision occurs before its date.

## How to use this plan

* Each line links the issue or finding that holds the facts. This plan holds no facts of its own.
* The expiry dates come from `.github/pdp/exceptions.yaml`. On an expiry date, the PDP stops the waiver, and the image leg can fail its review.
* A change to `scripts/`, `.github/pdp/`, `tools.lock` or `rootfs/` rebuilds all images. Thus collect such fixes into one change. See [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md).
* When you close an issue, remove its line here or mark it done.

## Before 2026-11-22

The waivers `EXC-2026-0001` to `EXC-2026-0007` expire. For each group, decide to renew the waiver after a new scan, or to remove it.

1. nexus3, `EXC-2026-0001`: [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md). Facts: [Waiver EXC-2026-0001 accepts the nexus3 Java library findings until 2026-11-22](/findings/waiver-exc-2026-0001-accepts-the-nexus3-java-library-findings-until-2026-11-22--01a1838a690c.md).
2. DHI postgres and traefik, `EXC-2026-0002` and `EXC-2026-0003`: [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md). Facts: [Waivers EXC-2026-0002 and 0003 accept DHI Debian base findings until 2026-11-22](/findings/waivers-exc-2026-0002-and-0003-accept-dhi-debian-base-findings-until-2026-11-22--01a1838a6981.md). `EXC-2026-0003` matched no finding on 2026-10-28: [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md).
3. Ory, `EXC-2026-0004` to `EXC-2026-0007`: [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md). Facts: [Waivers EXC-2026-0004 to 0007 accept Ory vendored Go findings until 2026-11-22](/findings/waivers-exc-2026-0004-to-0007-accept-ory-vendored-go-findings-until-2026-11-22--01a1838a6a0e.md).

## Before 2026-11-27

The go-jose waivers and the October `x/net` and `x/text` waivers expire.

1. go-jose `GHSA-mgcc-cww5-fp2q`, `EXC-2026-0017` to `EXC-2026-0019`, `EXC-2026-0026`, `EXC-2026-0028` and `EXC-2026-0029`: [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md). Facts: [Six waivers accept go-jose GHSA-mgcc-cww5-fp2q until 2026-11-27](/findings/six-waivers-accept-go-jose-ghsa-mgcc-cww5-fp2q-until-2026-11-27--01a1838a6c08.md).
2. October `x/net` and `x/text` in the Ory images, `EXC-2026-0020` to `EXC-2026-0025` and `EXC-2026-0027`: [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md). Facts: [Seven waivers accept the October x/net and x/text findings in Ory until 2026-11-27](/findings/seven-waivers-accept-the-october-x-net-and-x-text-findings-in-ory-until-2026-11-27--01a1838a6c7a.md).

## Before 2026-12-29

The waivers `EXC-2026-0008` to `EXC-2026-0016` expire.

1. libcurl in postgres, grpc in Ory and dapr, amqp091-go in `daprd`: [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md). Facts: [Waiver EXC-2026-0008 accepts two libcurl Criticals in postgres until 2026-12-29](/findings/waiver-exc-2026-0008-accepts-two-libcurl-criticals-in-postgres-until-2026-12-29--01a1838a6a7d.md), [Waivers EXC-2026-0009 to 0015 accept grpc findings in Ory and dapr until 2026-12-29](/findings/waivers-exc-2026-0009-to-0015-accept-grpc-findings-in-ory-and-dapr-until-2026-12-29--01a1838a6af1.md) and [Waiver EXC-2026-0016 accepts amqp091-go findings in daprd until 2026-12-29](/findings/waiver-exc-2026-0016-accepts-amqp091-go-findings-in-daprd-until-2026-12-29--01a1838a6b8d.md).
2. `EXC-2026-0013` to `EXC-2026-0016` matched no finding after dapr `v1.18.9`: [dapr v1.18.9 cleared the grpc, x/net and amqp091-go findings on 2026-10-28](/findings/dapr-v1-18-9-cleared-the-grpc-x-net-and-amqp091-go-findings-on-2026-10-28--01a1838a6f77.md). Remove them with the next change to `.github/pdp/`.

## Next scripts/ change

Each fix below rebuilds all images. Do them together.

1. [lint-skills.sh does not check the paths in the wiki](/issues/lint-skills-sh-does-not-check-the-paths-in-the-wiki--01a1838a16b2.md)
2. [CI does not validate the wiki](/issues/ci-does-not-validate-the-wiki--01a1838a16fa.md). This also changes `tools.lock`.
3. [Check 3 of lint-workflows.sh has a dead empty-hash test](/issues/check-3-of-lint-workflows-sh-has-a-dead-empty-hash-test--01a18395b612.md)
4. The alarm text in `scripts/drift-upstream.sh`: [The docs disagree on Docker Hub authentication and on where DHI keeps its attestations](/issues/the-docs-disagree-on-docker-hub-authentication-and-on-where-dhi-keeps-its-attestations--01a18395b5db.md).
5. The fix in `scripts/lint-skills.sh`, if the upstream template does not change: [Re-running okfw install restores a path example that lint-skills.sh rejects](/issues/re-running-okfw-install-restores-a-path-example-that-lint-skills-sh-rejects--01a18395b684.md).

## Next .github/pdp/ change

Each fix below rebuilds all images. Do them together, and with the waiver decisions above if possible.

1. [Two code comments point at moved skill cards](/issues/two-code-comments-point-at-moved-skill-cards--01a1838a173b.md)
2. [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md)
3. The example block at the end of `.github/pdp/exceptions.yaml`: [SETUP-ENVIRONMENTS.md and exceptions.yaml have stale setup text](/issues/setup-environments-md-and-exceptions-yaml-have-stale-setup-text--01a18395b5a2.md).

## Docs debt

These issues change text only. Some of them touch a build path. The note says which.

1. [README.md describes an older image set and an old test count](/issues/readme-md-describes-an-older-image-set-and-an-old-test-count--01a18395b534.md). No image build.
2. [SETUP-ENVIRONMENTS.md and exceptions.yaml have stale setup text](/issues/setup-environments-md-and-exceptions-yaml-have-stale-setup-text--01a18395b5a2.md). No image build for `SETUP-ENVIRONMENTS.md`.
3. [The docs disagree on Docker Hub authentication and on where DHI keeps its attestations](/issues/the-docs-disagree-on-docker-hub-authentication-and-on-where-dhi-keeps-its-attestations--01a18395b5db.md). The `build.yml` comment starts a full build.
4. [The notes in versions.json are stale](/issues/the-notes-in-versions-json-are-stale--01a18395b56b.md). Do it with the next bump of loki, prometheus and seaweedfs.
5. [Eight build Containerfiles say that fetch-source.sh removes .git](/issues/eight-build-containerfiles-say-that-fetch-source-sh-removes-git--01a18395b4ba.md). Do it with the next change to those Containerfiles.
6. [The nats config cites a runtime document that does not exist](/issues/the-nats-config-cites-a-runtime-document-that-does-not-exist--01a18395b4f1.md). Do it with the next change to nats.

## Pipeline settings and local checks

These issues start no image build.

1. [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md). A ruleset change on GitHub needs the maintainer.
2. [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md). An environment change on GitHub needs the maintainer.
3. [The drift workflow validates its proposal with asserted gitleaks values](/issues/the-drift-workflow-validates-its-proposal-with-asserted-gitleaks-values--01a18395b484.md)
4. [Ops.mk skips the shell lint without shellcheck and has a wrong help line](/issues/ops-mk-skips-the-shell-lint-without-shellcheck-and-has-a-wrong-help-line--01a18395b64c.md)

## No fixed date

1. [The mssql image has 60 blocking findings and no triage](/issues/the-mssql-image-has-60-blocking-findings-and-no-triage--01a1838a1626.md)
2. [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md) (GH #24)
3. [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md)
4. [Nobody has measured whether Docker OIDC covers registry.scout.docker.com](/issues/nobody-has-measured-whether-docker-oidc-covers-registry-scout-docker-com--01a1838a159a.md)
5. [No check enforces Simplified Technical English](/issues/no-check-enforces-simplified-technical-english--01a1838a1782.md)

## Before 2027-10-31

1. [The pinned mssql signing identity expires on 2027-10-31](/issues/the-pinned-mssql-signing-identity-expires-on-2027-10-31--01a1838a166f.md). Check the live mssql signature before the certificate expires.

## Verification

* `okfw search --kind issue --tag open` returns no open issue that this plan does not list.
* No waiver in `.github/pdp/exceptions.yaml` expires on a date that this plan does not list.

## Related

* [Plans overview](/plans/plans-overview--01a1837da5cd.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
* [Plan workflow](/guides/plan-workflow--01a1837da67e.md)
