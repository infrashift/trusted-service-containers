---
id: "01a18382-f33a-79cf-aa8d-b7a9f6d6ac6f"
title: "The three actors"
type: "component"
tags:
  - "architecture"
  - "actors"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The Build, Review and Release actors: what each one does, which GitHub environment holds its key, and why a Review signature proves human approval."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/tree/main/.github/workflows"
    title: "The seven workflows"
---

# The three actors

Three actors move an image from a PR to a release. Each actor is a GitHub environment with its own cosign key. Each actor signs the result of its work.

## The actors

| Actor | Environment | What it does | Workflow |
|---|---|---|---|
| Build | `Build-Actor` | Mirrors or builds the image, scans it, and makes signed evidence. | `.github/workflows/build.yml` |
| Review | `Review-Actor` | Derives the facts again, independently. Evaluates the policy and signs a verdict. | `.github/workflows/review.yml` |
| Release | `Release-Actor` | Verifies the signed verdict, promotes the image, and signs it twice. | `.github/workflows/release.yml` |

## How a change moves

1. A PR runs `pr-gate.yml`. This is the repository gate for secrets, schema, policy tests and lints.
2. The PR runs `build.yml`. The mirror legs and the build legs make signed evidence.
3. When `build.yml` completes, `review.yml` runs. The review actor verifies again, evaluates the policy and signs a verdict.
4. After the merge, `release.yml` promotes each image to `trusted/` or `quarantine/` and signs it twice.
5. After the release, `cleanup-dev.yml` removes the `development/` images of the PR.

## Key isolation

The three environments hold three different cosign keys under the same secret name, `COSIGN_PRIVATE_KEY`. Each script refers to `env://COSIGN_PRIVATE_KEY` and does not know which key it has. Only the `environment:` binding of the job gives the isolation.

In the design, `Review-Actor` and `Release-Actor` have Required Reviewers. Then a Review signature is proof that a human approved the verdict. There is no separate human key. The design is in `.ai/PRD.md` (core principle 6) and in a comment in `.github/CODEOWNERS`.

On 2026-10-28, the live settings did not match this design. `Review-Actor` had no protection rules. `Release-Actor` had only a custom deployment branch policy. Neither environment had required reviewers. `Build-Actor` had no protection rules. Thus, on that date, a Review signature was not proof that a human approved. See [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md).

The public keys are in `.github/pdp/public-keys/`: `build.pub`, `review.pub` and `release.pub`.

## Related

* [The review actor re-derives the facts](/architecture/the-review-actor-re-derives-the-facts--01a18382f356.md)
* [Promotion](/architecture/promotion--01a18382f371.md)
* [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md): the workflows and the signing environments.
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
