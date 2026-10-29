---
id: "01a1837d-a594-7769-9c60-3e7c2a93f718"
title: "Operations overview"
type: "overview"
tags:
  - "hub"
  - "operations"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "Runbooks: add an upstream, bump a source, re-pin a toolchain or base, waive a CVE, move to enforce, read the review, and run the checks."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Operations overview

This bundle holds the runbooks: numbered procedures for the work that operators do on this repository.

Do not put a description of a part of the system here. Put it in `supply-chain/` or `architecture/`. Do not put a problem here. Record it in `issues/`.

## Find concepts

* List this bundle: read `.okfw/operations/index.md`.
* Search the runbooks: `okfw search "<words>" --type runbook`.

## Add a concept

1. Search the wiki first. Update a runbook that exists, if possible.
2. Run `okfw create "<Title>" --type runbook --path operations -d "<one sentence>" --tags runbook,<topic>`.
3. Add a link to the new runbook in the list below.
4. Write numbered imperative steps. Put each warning before its step. Obey [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Concepts

### Every change

* [Run the checks locally](/operations/run-the-checks-locally--01a18383da08.md): `validate`, the repo gate and the policy tests.
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md): a green check is not a pass.

### Images

* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md): seven steps. Step 6 scans the local build.
* [Move an image from observe to enforce](/operations/move-an-image-from-observe-to-enforce--01a18383dac5.md): after a review with zero blocking findings.
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md): only after no in-track release clears the finding.

### Pins

* [Bump an upstream source within its track](/operations/bump-an-upstream-source-within-its-track--01a18383da54.md): from a drift proposal.
* [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md): a `stdlib` finding is a compiler finding.
* [Re-pin a base image](/operations/re-pin-a-base-image--01a18383da79.md): rebuilds every build-track image.

### Registries and setup

* [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md): which login uses which credential.
* [Clean the development namespace](/operations/clean-the-development-namespace--01a18383db39.md): never `trusted/` or `quarantine/`.
* [Set up a new repository from scratch](/operations/set-up-a-new-repository-from-scratch--01a18383db12.md): a pointer to `SETUP-ENVIRONMENTS.md`.

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md): the parts that these runbooks use.
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md)
