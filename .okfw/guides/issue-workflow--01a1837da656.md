---
id: "01a1837d-a656-71c0-b970-3822f1116cc8"
title: "Issue workflow"
type: "guide"
tags:
  - "guide"
  - "issue-workflow"
created: "2026-10-28T12:10:12-05:00"
timestamp: "2026-10-28T12:10:12-05:00"
description: "How to record, find and close an issue in the wiki, with the body sections and the state tags."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:10:12-05:00"
---

# Issue workflow

This concept tells you how to record, find and close an issue. An issue records one problem or one task. The wiki is the tracker of record for this project. See [ADR-007: The wiki is the tracker of record](/decisions/adr-007-the-wiki-is-the-tracker-of-record--01a18382f505.md).

## Find issues

* Open issues: `okfw search --kind issue --tag open`
* Closed issues: `okfw search --kind issue --tag resolved`
* Issues for one image: `okfw search --kind issue --tag open --tag nats`

## Record an issue

1. Search the wiki for the problem. If an issue exists, update that issue.
2. Run `okfw create "<Title>" --kind issue --type issue --path issues -d "<one sentence>" --tags issue,open`.
3. Write the title as a statement of the problem, for example "The go1.26 toolchain pin carries stdlib CVEs".
4. Write the body with the sections below.
5. Link the issue to the concepts that it affects, for example an image or a workflow.
6. Add a link to the issue from the [issues overview](/issues/issues-overview--01a1837da5b0.md).

## Body sections

```markdown
## Problem
What is wrong, or what is necessary. One paragraph.

## Context
Why it is important. What it affects. Evidence, with links.

## Acceptance criteria
- [ ] One check that shows the issue is closed.

## Related
- [Concept](/bundle/file.md)
```

## GitHub issues

1. Read each GitHub issue that a bot opens. The drift workflows report drift in GitHub issues.
2. If the bot issue needs work, record a wiki issue. Set `x.github` to the GitHub issue number.
3. Close the GitHub issue with a comment that gives the GitHub URL of the wiki issue.
4. If a GitHub issue needs no work, close it with a comment that gives the reason.

## Waivers

A waiver in `.github/pdp/exceptions.yaml` needs a `ticket` value. For a new waiver, set `ticket` to the GitHub URL of the wiki issue on `main`. Older waivers point to GitHub issues. The wiki issues for these waivers give the GitHub number in `x.github`.

## Close an issue

1. Add a `## Resolution` section. Give the date, the commit or PR, and what changed.
2. Replace the tag `open` with `resolved`: `okfw remove-tags <id> open` and `okfw add-tags <id> resolved`.
3. Run `okfw set-lifecycle <id> deprecated`.

Do not delete a closed issue. Other concepts and commit messages refer to it.

## Related

* [Wiki conventions](/guides/wiki-conventions--01a1837da62e.md)
* [Plan workflow](/guides/plan-workflow--01a1837da67e.md)
