---
id: "01a1838a-159a-7c84-8807-91d1fc6619dd"
title: "Nobody has measured whether Docker OIDC covers registry.scout.docker.com"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "prd"
  - "dhi"
  - "credentials"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "The DHI legs use a long-lived Docker organization token because no run has shown which Docker hosts accept an OIDC token."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.ai/PRD.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
    title: "SETUP-ENVIRONMENTS.md"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
    title: ".github/workflows/build.yml"
---

# Nobody has measured whether Docker OIDC covers registry.scout.docker.com

## Problem

Nobody has measured whether the Docker OIDC connection covers `registry.scout.docker.com`. The pipeline uses an organization access token for the Docker hosts instead. A token is long-lived and must be rotated. An OIDC token is short-lived and scoped to one repository and one environment.

## Context

* Before the wiki adoption, `.ai/PRD.md` listed this open item: "Whether Docker OIDC covers `registry.scout.docker.com`." `.ai/PRD.md` is now a pointer to the wiki, and the open items are in the [Issues overview](/issues/issues-overview--01a1837da5b0.md).
* `SETUP-ENVIRONMENTS.md` section 6 chose the token so that the pipeline could run. It says: answer the question from a real run, then narrow the scope of the token or retire it.
* `.github/workflows/build.yml` logs in to `dhi.io` and `registry.scout.docker.com` with `DOCKERHUB_OAT` on every leg with the trust class `dhi`.
* `scripts/mirror-leg.sh` fetches the DHI public key from `registry.scout.docker.com/keyring/dhi/latest.pub` over HTTPS.

## Acceptance criteria

- [ ] A recorded run shows which Docker hosts accept an OIDC token.
- [ ] If OIDC works for `dhi.io` and `docker.io`, those logins use OIDC, and the token covers only the hosts that need it.
- [ ] `SETUP-ENVIRONMENTS.md` section 6 and [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md) show the result.

## Analysis

`SETUP-ENVIRONMENTS.md` section 7 says that DHI keeps its attestations as referrers in the image repository on `dhi.io`. The comment in `.github/workflows/build.yml` says that the attestations are on `registry.scout.docker.com`. The old card `.ai/skills/dhi-authentication.md` said the same before the wiki adoption. If section 7 is correct, the pipeline may not need a login to `registry.scout.docker.com` at all. A run without that login can show this.

## Related

* [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md)
* [The four DHI digests and attestationRepo were placeholders](/issues/the-four-dhi-digests-and-attestationrepo-were-placeholders--01a1838a1552.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [The docs disagree on Docker Hub authentication and on where DHI keeps its attestations](/issues/the-docs-disagree-on-docker-hub-authentication-and-on-where-dhi-keeps-its-attestations--01a18395b5db.md)
