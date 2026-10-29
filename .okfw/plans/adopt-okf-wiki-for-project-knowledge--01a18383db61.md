---
id: "01a18383-db61-7ec2-8a64-1d2998a287ac"
title: "Adopt OKF Wiki for project knowledge"
type: "plan"
tags:
  - "plan"
  - "okfw"
  - "done"
created: "2026-10-28T12:16:59-05:00"
timestamp: "2026-10-28T20:51:02-05:00"
description: "Move the project knowledge from the PRD, the .ai cards, the docs and GitHub issues into one OKF wiki in .okfw/, written in STE."
status: "deprecated"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T20:51:02-05:00"
sources:
  - resource: "https://github.com/infrashift/okf-wiki"
    title: "okf-wiki (okfw)"
  - resource: "https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md"
    title: "OKF specification"
  - resource: "https://github.com/infrashift/trusted-devcontainer-templates"
    title: "trusted-devcontainer-templates (sibling precedent)"
---

# Adopt OKF Wiki for project knowledge

This plan moves the project knowledge of this repository into one OKF wiki in `.okfw/`. Humans and AI agents read and write the same wiki. The maintainer approved this plan on 2026-10-28.

## Goal

One wiki in `.okfw/` holds the project knowledge that the code does not show: decisions, findings, runbooks, issues and plans. The wiki shows a small amount first and more on request. All prose obeys [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md).

## Context

Before this plan, the knowledge was in many places:

* `.ai/PRD.md`: the architecture, the decisions, the inherited defects and the open items.
* Twelve rule cards in `.ai/skills/`.
* `docs/build-track/dual-provenance.md`.
* Ten GitHub issues.
* The waivers in `.github/pdp/exceptions.yaml`, each with an expiry date.

No place recorded a plan or a dated finding.

The sibling repository `infrashift/trusted-devcontainer-templates` adopted `okfw` on 2026-10-28 (commit `5d19633`). This plan copies its layout of nine bundles plus a wiki map, and its guides.

Decisions of the maintainer:

1. Use this repository, not `trusted-devcontainer-templates`.
2. The wiki is the issue tracker of record.
3. Move the PRD, the `.ai` cards and the `docs/` text into the wiki. Leave a pointer stub in place of each source file.

Facts about `okfw` v2026.10.2 that shape the design:

* `okfw init` has no flags. It writes only `.okfw/index.md` and `.okfw/.gitignore`.
* The bundles of this wiki are subdirectories of `.okfw/`, selected with `--path`.
* The frontmatter schema is closed. Custom fields go under `x:`.
* There is no STE linter.
* `okfw validate --all` is a strict schema check that exits non-zero on failure.
* `okfw graph-query dangling` lists broken links but always exits 0.

A hard constraint: a change to `scripts/`, `.github/pdp/`, `tools.lock` or `rootfs/` makes `build.yml` rebuild all 17 images. This plan touches none of those paths. The changes that need those paths become follow-up issues.

## Disclosure levels

| Level | The reader reads |
|---|---|
| 0 | The `okfw` block in `CLAUDE.md`, the root `index.md` and the [wiki map](/wiki-map--01a1837da4d8.md) |
| 1 | The `index.md` and the overview of one bundle |
| 2 | One concept, with one idea and a description of 25 words or fewer |
| 3 | The `resource` and `sources` of a concept, as GitHub `main` URLs |

## Steps

1. Create the branch `chore/okf-wiki-init` from `main`.
2. Run `okfw init` and `okfw connect`.
3. Run `okfw install` for `claude`, `gemini` and `codex`. Add three STE lines above the block in `CLAUDE.md`.
4. Add `.mcp.json`, `.claude/settings.json` and `.gemini/settings.json`, copied from the sibling. The MCP entries start `${HOME}/.local/bin/okfw`, not `okfw` from the PATH, because an agent that a desktop launcher starts can have a PATH without `~/.local/bin`.
5. Create the wiki map, the nine bundle overviews and the five concepts in `guides/`. Add the rules on digests, secrets, repository paths, drift issues and waiver tickets to the conventions.
6. Give the content to three agents. Each agent writes only its own bundles, with `okfw create`, and marks each concept `draft` and agent-generated:
   * Agent A: `issues/` and `findings/`.
   * Agent B: `architecture/`, `decisions/` and `images/`.
   * Agent C: `supply-chain/`, `operations/` and `plans/`.
