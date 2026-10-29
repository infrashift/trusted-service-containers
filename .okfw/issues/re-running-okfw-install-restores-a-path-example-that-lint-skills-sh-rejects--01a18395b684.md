---
id: "01a18395-b684-7bdb-b6ee-9844fdc3ef20"
title: "Re-running okfw install restores a path example that lint-skills.sh rejects"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "okfw"
  - "lint"
created: "2026-10-28T12:36:29-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "The okfw block template has a backticked ./file.md example that lint-skills.sh fails on; okfw install undoes the local fix."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-skills.sh"
sources:
  - resource: "https://github.com/infrashift/okf-wiki"
    title: "infrashift/okf-wiki"
---

# Re-running okfw install restores a path example that lint-skills.sh rejects

## Problem

`okfw install --platform claude` writes a block into `CLAUDE.md` that `scripts/lint-skills.sh` rejects. The block has a backticked link example, "./file.md". The lint reads it as a path claim, and no such file exists. The maintainer edited the example in this repository. A new run of `okfw install` restores the old text.

## Context

* `scripts/lint-skills.sh` scans `CLAUDE.md`. It treats a backticked string with a slash that starts with "./" as a repository path.
* The `okfw` v2026.10.2 binary holds the block template. The template has the example "./file.md" in code font.
* The maintainer changed the example in `CLAUDE.md` to "./<file>.md". The lint regex does not match "<", so the lint passes.
* A test on 2026-10-28, in an empty directory: `okfw install --platform claude` wrote the block. An edit changed the example. A second `okfw install --platform claude` wrote "./file.md" again. The block is a managed block, and each install replaces it.
* `AGENTS.md` and `GEMINI.md` have the same block. `scripts/lint-skills.sh` does not scan them.

## Acceptance criteria

- [ ] The block template in `infrashift/okf-wiki` uses an example that is not a path claim, or `scripts/lint-skills.sh` skips the managed `okfw` block.
- [ ] Run `okfw install --platform claude` again, then run `make -f Ops.mk lint-skills`. The lint passes.

## Analysis

The upstream fix is better, because every repository that uses both `okfw` and a path lint has the same problem. A fix in `scripts/lint-skills.sh` rebuilds all images. Until one fix exists, do not run `okfw install` in this repository without a check of the result.

## Related

* [lint-skills.sh does not check the paths in the wiki](/issues/lint-skills-sh-does-not-check-the-paths-in-the-wiki--01a1838a16b2.md)
* [CI does not validate the wiki](/issues/ci-does-not-validate-the-wiki--01a1838a16fa.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
