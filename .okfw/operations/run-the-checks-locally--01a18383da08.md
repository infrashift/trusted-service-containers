---
id: "01a18383-da08-7cc8-bb47-688d6be63bfd"
title: "Run the checks locally"
type: "runbook"
tags:
  - "runbook"
  - "validate"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "Run make -f Ops.mk validate, the repo gate and the policy tests on your machine before you open a pull request."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/repo-gate.sh"
    title: "scripts/repo-gate.sh"
---

# Run the checks locally

This runbook runs the repository checks on your machine. Run them before you propose any change. They are fast.

## Before you start

1. Install the tools at the versions in `tools.lock`. On Linux, you can run `sudo BIN=/usr/local/bin ./scripts/install-tools.sh opa gitleaks regctl`.
2. Install `jq`, `python3` with `jsonschema` and PyYAML, and `shellcheck`.
3. Install `okfw`. The `check-wiki` target fails without it.

## Procedure

1. Run the static checks:

   ```bash
   make -f Ops.mk validate
   ```

2. Make sure that the output ends with `OK: repository validation passed`.
3. Run the repo gate. It runs `gitleaks` and evaluates `data.tsc.pdp.repo_decision`:

   ```bash
   make -f Ops.mk repo-gate
   ```

4. Make sure that the output ends with `OK: repo gate passed`.
5. If you changed `.github/pdp/`, run the policy tests alone to see the coverage:

   ```bash
   make -f Ops.mk policy-test
   ```

6. If you changed a pin, resolve every pin again against the live registries:

   ```bash
   make -f Ops.mk verify-pins
   ```

## One target at a time

To run one check, give its target name. Examples:

* `make -f Ops.mk lint-workflows`
* `make -f Ops.mk lint-containerfiles`
* `make -f Ops.mk check-wiki`
* `make -f Ops.mk verify-build-pins`

`make -f Ops.mk help` lists all targets.

## When you add a check

WARNING: A new check that never fails gives no protection. In this repository, three lint rules first passed because they matched their own comments.

1. Add the check.
2. Break the condition on purpose.
3. Run the check and make sure that it fails.
4. Remove the break and make sure that the check passes.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Ops.mk validate targets](/supply-chain/ops-mk-validate-targets--01a18383d999.md)
* [Repo gate and secret scanning](/supply-chain/repo-gate-and-secret-scanning--01a18383d973.md)
* [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md)
* [Ops.mk skips the shell lint without shellcheck and has a wrong help line](/issues/ops-mk-skips-the-shell-lint-without-shellcheck-and-has-a-wrong-help-line--01a18395b64c.md)
