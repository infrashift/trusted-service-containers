---
id: "01a18395-b64c-7abf-9b74-780030f2110d"
title: "Ops.mk skips the shell lint without shellcheck and has a wrong help line"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "lint"
  - "ops-mk"
created: "2026-10-28T12:36:29-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "lint-shell passes when shellcheck is missing, the policy-test help line is wrong, and verify-mirror-pins sends track through @tsv."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/pr-gate.yml"
    title: ".github/workflows/pr-gate.yml"
---

# Ops.mk skips the shell lint without shellcheck and has a wrong help line

## Problem

`Ops.mk` has three small defects. The `lint-shell` target skips the shell lint with a warning when `shellcheck` is missing, so a local `validate` passes without it. The `help` text for `policy-test` describes a command that the target does not run. The `verify-mirror-pins` target sends `track` through `@tsv`.

## Context

* `lint-shell` prints "warning: shellcheck not installed; skipping shell lint" and exits with 0. `validate` depends on `lint-shell`, so `make -f Ops.mk validate` ends with "OK: repository validation passed".
* CI is not affected. `.github/workflows/pr-gate.yml` installs `shellcheck` and runs it directly.
* The `check-wiki` target of the same file fails when `okfw` is missing. Its comment says "a check that skips reads as a pass".
* `help` says that `policy-test` runs `opa test --threshold 85`. The target runs `opa test --coverage --format json`, reads the coverage with `jq`, and compares it with 85 in `awk`. The floor is the same.
* `verify-mirror-pins` reads the mirror variants with `jq ... | @tsv`, which escapes backslashes. The `track` field is only printed, so a regex such as the nexus3 track shows double backslashes. No comparison uses it.

## Acceptance criteria

- [ ] `lint-shell` fails when `shellcheck` is missing, as `check-wiki` does when `okfw` is missing.
- [ ] The `help` line for `policy-test` describes what the target runs.
- [ ] `verify-mirror-pins` prints each `track` as `versions.json` holds it. Follow the rule in [Two jq traps](/supply-chain/two-jq-traps--01a18383d94f.md): send only slugs through `@tsv`.

## Analysis

`Ops.mk` is not a build path, so this fix starts no image build. The `@tsv` use is harmless today, but a later change that matches against `track` would match nothing. That is the first trap in [Two jq traps](/supply-chain/two-jq-traps--01a18383d94f.md).

## Related

* [Ops.mk validate targets](/supply-chain/ops-mk-validate-targets--01a18383d999.md)
* [Run the checks locally](/operations/run-the-checks-locally--01a18383da08.md)
* [Two jq traps](/supply-chain/two-jq-traps--01a18383d94f.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