7. Link across bundles. Link each open issue to its image or component, each finding to its issue, and each image to its issues and findings. Run `okfw index-md --no-adopt`.
8. Replace the moved sources with pointer stubs of three to five STE lines and a relative link. Do not delete them, because `policies.rego` and `exceptions.yaml` cite them, and an edit to those files rebuilds all images.
9. Update the references in `CLAUDE.md` and `README.md`. Add a "Project knowledge" section to `README.md`.
10. Add the `check-wiki` target to `Ops.mk` and to `validate`. It fails if `okfw` is missing, and it fails on any dangling link.
11. Add `/.okfw/` to `.github/CODEOWNERS` for platform engineers. Add the agent configuration files for security admins.
12. Record follow-up issues with acceptance criteria:
    * `scripts/lint-skills.sh` does not scan `.okfw/`.
    * CI does not run `okfw`, because it is not in `tools.lock`.
    * The comment pointers in `policies.rego` and `exceptions.yaml` point at stubs.
    * No check enforces STE.
13. Run an STE review over all concepts, with the STE guide as the rubric. Fix what it finds.
14. Show the result to the maintainer. Commit and open a pull request only on request. Close or comment on GitHub issues only with approval.

## Verification

1. `make -f Ops.mk validate` passes, with `check-wiki` and `lint-skills`.
2. Break each check on purpose and make sure that it fails. Use a bad pointer link, a dangling wiki link, an unknown frontmatter key, and no `okfw` on `PATH`.
3. `git diff --name-only main` shows no file under `versions.json`, `Containerfiles/`, `rootfs/`, `scripts/`, `tools.lock`, `.github/pdp/` or the build, review and release workflows. Thus no image build starts.
4. `make -f Ops.mk repo-gate` reports no `gitleaks` finding in `.okfw/`.
5. `okfw search --kind issue --tag open` returns the open GitHub issues, the PRD open items and the follow-ups. `okfw search --stale` returns nothing on the day of the merge.
6. `okfw graph --ascii` reaches every bundle overview from the wiki map. Each line in each `index.md` has a description.
7. In a new Claude Code session, the `okfw` skill and MCP server load. A search for "why is observe not a pass" finds the decision.

## Result

The verification passed. PR #40 merged the wiki into `main` on 2026-10-29.

* Steps 1 to 6 of the verification passed on 2026-10-28, before the merge.
* Step 7 passed on 2026-10-29. A new headless Claude Code session ran with a `PATH` that did not include `~/.local/bin`. `claude mcp list` showed `okfw: ${HOME}/.local/bin/okfw mcp - Connected`. The session called `mcp__okfw__okfw_search` for "why is observe not a pass". The first result was [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md). This check did not examine the `okfw` skill separately.
* The GitHub issues that the wiki now tracks were closed on 2026-10-29. See [Close the GitHub issues that the wiki now tracks](/issues/close-the-github-issues-that-the-wiki-now-tracks--01a18395b6bd.md).
* The merge showed a race in the release workflow. See [The release Gate job fails when GitHub has not yet linked the merge commit to its pull request](/issues/the-release-gate-job-fails-when-github-has-not-yet-linked-the-merge-commit-to-its-pull-request--01a1854e501e.md).

## Related

* [Plans overview](/plans/plans-overview--01a1837da5cd.md)
* [Plan workflow](/guides/plan-workflow--01a1837da67e.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Wiki map](/wiki-map--01a1837da4d8.md)
* [Ops.mk validate targets](/supply-chain/ops-mk-validate-targets--01a18383d999.md)
* [Build matrix selection](/supply-chain/build-matrix-selection--01a18383d7c5.md)
* [ADR-007: The wiki is the tracker of record](/decisions/adr-007-the-wiki-is-the-tracker-of-record--01a18382f505.md)
* [lint-skills.sh does not check the paths in the wiki](/issues/lint-skills-sh-does-not-check-the-paths-in-the-wiki--01a1838a16b2.md)
* [CI does not validate the wiki](/issues/ci-does-not-validate-the-wiki--01a1838a16fa.md)
* [Two code comments point at moved skill cards](/issues/two-code-comments-point-at-moved-skill-cards--01a1838a173b.md)
* [No check enforces Simplified Technical English](/issues/no-check-enforces-simplified-technical-english--01a1838a1782.md)
* [Re-running okfw install restores a path example that lint-skills.sh rejects](/issues/re-running-okfw-install-restores-a-path-example-that-lint-skills-sh-rejects--01a18395b684.md)
* [Close the GitHub issues that the wiki now tracks](/issues/close-the-github-issues-that-the-wiki-now-tracks--01a18395b6bd.md)
* [Roadmap](/plans/roadmap--01a18396ce3c.md)
