---
id: "01a18383-d82e-7bbb-b839-fdf93ba421c1"
title: "Policy decision point"
type: "component"
tags:
  - "supply-chain"
  - "pdp"
  - "policy"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The PDP: one Rego file with one package and two entrypoints, which decide the repository check and the verdict of each leg."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/check-no-orphan-rego.sh"
    title: "scripts/check-no-orphan-rego.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies_test.rego"
    title: "policies_test.rego"
---

# Policy decision point

The policy decision point (PDP) is `.github/pdp/policies.rego`, package `tsc.pdp`. It is the only policy file. It decides whether the repository is acceptable and which namespace each leg goes to.

## One file, one package

No other `.rego` file can exist in the repository. `scripts/check-no-orphan-rego.sh` enforces this. It fails on a `.rego` file outside `.github/pdp/`, or on an unexpected file in that directory. It also fails if the package is not `tsc.pdp`.

The reference repository had six orphaned policy files that contradicted the live policy. Two of them would have denied every image, but nothing evaluated them, so nobody saw it.

## Two entrypoints

| Query | Scope | Caller |
|---|---|---|
| `data.tsc.pdp.repo_decision` | The repository: secret scanning, the `versions.json` schema and tracks, waiver hygiene. One time for each pull request. | `scripts/repo-gate.sh` |
| `data.tsc.pdp.decision` | One leg, for both tracks. A mirror leg is one service and variant over a full index. A build leg is one service and architecture. | `scripts/review-leg.sh` |

## How to evaluate it

1. Pass `--data .github/pdp/policies.rego` and `--data .github/pdp/exceptions.yaml` to `opa eval`.
2. Supply `evaluated_at` in the input. The policy never reads a clock.
3. Pipe the result through `jq -e`. It exits non-zero on `null` or `false`, so a policy that did not load is a hard failure.

WARNING: Do not pass `--strict-builtin-errors`. With the default, a builtin error becomes undefined. That empties the waiver set and leaves every Critical unwaived, which is the fail-closed direction.

## Trust class decides signature checks only

The trust class (`dhi`, `internal`, `notation`, `none`) decides which signature and which attestations the PDP requires. It never appears in a CVE rule. Before you merge a change to the policy, search it for `trust_class` and make sure that no CVE rule uses it.

## Determinism

The policy never calls `time.now_ns()`. Every time comparison uses `input.evaluated_at`. The same input gives the same output a year later. Thus anyone can evaluate the archived input again and get the signed verdict again.

## The leg decision

* `allow` is true when the leg has no violation.
* `namespace` is `trusted` when the leg has no violation. In all other cases it is `quarantine`.
* When `enforcement` is `observe`, `allow` is also true with violations. The namespace stays `quarantine`. Thus `observe` stops a hard failure of the pipeline, but it is not a route into `trusted/`.
* A default decision with `allow: false` and namespace `quarantine` applies if the policy does not evaluate.

## Rule codes

Each violation, warning and observation has a code, for example `CVE_CRITICAL`, `TRACK_VIOLATION`, `BUILD_LABEL_EMPTY` or `EXCEPTION_INVALID`. Search `policies.rego` for the code to find the rule. The tests are in `.github/pdp/policies_test.rego`.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md)
* [CVE gate](/supply-chain/cve-gate--01a18383d875.md)
* [Waivers](/supply-chain/waivers--01a18383d898.md)
* [Repo gate and secret scanning](/supply-chain/repo-gate-and-secret-scanning--01a18383d973.md)
* [Review Attestations workflow](/supply-chain/review-attestations-workflow--01a18383d715.md)
