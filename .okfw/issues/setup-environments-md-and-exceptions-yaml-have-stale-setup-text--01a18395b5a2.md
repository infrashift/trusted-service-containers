---
id: "01a18395-b5a2-7a58-9f85-d6038b74b4c4"
title: "SETUP-ENVIRONMENTS.md and exceptions.yaml have stale setup text"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "docs"
  - "setup"
  - "waiver"
created: "2026-10-28T12:36:29-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "The setup checklist asks for attestationRepo, §11 says exceptions.yaml is empty, and exceptions.yaml keeps a delete-me example block."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/exceptions.yaml"
    title: ".github/pdp/exceptions.yaml"
---

# SETUP-ENVIRONMENTS.md and exceptions.yaml have stale setup text

## Problem

`SETUP-ENVIRONMENTS.md` has stale text in its checklist and in §11. `.github/pdp/exceptions.yaml` still has a commented example that says "Delete before the first real entry", after 29 real entries.

## Context

On 2026-10-28:

* The checklist has the box "Four DHI digests resolved; `attestationRepo` discovered and committed". Commit `fa26b25` (2026-08-24) removed `attestationRepo` from `versions.json` and from the schema. §7 of the same file explains why.
* The checklist has the box "Referrers spike passed; `tools.lock` cosign pin confirmed". No file records the result of the spike. See [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md).
* The checklist has the box "`main` ruleset active, empty bypass list, three required contexts". The live ruleset requires one context. See [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md).
* The checklist has the box "`Review-Actor` has Required Reviewers with `prevent_self_review`". The live `Review-Actor` environment has no required reviewers. See [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md).
* §11 says that `.github/pdp/exceptions.yaml` "ships empty on purpose". The file holds `EXC-2026-0001` to `EXC-2026-0029`.
* The end of `.github/pdp/exceptions.yaml` has a commented block that starts "Example. Delete before the first real entry." The example uses the id `EXC-2026-0001`, which is also the id of a real waiver.

## Acceptance criteria

- [ ] The checklist does not ask for `attestationRepo`.
- [ ] The referrers box links to a recorded result, or stays open with a link to the open issue.
- [ ] §11 does not say that `.github/pdp/exceptions.yaml` is empty.
- [ ] The example block in `.github/pdp/exceptions.yaml` is removed, or it uses an id that no real waiver can have.

## Analysis

`SETUP-ENVIRONMENTS.md` is not a build path. A change to `.github/pdp/` rebuilds all images, so do the `exceptions.yaml` part with the next change to `.github/pdp/`. [Set up a new repository from scratch](/operations/set-up-a-new-repository-from-scratch--01a18383db12.md) already records the §10 and §11 differences.

## Related

* [Set up a new repository from scratch](/operations/set-up-a-new-repository-from-scratch--01a18383db12.md)
* [The four DHI digests and attestationRepo were placeholders](/issues/the-four-dhi-digests-and-attestationrepo-were-placeholders--01a1838a1552.md)
* [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
