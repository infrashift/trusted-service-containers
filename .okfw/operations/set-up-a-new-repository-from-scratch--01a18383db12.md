---
id: "01a18383-db12-7ac0-960a-1774124846fb"
title: "Set up a new repository from scratch"
type: "runbook"
tags:
  - "runbook"
  - "setup"
  - "environments"
created: "2026-10-28T12:16:59-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "A pointer to SETUP-ENVIRONMENTS.md: its twelve sections, from the preconditions to the first run, with the purpose of each section."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/CODEOWNERS"
    title: "CODEOWNERS"
---

# Set up a new repository from scratch

This runbook is a pointer. `SETUP-ENVIRONMENTS.md` is the source of truth for the setup of a new repository. A human does it one time, before the pipeline can run. Do the sections in sequence, because later sections need earlier ones.

WARNING: Do not copy the commands from this concept. Read them in `SETUP-ENVIRONMENTS.md`. That file changes when the procedure changes.

## Sections

| Section | Purpose |
|---|---|
| Start | Export `ORG`, `REPO` and `SLUG`. |
| §0 Preconditions | Check `gh` scopes and the tool versions. Keep `cosign` at v2, the same as the sibling repository. |
| §1 Run the blocking spike first | Prove that GHCR keeps the attestations through a `regctl image copy`, and get the first CVE counts for nexus3. |
| §2 Create the repository | Create the GitHub repository and push. |
| §3 Generate three cosign keypairs | Make the build, review and release keys in `/dev/shm`. Prove that each public half matches its private half. |
| §4 Three environments, each with two secrets | Create `Build-Actor`, `Review-Actor` and `Release-Actor`. Store `COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD` in each. Set the protection rules. |
| §5 Publish public keys, destroy private ones | Commit the `.pub` files to `.github/pdp/public-keys/`. Destroy the private keys with `shred`. Scan for leaks. |
| §6 Docker Hub authentication | Store the read-only Organization Access Token `DOCKERHUB_OAT` on `Build-Actor`, and set `DOCKERHUB_ORGANIZATION`. |
| §7 Resolve the four DHI digests | Replace the zero placeholders with index digests, and verify the DHI signatures by hand. |
| §8 Verify the base-image assumptions | Make sure that the pinned `ubi9-micro` still lacks the CA bundle, tzdata and UID 1001. |
| §9 Teams and CODEOWNERS | Make sure that the three teams exist and have repository access. |
| §10 Branch ruleset on `main` | Require a pull request, Code Owner review, signed commits, and the three required checks, with an empty bypass list. |
| §11 First run | Run `validate` and `verify-pins`, then open a test pull request. |
| Checklist | Confirm each item before the pipeline goes live. |

## Facts to keep in mind

* By design, the review signature is the human approval. §4 gives `Review-Actor` Required Reviewers with `prevent_self_review`. Without `prevent_self_review`, the author of a pull request can approve the deployment, and the gate does nothing.
* All three environments use the secret name `COSIGN_PRIVATE_KEY`. Do not create a repository-level copy.
* Keep "Allow GitHub Actions to create and approve pull requests" disabled.

## Analysis

* §4 gives `Review-Actor` Required Reviewers. On 2026-10-28, `Review-Actor` and `Release-Actor` had no required reviewers. See [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md).
* §10 lists three required checks. On 2026-10-28 the live ruleset required only `Repo Gate`.
* The checklist still says "`attestationRepo` discovered and committed". §7 says that the field no longer exists.
* §11 says that `.github/pdp/exceptions.yaml` ships empty. That was true at the start. It now holds waivers.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md)
* [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md)
* [PR Review Gate workflow](/supply-chain/pr-review-gate-workflow--01a18383d6d2.md)
* [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md)
* [SETUP-ENVIRONMENTS.md and exceptions.yaml have stale setup text](/issues/setup-environments-md-and-exceptions-yaml-have-stale-setup-text--01a18395b5a2.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
