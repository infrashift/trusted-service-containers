---
id: "01a18383-d9e3-7b1a-8e9f-e5de76edce52"
title: "Authenticate to DHI and the registries"
type: "runbook"
tags:
  - "runbook"
  - "registry"
  - "dhi"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "Which registries the workflows log in to, which credential each login uses, and why the base image and mssql need no login."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
    title: "SETUP-ENVIRONMENTS.md §6 and §7"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/drift-upstream.yml"
    title: "drift-upstream.yml"
---

# Authenticate to DHI and the registries

This runbook tells you which registries the workflows log in to, and with which credential. All logins use `docker/login-action`. It writes `~/.docker/config.json`, which `regctl`, `cosign`, `syft` and `grype` all read.

## Registries and credentials

| Registry | Why | Credential | Which legs |
|---|---|---|---|
| `dhi.io` | DHI image layers | `DOCKERHUB_ORGANIZATION` and `DOCKERHUB_OAT` | `dhi` legs only |
| `registry.scout.docker.com` | DHI attestations and the DHI keyring (see Analysis) | `DOCKERHUB_ORGANIZATION` and `DOCKERHUB_OAT` | `dhi` legs only |
| `docker.io` | `sonatype/nexus3` and the build-track cross-check references | `DOCKERHUB_ORGANIZATION` and `DOCKERHUB_OAT` | All legs, when the token exists |
| `ghcr.io` | Our own push target | `GITHUB_TOKEN` | All legs |

`drift-upstream.yml` logs in to `dhi.io` and `docker.io` with the same token. Without them it cannot list the DHI tags, and it reports them under "Needs attention".

## The token

`SETUP-ENVIRONMENTS.md` §6 gives the full procedure. The main points:

1. Use an Organization Access Token, not a personal token. Grant it read-only access.
2. Store it as `DOCKERHUB_OAT`, an environment secret on `Build-Actor`. Do not store it as a repository secret. A repository secret would give it to the review and release actors.
3. Set the repository variable `DOCKERHUB_ORGANIZATION` to the Docker Hub organization `infrashiftio`.

WARNING: The Docker Hub organization is `infrashiftio`, not `infrashift`. With the wrong name, Docker answers `unauthorized: incorrect username or password`. That looks like a bad token.

## OIDC is the target state

The first design used Docker OIDC with `DOCKERHUB_OIDC_CONNECTIONID` and no password. Nobody set that variable, so the first build failed at the first login. The token replaced OIDC. OIDC is still the better end state: a short-lived token, scoped to one repository and environment, with nothing to rotate.

An OIDC login needs `id-token: write` on the job, not on the workflow, and `docker/login-action` v4.5.0 or later. Scope the Docker-side ruleset to pull only.

The open question is whether OIDC covers `registry.scout.docker.com`. Docker's own mirror documentation uses an Organization Access Token for all three hosts. Answer the question from the logs of a real run. If OIDC works for `dhi.io` and `docker.io`, move those two back to OIDC.

## Authenticate for docker.io although nexus3 is public

Docker Hub limits anonymous pulls for each IP address, and GitHub runners share IP addresses. An anonymous mirror fails at random, and the failure looks like a network problem. If no token exists, the workflow skips the `docker.io` login and pulls anonymously with the rate limit.

## Registries that need no login

* `mcr.microsoft.com` (mssql) allows anonymous pulls, and no rate limit has occurred. Add a login only if MCR refuses anonymous pulls.
* The base image `ghcr.io/infrashift/trusted-base-images/trusted/ubi9-micro` is readable without a credential. If that changes, give access in the package settings of the sibling ("Manage Actions access"). Do not use a personal access token.

## A DHI leg without a token

A `dhi` leg stops at once with an error if `DOCKERHUB_OAT` does not exist. The error tells you to set it on `Build-Actor`.

## Analysis

* The comment in `build.yml` says that DHI keeps its signed attestations on `registry.scout.docker.com`. `SETUP-ENVIRONMENTS.md` §7 says that DHI publishes the attestations as OCI referrers in the repository of the image, for example `dhi.io/traefik`. The DHI public keyring is at `registry.scout.docker.com/keyring/dhi/latest.pub`. Thus the Scout login is possibly necessary only for the keyring, or not at all.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md)
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [Set up a new repository from scratch](/operations/set-up-a-new-repository-from-scratch--01a18383db12.md)
* [The docs disagree on Docker Hub authentication and on where DHI keeps its attestations](/issues/the-docs-disagree-on-docker-hub-authentication-and-on-where-dhi-keeps-its-attestations--01a18395b5db.md)
