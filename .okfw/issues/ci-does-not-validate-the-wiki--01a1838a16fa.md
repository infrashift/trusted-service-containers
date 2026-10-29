---
id: "01a1838a-16fa-71b2-94f1-341946cce84b"
title: "CI does not validate the wiki"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "okfw"
  - "ci"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "okfw is not in tools.lock, so pr-gate.yml cannot run okfw validate; only the local check-wiki target validates the wiki."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/tools.lock"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
    title: "Ops.mk"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/pr-gate.yml"
    title: ".github/workflows/pr-gate.yml"
---

# CI does not validate the wiki

## Problem

CI does not validate the wiki. `okfw` is not in `tools.lock`, so `.github/workflows/pr-gate.yml` cannot install it or run `okfw validate`. A PR can break the wiki and pass every required check.

## Context

* Only the local target `make -f Ops.mk check-wiki` validates the wiki. `make -f Ops.mk validate` runs it.
* `check-wiki` runs three checks: `okfw validate --all`, `okfw validate --okf` and `okfw graph-query dangling --json`. It fails when `okfw` is not on the `PATH`.
* A new tool in `tools.lock` is a supply-chain decision. The tool must have a pinned version and a checksum.
* A change to `tools.lock` makes `.github/workflows/build.yml` rebuild every image.

## Acceptance criteria

- [ ] `tools.lock` pins `okfw` with a version and a checksum.
- [ ] `scripts/install-tools.sh` installs `okfw` and refuses a binary that does not match the checksum.
- [ ] A step in `.github/workflows/pr-gate.yml` runs the same three checks as `check-wiki`.
- [ ] A PR with a dangling wiki link fails the PR gate. Break a link on purpose and confirm the failure.

## Related

* [lint-skills.sh does not check the paths in the wiki](/issues/lint-skills-sh-does-not-check-the-paths-in-the-wiki--01a1838a16b2.md)
* [No check enforces Simplified Technical English](/issues/no-check-enforces-simplified-technical-english--01a1838a1782.md)
* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
