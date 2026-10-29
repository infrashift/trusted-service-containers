---
id: "01a1837d-a55d-7180-9043-d2ff1112e2c6"
title: "Supply chain overview"
type: "overview"
tags:
  - "hub"
  - "supply-chain"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "The seven workflows, the PDP, waivers, the signing environments and the lint rules that make, check, sign and promote the images."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Supply chain overview

This bundle holds the parts of the pipeline that make, check, sign and promote the images. These are the workflows, the PDP, waivers, the signing environments and the lint rules.

Do not put a procedure here. Put it in `operations/`. Do not put a dated measurement or a waiver group here. Put it in `findings/`.

## Find concepts

* List this bundle: read `.okfw/supply-chain/index.md`.
* Search this bundle: `okfw search "<words>" --tag supply-chain`.
* Workflows only: `okfw search --tag workflow`.

## Add a concept

1. Search the wiki first. Update a concept that exists, if possible.
2. Run `okfw create "<Title>" --type component --path supply-chain -d "<one sentence>" --tags supply-chain,<topic>`.
3. Add a link to the new concept in the list below.
4. Obey the [wiki conventions](/guides/wiki-conventions--01a1837da62e.md) and [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Concepts

### Workflows

The workflows run in this sequence for one image pull request: gate, build, review, release, cleanup.

* [PR Review Gate workflow](/supply-chain/pr-review-gate-workflow--01a18383d6d2.md): static checks, the repo gate, and the seed of `review/cve-policy`.
* [CI Build & Audit workflow](/supply-chain/ci-build-audit-workflow--01a18383d6f4.md): mirror or build, scan and sign each leg as `Build-Actor`.
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md): verify again, evaluate the PDP and sign a verdict as `Review-Actor`.
* [Release Images workflow](/supply-chain/release-images-workflow--01a18383d737.md): promote byte-identical to `trusted/` or `quarantine/` as `Release-Actor`.
* [Cleanup Dev Images workflow](/supply-chain/cleanup-dev-images-workflow--01a18383d75b.md): delete the `development/` versions of one pull request.
* [Base Image Drift workflow](/supply-chain/base-image-drift-workflow--01a18383d780.md): propose new base pins each day.
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md): propose new releases, sources and toolchains inside each track.

### Cross-workflow rules

* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md): which legs a pull request rebuilds, and when all images rebuild.
* [Matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md): one guard, byte-identical in three workflows.
* [Build path filter sync](/supply-chain/build-path-filter-sync--01a18383d80b.md): `BUILD_PATHS` must cover the `paths:` filter of `build.yml`.
* [Workflow conventions](/supply-chain/workflow-conventions--01a18383d8e0.md): SHA pins, `tools.lock`, permissions, `env:`, required checks.
* [Workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md): the eleven checks of `scripts/lint-workflows.sh`.

### Policy

* [Policy decision point](/supply-chain/policy-decision-point--01a18383d82e.md): one Rego file, one package, two entrypoints.
* [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md): the five rules that make the PDP deny on missing input.
* [CVE gate](/supply-chain/cve-gate--01a18383d875.md): blocking, waived and recorded findings.
* [Waivers](/supply-chain/waivers--01a18383d898.md): the rules for an entry in `exceptions.yaml`.

### Build, signing and repository checks

* [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md): the shape of a build-track Containerfile.
* [Signing environments and key isolation](/supply-chain/signing-environments-and-key-isolation--01a18383d92a.md): three environments, three keys, one secret name.
* [Repo gate and secret scanning](/supply-chain/repo-gate-and-secret-scanning--01a18383d973.md): measured facts, `gitleaks` and the three config guards.
* [Ops.mk validate targets](/supply-chain/ops-mk-validate-targets--01a18383d999.md): what `make -f Ops.mk validate` runs, with `check-wiki`.
* [Two jq traps](/supply-chain/two-jq-traps--01a18383d94f.md): `@tsv` and tab `IFS`.

## Related

* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Operations overview](/operations/operations-overview--01a1837da594.md): the procedures that use these parts.
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Terminology](/guides/terminology--01a1837da60b.md)
