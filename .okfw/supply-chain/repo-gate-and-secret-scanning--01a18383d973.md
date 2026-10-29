---
id: "01a18383-d973-7dee-87cb-80e4c6083441"
title: "Repo gate and secret scanning"
type: "component"
tags:
  - "supply-chain"
  - "repo-gate"
  - "gitleaks"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "How the repo gate evaluates the repository half of the PDP from measured facts, and the three guards that keep the gitleaks config real."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/repo-gate.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.gitleaks.toml"
    title: ".gitleaks.toml"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/check-no-orphan-rego.sh"
    title: "scripts/check-no-orphan-rego.sh"
---

# Repo gate and secret scanning

`scripts/repo-gate.sh` evaluates `data.tsc.pdp.repo_decision`, the repository half of the PDP. It builds the input from measured facts: the real size of the `gitleaks` config, the real scan output and the real `versions.json`. It never uses an asserted literal.

## Why measured facts

The reference repository wrote `"gitleaks_passed": true` as a fixed string into a signed attestation. At the same time its `.gitleaks.toml` had 0 bytes, and the repository had three live cosign private keys in it.

## What repo-gate.sh does

1. Set `evaluated_at` to the current UTC time, or take it from `EVALUATED_AT`.
2. Measure the size of `.gitleaks.toml`, and check whether it sets `useDefault = true`.
3. Run `gitleaks detect` with `--exit-code 0`. The tool reports and the PDP decides, so only one decision point exists.
4. If `gitleaks` is not installed, set the status `not-installed`. The PDP then denies.
5. Build the input from these facts and `versions.json`.
6. Evaluate `data.tsc.pdp.repo_decision` with the policy and `.github/pdp/exceptions.yaml`.
7. Pipe the result through `jq -e`, so a policy that did not load is a hard failure.
8. Print each violation and warning. Exit 1 if `allow` is not true.

The `Repo Gate` job of `pr-gate.yml` runs it. Locally, run `make -f Ops.mk repo-gate`. `make -f Ops.mk validate` does not run it.

## Three guards on the scanner config

`gitleaks` reads an empty config as zero rules. It scans, finds nothing, and exits 0. That looks the same as a clean scan. Three independent guards prevent this:

1. `.gitleaks.toml` sets `[extend] useDefault = true`.
2. `Ops.mk` target `check-gitleaks-config` and the `Repo Gate` job fail if the file has fewer than 64 bytes or does not set `useDefault = true`.
3. The PDP rules `GITLEAKS_CONFIG_EMPTY` and `GITLEAKS_DEFAULTS_DISABLED` read the measured byte count, not a fixed boolean.

## Custom secret rules

`.gitleaks.toml` adds these rules to the default rule set:

| Rule id | Finds |
|---|---|
| `cosign-sigstore-private-key` | A cosign or Sigstore private key block |
| `pem-private-key-block` | Any PEM private key block |
| `jwt-token` | A JWT, for example an OIDC token pasted into a predicate |
| `github-pat` | A GitHub personal access token |
| `dockerhub-pat` | A Docker Hub personal access token |

The allowlist covers the public keys, the keyring files, generated docs output, the schemas, the policy test file and zero placeholder digests.

`gitleaks` scans the full tree and history, also `.okfw/`. Do not quote a private-key header, a JWT or a token prefix in the wiki.

## Other repository rules of the PDP

`repo_decision` also checks `versions.json` (schema, digests, anchored tracks that match their own pins, source commits) and the waiver register (`EXCEPTIONS_MALFORMED`, `EXCEPTION_INVALID`, `EXCEPTION_ORPHANED`, `EXCEPTION_DUPLICATE_ID`).

## One policy file

`scripts/check-no-orphan-rego.sh` runs before the repo gate. It fails on a `.rego` file outside `.github/pdp/`. It fails on any file in that directory other than `policies.rego` and `policies_test.rego`. It fails if the package is not `tsc.pdp`. Do not add a `.rego` file, also not as an example in the wiki.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Policy decision point](/supply-chain/policy-decision-point--01a18383d82e.md)
* [PR Review Gate workflow](/supply-chain/pr-review-gate-workflow--01a18383d6d2.md)
* [Ops.mk validate targets](/supply-chain/ops-mk-validate-targets--01a18383d999.md)
* [Run the checks locally](/operations/run-the-checks-locally--01a18383da08.md)
* [The drift workflow validates its proposal with asserted gitleaks values](/issues/the-drift-workflow-validates-its-proposal-with-asserted-gitleaks-values--01a18395b484.md)
