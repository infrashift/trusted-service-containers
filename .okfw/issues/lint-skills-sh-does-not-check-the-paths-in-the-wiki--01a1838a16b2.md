---
id: "01a1838a-16b2-76a2-a1c5-586731acc500"
title: "lint-skills.sh does not check the paths in the wiki"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "okfw"
  - "lint"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "scripts/lint-skills.sh scans a fixed file list without .okfw/, so a wiki concept can cite a path that does not exist."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-skills.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/build.yml"
    title: ".github/workflows/build.yml"
---

# lint-skills.sh does not check the paths in the wiki

## Problem

`scripts/lint-skills.sh` does not check the repository paths in the wiki. A concept can cite a path that does not exist, and the lint still passes.

## Context

* The lint scans a fixed list of files: `CLAUDE.md`, `README.md`, `SETUP-ENVIRONMENTS.md`, `.ai/PRD.md`, `.ai/skills/*.md` and `docs/**/*.md`. The list does not include `.okfw/`.
* The function `repo_path` accepts only paths that start with `scripts/`, `.github/`, `docs/`, `.ai/`, `Containerfiles/`, `schemas/`, `rootfs/`, `../` or `./`. A path that starts with `.okfw/` is not checked.
* The wiki conventions tell writers to write repository paths in code font and to make sure that they exist. Only a review checks this now.
* A change in `scripts/` makes `.github/workflows/build.yml` rebuild every image. The regex in the matrix step of `.github/workflows/build.yml` selects the full matrix when a file in `scripts/` changes.

## Acceptance criteria

- [ ] `scripts/lint-skills.sh` scans the markdown files in `.okfw/`, with `globstar` or `find`.
- [ ] `repo_path` accepts paths that start with `.okfw/`.
- [ ] A concept with a path that does not exist makes the lint fail. Break a path on purpose and confirm the failure.
- [ ] Merge this change together with the next change in `scripts/`, so that the full rebuild occurs one time only.

## Related

* [CI does not validate the wiki](/issues/ci-does-not-validate-the-wiki--01a1838a16fa.md)
* [Two code comments point at moved skill cards](/issues/two-code-comments-point-at-moved-skill-cards--01a1838a173b.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
* [The nats config cites a runtime document that does not exist](/issues/the-nats-config-cites-a-runtime-document-that-does-not-exist--01a18395b4f1.md)
* [Re-running okfw install restores a path example that lint-skills.sh rejects](/issues/re-running-okfw-install-restores-a-path-example-that-lint-skills-sh-rejects--01a18395b684.md)
