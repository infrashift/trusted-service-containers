# supply-chain

<!-- okfw:generated — maintained by okfw; edits here are overwritten -->

## Concepts

* [Base Image Drift workflow](base-image-drift-workflow--01a18383d780.md) - The drift-base.yml workflow compares the base pins with the sibling repo each day, pushes a proposal branch and updates one tracking issue.
* [Build matrix selection](build-matrix-selection--01a18383d7c5.md) - How build.yml selects the legs to rebuild, and why a change to scripts/, the PDP, tools.lock or rootfs/ rebuilds every image.
* [Build path filter sync](build-path-filter-sync--01a18383d80b.md) - The BUILD_PATHS regex in pr-gate.yml must cover the paths filter of build.yml, or a pull request waits for a check that never resolves.
* [CI Build & Audit workflow](ci-build-audit-workflow--01a18383d6f4.md) - The build.yml workflow mirrors or builds each selected leg as Build-Actor, scans and signs it, and reports one aggregate build/gate check.
* [CVE gate](cve-gate--01a18383d875.md) - One CVE rule for every image: Critical blocks, fixable High blocks, other findings are recorded, and only a valid waiver changes blocking to waived.
* [Cleanup Dev Images workflow](cleanup-dev-images-workflow--01a18383d75b.md) - How cleanup-dev.yml deletes the development/ image versions of one PR after its release, and why a manual run is a dry run by default.
* [Containerfile policy](containerfile-policy--01a18383d8bc.md) - The rules for build-track Containerfiles that the lint enforces: three stages, ARGs after the runtime FROM, five labels, non-root, no digests.
* [Fail-closed policy contract](fail-closed-policy-contract--01a18383d851.md) - The five rules at the top of policies.rego that make the PDP deny on missing input, and the test rules for each new rule.
* [Matrix injection guard](matrix-injection-guard--01a18383d7e8.md) - The jq schema check on build-matrix.json, byte-identical in build.yml, review.yml and release.yml, and the lint check that keeps the three copies equal.
* [Ops.mk validate targets](ops-mk-validate-targets--01a18383d999.md) - The checks that make -f Ops.mk validate runs, in order, including check-wiki for this wiki, and what each check catches.
* [PR Review Gate workflow](pr-review-gate-workflow--01a18383d6d2.md) - How pr-gate.yml runs the static checks and the repository half of the PDP on every pull request, and seeds review/cve-policy.
* [Policy decision point](policy-decision-point--01a18383d82e.md) - The PDP: one Rego file with one package and two entrypoints, which decide the repository check and the verdict of each leg.
* [Release Images workflow](release-images-workflow--01a18383d737.md) - The release.yml workflow runs on a push to main, finds the reviewed build, and promotes each leg byte-identical to trusted/ or quarantine/.
* [Repo gate and secret scanning](repo-gate-and-secret-scanning--01a18383d973.md) - How the repo gate evaluates the repository half of the PDP from measured facts, and the three guards that keep the gitleaks config real.
* [Review Attestations workflow](review-attestations-workflow--01a18383d715.md) - How review.yml verifies each leg again as Review-Actor, signs a verdict, and resolves the review/cve-policy status.
* [Signing environments and key isolation](signing-environments-and-key-isolation--01a18383d92a.md) - How three GitHub environments isolate three cosign keys under one secret name, with the designed and the live protection rules.
* [Supply chain overview](supply-chain-overview--01a1837da55d.md) - The seven workflows, the PDP, waivers, the signing environments and the lint rules that make, check, sign and promote the images.
* [Two jq traps](two-jq-traps--01a18383d94f.md) - Two shell traps that give a wrong result with no error: @tsv doubles the backslashes in a regex, and a tab IFS joins empty fields.
* [Upstream Drift workflow](upstream-drift-workflow--01a18383d7a3.md) - The drift-upstream.yml workflow finds newer releases, sources and toolchains inside each track, validates the change, and proposes it to a human.
* [Waivers](waivers--01a18383d898.md) - The format and rules of a waiver in exceptions.yaml: the required fields, the 90-day limit, the 40-character justification and the ticket link.
* [Workflow conventions](workflow-conventions--01a18383d8e0.md) - The rules for every workflow: actions pinned by SHA, tools from tools.lock, empty top-level permissions, untrusted values through env, and the required checks.
* [Workflow lint checks](workflow-lint-checks--01a18383d906.md) - The eleven checks in scripts/lint-workflows.sh and the defect that each check prevents.

