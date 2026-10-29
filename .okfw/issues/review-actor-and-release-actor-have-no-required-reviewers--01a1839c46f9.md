---
id: "01a1839c-46f9-730a-b80f-48321efb6e6e"
title: "Review-Actor and Release-Actor have no required reviewers"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "signing"
  - "environments"
  - "security"
created: "2026-10-28T12:43:39-05:00"
timestamp: "2026-10-28T12:48:18-05:00"
description: "The Review-Actor and Release-Actor environments have no required reviewers, so a Review signature does not prove a human approval."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:48:18-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
sources:
  - resource: "https://api.github.com/repos/infrashift/trusted-service-containers/environments"
    title: "GitHub environments API, read on 2026-10-28"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/CODEOWNERS"
    title: "CODEOWNERS"
---

# Review-Actor and Release-Actor have no required reviewers

## Problem

The `Review-Actor` and `Release-Actor` environments have no required reviewers. The design says that a `Review-Actor` signature proves that a human approved the verdict. The live settings do not support that claim.

## Context

On 2026-10-28, `gh api repos/infrashift/trusted-service-containers/environments/<name>` gave these settings:

| Environment | Protection rules | Deployment branch policy |
|---|---|---|
| `Build-Actor` | None | None. A job from any branch can use the build key. |
| `Review-Actor` | None | None |
| `Release-Actor` | One `branch_policy` rule. No required reviewers. | Custom policies: `main` only |

All three environments had `can_admins_bypass: true`.

The repository documents a different state:

* Core principle 6 of `.ai/PRD.md` (now in [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md)) says that `Review-Actor` has Required Reviewers. Thus "a Review signature *is* proof a human approved".
* The comment at the top of `.github/CODEOWNERS` says that dual control comes from Required Reviewers on `Review-Actor` and `Release-Actor`, not from CODEOWNERS.
* `SETUP-ENVIRONMENTS.md` §4 ("Protection rules") tells the operator to give `Review-Actor` Required Reviewers with `prevent_self_review=true`. It calls this "the *entire* human gate". It also restricts `Release-Actor` to `main` with a custom deployment branch policy.
* §4 gives no required reviewers for `Release-Actor`. Only the CODEOWNERS comment asks for them.
* §4 gives no protection rule and no branch policy for `Build-Actor`.
* §3 makes three keypairs in `/dev/shm`, and §5 destroys the private halves after the upload. These steps do not change the protection rules.
* The checklist of `SETUP-ENVIRONMENTS.md` has the items "`Review-Actor` has Required Reviewers with `prevent_self_review`" and "`Release-Actor` restricted to `main`". The first item is not true today. The second item is true.
* `.github/CODEOWNERS` and `SETUP-ENVIRONMENTS.md` do not mention a single-maintainer constraint.

The workflows bind the environments as follows. `.github/workflows/build.yml` runs on `pull_request` and uses `Build-Actor`. `.github/workflows/review.yml` runs on `workflow_run` and uses `Review-Actor`. `.github/workflows/release.yml` runs on a push to `main` and uses `Release-Actor`.

## Acceptance criteria

- [ ] `Review-Actor` has required reviewers, and `prevent_self_review` is `true`, as `SETUP-ENVIRONMENTS.md` §4 specifies.
- [ ] `Release-Actor` has required reviewers, if the maintainer decides that the CODEOWNERS comment is the intended design.
- [ ] The branch policies agree with `SETUP-ENVIRONMENTS.md` §4.
- [ ] Or: `SETUP-ENVIRONMENTS.md`, `.github/CODEOWNERS` and the wiki concepts below record the accepted risk, and stop the claim that a `Review-Actor` signature proves a human approval.
- [ ] A `gh api .../environments/<name>` result with the date is in a finding or in the resolution of this issue.

## Analysis

* Without required reviewers, `review.yml` signs a verdict with the review key and no human step. The `Review-Actor` signature then proves only that the workflow ran.
* With `can_admins_bypass: true`, an administrator can skip a required reviewer. Thus a required reviewer alone does not give dual control against an administrator.
* `build.yml` runs on `pull_request`. A branch policy on `Build-Actor` must still let the PR builds run.
* If one person is both the PR author and the only reviewer, `prevent_self_review` can stop that person from approving. The repository docs do not say how many maintainers there are.
* This issue and [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md) have the same effect: a merge or a signed verdict needs no human approval.

## Related

* [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md)
* [The three actors](/architecture/the-three-actors--01a18382f33a.md)
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md)
* [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md)
* [Set up a new repository from scratch](/operations/set-up-a-new-repository-from-scratch--01a18383db12.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
