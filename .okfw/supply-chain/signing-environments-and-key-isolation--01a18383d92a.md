---
id: "01a18383-d92a-73a5-96c2-90ade034c5f6"
title: "Signing environments and key isolation"
type: "component"
tags:
  - "supply-chain"
  - "signing"
  - "environments"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "How three GitHub environments isolate three cosign keys under one secret name, with the designed and the live protection rules."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
    title: "scripts/lint-workflows.sh (check 7)"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/review.yml"
    title: "review.yml"
---

# Signing environments and key isolation

Three GitHub environments hold three different cosign keys under the same secret name, `COSIGN_PRIVATE_KEY`. The `environment:` binding of a job alone decides which key the job gets.

## The three environments

| Environment | Key | Jobs |
|---|---|---|
| `Build-Actor` | build | The two leg jobs of `build.yml`, and `detect` of `drift-upstream.yml` |
| `Review-Actor` | review | `Review <leg>` of `review.yml` |
| `Release-Actor` | release | `Release <leg>` and `Manifest <service>` of `release.yml` |

Every script uses `env://COSIGN_PRIVATE_KEY` and does not know which actor it is. An edit to a script cannot point it at the wrong key. Only an edit to the environment binding of a workflow can, and CODEOWNERS protect the workflows. Check 7 of `scripts/lint-workflows.sh` fails if a job uses `COSIGN_PRIVATE_KEY` without an environment.

## Protection: design and live state

The design and the live settings do not agree. The table gives both.

| Environment | Design (`SETUP-ENVIRONMENTS.md` §4, CODEOWNERS) | Live state on 2026-10-28 |
|---|---|---|
| `Build-Actor` | None. It runs on every pull request. | No protection rules. |
| `Review-Actor` | Required Reviewers, with `prevent_self_review` | No protection rules: no required reviewers and no branch policy. |
| `Release-Actor` | Only `main` can deploy (`SETUP-ENVIRONMENTS.md` §4). The CODEOWNERS comment and the former key-isolation rule card also give it Required Reviewers. | A custom deployment branch policy for `main` only. No required reviewers. |

A read-only `gh api repos/infrashift/trusted-service-containers/environments/<name>` call on 2026-10-28 showed the live state. See [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md).

## Two secrets in each environment

Each environment has `COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD`. A generated key is an encrypted PEM, and cosign cannot decrypt it without the password. The reference runbook stores only the key, which cannot work.

`Build-Actor` also holds `DOCKERHUB_OAT`, the Docker Hub token. A repository secret would give that token to the review and release actors too. See [Authenticate to DHI and the registries](/operations/authenticate-to-dhi-and-the-registries--01a18383d9e3.md).

## The review signature is the human approval (design)

By design, the review key is not available until a named human approves the deployment. Then a `Review-Actor` signature proves that the approval occurred. There is no separate human signing key, by design. The reference scheme needed a person to run `cosign sign-blob` by hand for every image. Thus nobody made its `human.pub`, and two of its scripts never worked.

On 2026-10-28, `Review-Actor` had no required reviewers. Thus a `Review-Actor` signature did not prove a human approval on that date.

## Keys are ECDSA P-256

`cosign generate-key-pair` makes ECDSA P-256 keys, not ED25519. It has no key-type flag. Do not repeat the incorrect claim of the reference repository.

## Never commit private key material

* `.gitignore` covers `*.key` and `*.pem`.
* `.gitleaks.toml` has rules for PEM and Sigstore private key blocks.
* Generate keys in `/dev/shm`, and destroy them with `shred` after the upload. See `SETUP-ENVIRONMENTS.md` §3 and §5.
* Commit only the public halves, to `.github/pdp/public-keys/`.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Workflow conventions](/supply-chain/workflow-conventions--01a18383d8e0.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md)
* [Set up a new repository from scratch](/operations/set-up-a-new-repository-from-scratch--01a18383db12.md)
* [Review-Actor and Release-Actor have no required reviewers](/issues/review-actor-and-release-actor-have-no-required-reviewers--01a1839c46f9.md)
