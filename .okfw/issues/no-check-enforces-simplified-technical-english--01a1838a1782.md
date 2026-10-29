---
id: "01a1838a-1782-7a10-8466-aaf906f6f602"
title: "No check enforces Simplified Technical English"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "okfw"
  - "ste"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:23:47-05:00"
description: "okfw has no prose linter, so only review checks STE; decide on a tool or record that review is the control."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:47-05:00"
---

# No check enforces Simplified Technical English

## Problem

No check enforces Simplified Technical English in the wiki. `okfw` validates the structure of a concept, but it has no prose linter. Only a human review finds long sentences, the passive voice or words that are not in the terminology.

## Context

* The wiki guide [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md) sets the rules: sentence length, active voice, imperative steps and controlled words.
* The guide [Terminology](/guides/terminology--01a1837da60b.md) lists the controlled words and the words not to use.
* AI agents write most concepts. A rule that no tool checks can drift without a signal.

## Acceptance criteria

- [ ] A decision records the control for STE: a tool or human review only. An example of a tool is a Vale style that encodes the terminology table.
- [ ] If the decision is a tool: `tools.lock` pins the tool, and `make -f Ops.mk validate` runs it.
- [ ] If the decision is review only: the [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md) say so.

## Related

* [CI does not validate the wiki](/issues/ci-does-not-validate-the-wiki--01a1838a16fa.md)
* [Simplified Technical English](/guides/simplified-technical-english--01a1837da5eb.md)
* [Terminology](/guides/terminology--01a1837da60b.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [Adopt OKF Wiki for project knowledge](/plans/adopt-okf-wiki-for-project-knowledge--01a18383db61.md)
