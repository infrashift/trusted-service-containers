---
id: "01a18395-b612-7f0a-8154-835b4d7e5f18"
title: "Check 3 of lint-workflows.sh has a dead empty-hash test"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "lint"
  - "ci"
created: "2026-10-28T12:36:29-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "The empty-hash test in check 3 can never fire; a missing injection guard still fails the lint, but with no error message."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
---

# Check 3 of lint-workflows.sh has a dead empty-hash test

## Problem

Check 3 of `scripts/lint-workflows.sh` has a test for an empty hash that cannot fire. If the matrix injection guard is missing from a workflow, the script still fails, but it prints no error message.

## Context

* Check 3 computes `H_BUILD`, `H_REVIEW` and `H_RELEASE` with the function `guard_hash`. The function pipes the guard text through `sha256sum` and `cut`.
* The test is `-z "$H_BUILD"`. The sha256 of empty input is a non-empty value, so `H_BUILD` is never empty. The test never fires.
* The script runs with `set -euo pipefail`. When `awk` finds no guard, `grep -vE '^\s*$'` gets no input and exits with 1. With `pipefail`, the assignment `H_BUILD=$(guard_hash ...)` fails, and `set -e` stops the script.
* A test on 2026-10-28 confirmed this. The function, run on a file with no guard under `set -euo pipefail`, stopped the shell with exit code 1 and no message. The same function without `set -e` gave the hash of empty input.
* Thus a missing guard fails `make -f Ops.mk lint-workflows`, but the output does not say which check failed or why.

## Acceptance criteria

- [ ] Check 3 compares each hash with the hash of empty input, or it tests that `awk` found the guard.
- [ ] A missing guard in one workflow prints an error that names the workflow.
- [ ] Remove the guard from a copy of one workflow and confirm that the check fails with that error.

## Analysis

The check fails closed, so this is not a security gap. The defect is the missing message: a silent exit looks like a broken script, not like a missing guard. The project rule "break it deliberately and confirm it fails" was met for the exit code, not for the message. A change to `scripts/` rebuilds all images, so do this fix with another `scripts/` change.

## Related

* [Workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md)
* [Matrix injection guard](/supply-chain/matrix-injection-guard--01a18383d7e8.md)
* [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
