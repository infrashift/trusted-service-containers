---
id: "01a18395-b5db-78d6-a8c5-478c0cb9c8ee"
title: "The docs disagree on Docker Hub authentication and on where DHI keeps its attestations"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "docs"
  - "dhi"
  - "credentials"
  - "postgres"
  - "traefik"
created: "2026-10-28T12:36:29-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "The code logs in with DOCKERHUB_OAT, but some text still says OIDC, and two files disagree on where the DHI attestations are."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/drift-upstream.yml"
    title: ".github/workflows/drift-upstream.yml"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-upstream.sh"
    title: "scripts/drift-upstream.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
    title: "scripts/mirror-leg.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
    title: "SETUP-ENVIRONMENTS.md"
---

# The docs disagree on Docker Hub authentication and on where DHI keeps its attestations

## Problem

The repository files disagree on two facts. The first fact is how the workflows log in to Docker Hub and DHI. The second fact is where DHI keeps its attestations. The code uses an organization access token. Some text still describes OIDC.

## Context

The code, on 2026-10-28:

* `.github/workflows/build.yml` logs in to `dhi.io`, `registry.scout.docker.com` and `docker.io` with `DOCKERHUB_ORGANIZATION` and the secret `DOCKERHUB_OAT`.
* `.github/workflows/drift-upstream.yml` logs in to `dhi.io` and `docker.io` with the same token.
* No workflow reads `DOCKERHUB_OIDC_CONNECTIONID`.

The text that disagrees with the code:

* The old card `.ai/skills/dhi-authentication.md` (before the wiki adoption, `git show HEAD:.ai/skills/dhi-authentication.md`) has the section "OIDC, not a stored token". Its example uses `DOCKERHUB_OIDC_CONNECTIONID` and no password. The wiki adoption replaced the card with a pointer stub to the runbook below.
* When `scripts/drift-upstream.sh` cannot list the tags of a DHI image, its alarm says "check the OIDC login". The login uses the token.
* A comment in `.github/workflows/build.yml` says that DHI keeps its signed attestations on `registry.scout.docker.com`. `SETUP-ENVIRONMENTS.md` §6 says the same.
* `SETUP-ENVIRONMENTS.md` §7 says that DHI publishes the attestations as OCI referrers in the repository of the image, for example `dhi.io/traefik`. `scripts/mirror-leg.sh` reads them there.

[Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md) gives the token login that the code uses.

## Acceptance criteria

- [ ] The alarm text in `scripts/drift-upstream.sh` tells the operator to check `DOCKERHUB_OAT` and `DOCKERHUB_ORGANIZATION`.
- [ ] The comment in `.github/workflows/build.yml` and `SETUP-ENVIRONMENTS.md` §6 agree with §7 about where the attestations are.
- [ ] No file in the repository describes OIDC as the current Docker login.

## Analysis

* `scripts/mirror-leg.sh` fetches the DHI keyring from `registry.scout.docker.com` with `curl`. `curl` does not read the Docker credentials that `docker/login-action` writes. Thus the keyring fetch does not use the Scout login.
* If §7 is correct, no step uses the login to `registry.scout.docker.com`. A run without that login can show this. See [Nobody has measured whether Docker OIDC covers registry.scout.docker.com](/issues/nobody-has-measured-whether-docker-oidc-covers-registry-scout-docker-com--01a1838a159a.md).
* A change to `scripts/` rebuilds all images. Do the alarm text fix with another `scripts/` change.

## Related

* [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md)
* [Nobody has measured whether Docker OIDC covers registry.scout.docker.com](/issues/nobody-has-measured-whether-docker-oidc-covers-registry-scout-docker-com--01a1838a159a.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
