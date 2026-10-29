---
id: "01a18395-b484-7a8a-a5be-1a985ff0c9c3"
title: "The drift workflow validates its proposal with asserted gitleaks values"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "drift"
  - "pdp"
  - "gitleaks"
created: "2026-10-28T12:36:28-05:00"
timestamp: "2026-10-28T12:36:42-05:00"
description: "drift-upstream.yml gives the PDP a literal gitleaks result and config size, against the measured-facts rule of repo-gate.sh."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:42-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/drift-upstream.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/repo-gate.sh"
    title: "scripts/repo-gate.sh"
---

# The drift workflow validates its proposal with asserted gitleaks values

## Problem

The step "Validate the proposal before publishing it" in `.github/workflows/drift-upstream.yml` gives the PDP asserted `gitleaks` values. It does not measure them. This is against the rule of `scripts/repo-gate.sh`: build the PDP input from measured facts, never from asserted literals.

## Context

* The step writes the literal input `gitleaks: {status: "ran", findings: [], config_bytes: 2994, uses_default_ruleset: true}`. It does not run `gitleaks`.
* On 2026-10-28, `.gitleaks.toml` had 3000 bytes, not 2994.
* The header of `scripts/repo-gate.sh` says that it uses "the real gitleaks config size, the real scan output". It gives the reason: the reference repository wrote a hardcoded `gitleaks_passed` value while its config had 0 bytes.
* The step only checks a drift proposal before the workflow publishes it. A human opens the PR from the proposal branch. The `Repo Gate` check on that PR runs `scripts/repo-gate.sh` with measured values.

## Acceptance criteria

- [ ] The drift workflow builds the `gitleaks` part of the input from a real scan and the real size of `.gitleaks.toml`, or it calls `scripts/repo-gate.sh`.
- [ ] Break the check on purpose (for example, an empty `.gitleaks.toml`) and confirm that the step fails.

## Analysis

The risk is low, because the PR still goes through `Repo Gate`. But the literal hides a failure of the config rule from the drift job. The literal also teaches the pattern that `scripts/repo-gate.sh` exists to prevent. A change to `scripts/` rebuilds all images, so do this fix with another `scripts/` change.

## Related

* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [Repo gate and secret scanning](/supply-chain/repo-gate-and-secret-scanning--01a18383d973.md)
* [Policy decision point](/supply-chain/policy-decision-point--01a18383d82e.md)
* [Defects of the reference repo and their guards](/decisions/defects-of-the-reference-repo-and-their-guards--01a18382f526.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
