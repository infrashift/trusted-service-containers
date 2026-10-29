---
id: "01a1837d-a5b0-7e5c-8236-c9a94967bb34"
title: "Issues overview"
type: "overview"
tags:
  - "hub"
  - "issues"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "All problems and tasks for this project, open and resolved. The wiki is the tracker of record."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Issues overview

This bundle holds one issue concept for each problem or task, with the tag `open` or `resolved`. The wiki is the tracker of record. Each GitHub issue has a wiki issue with its number in `x.github`.

Do not put multi-step work here. Put it in `plans/` and link the issues. Do not put a dated measurement here. Put it in `findings/`.

## Find concepts

* List this bundle: read `.okfw/issues/index.md`.
* Open issues: `okfw search --kind issue --tag open`.
* Issues for one image: `okfw search --kind issue --tag open --tag nexus3`.

## Add a concept

1. Search the wiki first. Update an issue that exists, if possible.
2. Run `okfw create "<Title>" --kind issue --type issue --path issues -d "<one sentence>" --tags issue,open`.
3. Add a link to the new issue in the list below.
4. Obey the [Issue workflow](/guides/issue-workflow--01a1837da656.md), the [wiki conventions](/guides/wiki-conventions--01a1837da62e.md) and [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Concepts

The [Roadmap](/plans/roadmap--01a18396ce3c.md) puts the open issues in time order. The note after each link gives the origin: a GitHub issue number, an open item of `.ai/PRD.md`, or a new issue from the wiki adoption. `.ai/PRD.md` is now a pointer to the wiki.

### Open: security posture

* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md) (new). A `Review-Actor` signature does not prove a human approval.
* [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md) (new). A red `review/cve-policy` does not stop a merge.

### Open: CVEs and waivers

