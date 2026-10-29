---
id: "01a18383-d999-761b-9ba8-ac34c8e7f856"
title: "Ops.mk validate targets"
type: "component"
tags:
  - "supply-chain"
  - "validate"
  - "ops-mk"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The checks that make -f Ops.mk validate runs, in order, including check-wiki for this wiki, and what each check catches."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-skills.sh"
    title: "scripts/lint-skills.sh"
---

# Ops.mk validate targets

`make -f Ops.mk validate` runs the static checks of the repository. It is fast, so run it before you propose any change. It stops at the first target that fails.

## The targets, in order

| Target | What it checks |
|---|---|
| `check-versions` | `versions.json` is valid JSON. Every `digest` is a full `sha256:`. It warns on zero placeholders. Every `shortCommit` is a prefix of its commit. |
| `check-schema` | `versions.json` against `schemas/versions.schema.json`, with `scripts/validate-schema.py`. |
| `check-keyring` | Every `.pub` and `.crt` file in `.github/pdp/keyring/` has a `.sha256` sidecar, and the sidecar matches. |
| `check-gitleaks-config` | `.gitleaks.toml` has 64 bytes or more and sets `useDefault = true`. |
| `check-no-orphan-rego` | Only one policy file and one package exist. |
| `lint-workflows` | The eleven [workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md). |
| `lint-containerfiles` | The [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md) and agreement with `versions.json`. |
| `lint-skills` | Every backticked repository path and relative link in the docs exists. |
| `check-wiki` | This wiki: `okfw validate --all`, `okfw validate --okf`, and no dangling links. |
| `lint-shell` | `shellcheck -S warning` on `scripts/*.sh`. |
| `test-scripts` | `scripts/test-propose-drift.sh`, `scripts/test-drift-upstream.sh` and `scripts/test-release-gate.sh` against fixtures and stubs. |
| `policy-test` | `opa check --strict`, `opa fmt --list`, `opa test`, and a coverage floor of 85%. |

When all targets pass, the output ends with `OK: repository validation passed`.

## The check-wiki target

`check-wiki` fails closed:

1. If `okfw` is not on `PATH`, it stops with an error. A check that skips looks like a pass.
2. It runs `okfw validate --all`, which is a strict schema check.
3. It runs `okfw validate --okf`.
4. It runs `okfw graph-query dangling --json`. That command exits 0 also when links are broken, so the target fails on any output other than `null`.

`okfw` is not in `tools.lock`, so CI does not run `check-wiki`. Only a local `validate` checks the wiki.

## What validate does not run

* `repo-gate`: the `gitleaks` scan and `data.tsc.pdp.repo_decision`. Run `make -f Ops.mk repo-gate`.
* `verify-pins`: it resolves every pin again against the live registries. It needs network access and registry logins.

## lint-skills

`scripts/lint-skills.sh` scans `CLAUDE.md`, `README.md`, `SETUP-ENVIRONMENTS.md`, `.ai/PRD.md`, `.ai/skills/*.md` and `docs/**/*.md`. It checks a backticked string only if it contains a slash and starts in a real top-level directory, for example `scripts/` or `.github/`. It does not scan `.okfw/` today.

## Analysis

* `lint-shell` skips with a warning when `shellcheck` is not installed. The `Repo Gate` job installs it, so CI still checks. A local `validate` can pass without a shell lint.
* The help text of `policy-test` says `opa test --threshold 85`. The target computes the coverage with `jq` and compares it with `awk`. The result is the same floor.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Run the checks locally](/operations/run-the-checks-locally--01a18383da08.md)
* [Repo gate and secret scanning](/supply-chain/repo-gate-and-secret-scanning--01a18383d973.md)
* [Workflow lint checks](/supply-chain/workflow-lint-checks--01a18383d906.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Ops.mk skips the shell lint without shellcheck and has a wrong help line](/issues/ops-mk-skips-the-shell-lint-without-shellcheck-and-has-a-wrong-help-line--01a18395b64c.md)