* [No Ory release clears the Go dependency findings in the four Ory images](/issues/no-ory-release-clears-the-go-dependency-findings-in-the-four-ory-images--01a1838a1296.md) (GH #7). A decision is due before 2026-11-22.
* [The go-jose advisory GHSA-mgcc-cww5-fp2q blocks six images until upstream releases a fix](/issues/the-go-jose-advisory-ghsa-mgcc-cww5-fp2q-blocks-six-images-until-upstream-releases-a-fix--01a1838a14d3.md) (GH #37). The waivers expire on 2026-11-27.
* [The nexus3 mirror has blocking findings that only a Sonatype release can clear](/issues/the-nexus3-mirror-has-blocking-findings-that-only-a-sonatype-release-can-clear--01a18389b7fe.md) (GH #5)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md) (GH #6)
* [The 2026-09-30 drift left libcurl, grpc and amqp091-go findings that no bump clears](/issues/the-2026-09-30-drift-left-libcurl-grpc-and-amqp091-go-findings-that-no-bump-clears--01a1838a135e.md) (GH #22)
* [Five waivers match no finding after the October rebuilds](/issues/five-waivers-match-no-finding-after-the-october-rebuilds--01a1838a17b7.md) (new)
* [The mssql image has 60 blocking findings and no triage](/issues/the-mssql-image-has-60-blocking-findings-and-no-triage--01a1838a1626.md) (PRD)
* [The whoami mirror has 54 blocking findings and no triage](/issues/the-whoami-mirror-has-54-blocking-findings-and-no-triage--01a1839ccc1d.md) (new)

### Open: drift and pins

* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md) (GH #24)
* [The pinned mssql signing identity expires on 2027-10-31](/issues/the-pinned-mssql-signing-identity-expires-on-2027-10-31--01a1838a166f.md) (PRD)

### Open: pipeline

* [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md) (PRD)
* [Nobody has measured whether Docker OIDC covers registry.scout.docker.com](/issues/nobody-has-measured-whether-docker-oidc-covers-registry-scout-docker-com--01a1838a159a.md) (PRD)
* [The drift workflow validates its proposal with asserted gitleaks values](/issues/the-drift-workflow-validates-its-proposal-with-asserted-gitleaks-values--01a18395b484.md) (new)
* [Check 3 of lint-workflows.sh has a dead empty-hash test](/issues/check-3-of-lint-workflows-sh-has-a-dead-empty-hash-test--01a18395b612.md) (new)
* [Ops.mk skips the shell lint without shellcheck and has a wrong help line](/issues/ops-mk-skips-the-shell-lint-without-shellcheck-and-has-a-wrong-help-line--01a18395b64c.md) (new)
* [The release Gate job fails when GitHub has not yet linked the merge commit to its pull request](/issues/the-release-gate-job-fails-when-github-has-not-yet-linked-the-merge-commit-to-its-pull-request--01a1854e501e.md) (new). A short GitHub API delay after a merge can stop a release.

### Open: wiki

* [lint-skills.sh does not check the paths in the wiki](/issues/lint-skills-sh-does-not-check-the-paths-in-the-wiki--01a1838a16b2.md) (new)
* [CI does not validate the wiki](/issues/ci-does-not-validate-the-wiki--01a1838a16fa.md) (new)
* [Two code comments point at moved skill cards](/issues/two-code-comments-point-at-moved-skill-cards--01a1838a173b.md) (new)
* [No check enforces Simplified Technical English](/issues/no-check-enforces-simplified-technical-english--01a1838a1782.md) (new)
* [Re-running okfw install restores a path example that lint-skills.sh rejects](/issues/re-running-okfw-install-restores-a-path-example-that-lint-skills-sh-rejects--01a18395b684.md) (new)

### Open: documentation

* [README.md describes an older image set and an old test count](/issues/readme-md-describes-an-older-image-set-and-an-old-test-count--01a18395b534.md) (new)
* [SETUP-ENVIRONMENTS.md and exceptions.yaml have stale setup text](/issues/setup-environments-md-and-exceptions-yaml-have-stale-setup-text--01a18395b5a2.md) (new)
* [The docs disagree on Docker Hub authentication and on where DHI keeps its attestations](/issues/the-docs-disagree-on-docker-hub-authentication-and-on-where-dhi-keeps-its-attestations--01a18395b5db.md) (new)
* [The notes in versions.json are stale](/issues/the-notes-in-versions-json-are-stale--01a18395b56b.md) (new)
* [Eight build Containerfiles say that fetch-source.sh removes .git](/issues/eight-build-containerfiles-say-that-fetch-source-sh-removes-git--01a18395b4ba.md) (new)
* [The nats config cites a runtime document that does not exist](/issues/the-nats-config-cites-a-runtime-document-that-does-not-exist--01a18395b4f1.md) (new)

### Resolved

* [Close the GitHub issues that the wiki now tracks](/issues/close-the-github-issues-that-the-wiki-now-tracks--01a18395b6bd.md) (new). Done on 2026-10-29.
* [The go1.26 toolchain pin 1.26.6 put 8 stdlib findings into every Go build](/issues/the-go1-26-toolchain-pin-1-26-6-put-8-stdlib-findings-into-every-go-build--01a1838a13e9.md) (GH #30). The GitHub issue was closed on 2026-10-29.
* [The ubi9-minimal base pins were behind the sibling repository on 2026-10-28](/issues/the-ubi9-minimal-base-pins-were-behind-the-sibling-repository-on-2026-10-28--01a1838a1487.md) (GH #34)
* [The ubi9-micro base pins were behind the sibling repository on 2026-10-14](/issues/the-ubi9-micro-base-pins-were-behind-the-sibling-repository-on-2026-10-14--01a1838a1439.md) (GH #33)
* [The 2026-09-30 drift proposal had wrong crosscheck pins and stale hashes](/issues/the-2026-09-30-drift-proposal-had-wrong-crosscheck-pins-and-stale-hashes--01a1838a12ff.md) (GH #19)
* [The day-one CVE count of nexus3 was unknown](/issues/the-day-one-cve-count-of-nexus3-was-unknown--01a1838a15d7.md) (PRD)
* [The four DHI digests and attestationRepo were placeholders](/issues/the-four-dhi-digests-and-attestationrepo-were-placeholders--01a1838a1552.md) (PRD)

### Guide

* [Issue workflow](/guides/issue-workflow--01a1837da656.md)

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Findings overview](/findings/findings-overview--01a1837da578.md): the waivers and measurements that the issues cite.
* [Plans overview](/plans/plans-overview--01a1837da5cd.md)
* [Plan workflow](/guides/plan-workflow--01a1837da67e.md)
* [Roadmap](/plans/roadmap--01a18396ce3c.md)
