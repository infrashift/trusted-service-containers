---
id: "01a18383-d94f-7b2f-89ec-7d77f16a9411"
title: "Two jq traps"
type: "component"
tags:
  - "supply-chain"
  - "jq"
  - "shell"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "Two shell traps that give a wrong result with no error: @tsv doubles the backslashes in a regex, and a tab IFS joins empty fields."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-upstream.sh"
    title: "scripts/drift-upstream.sh"
---

# Two jq traps

Two traps in `jq` and the shell caused long debug sessions in this repository. Both give a wrong result with no error.

## Trap 1: @tsv escapes backslashes

`jq -r '... | @tsv'` writes each backslash as two backslashes. A track regex such as `^3\.90\.[0-9]+-ubi$` then arrives with doubled backslashes and matches nothing. The symptom looks like a configuration error, not a tool error.

Rule:

1. Send only slugs through `@tsv`, for example a service name and a variant name.
2. In the loop, read every other value with `jq --arg`, for example the track.

`scripts/drift-upstream.sh` obeys this rule. Its loop reads only the service and the variant from `@tsv`. It then reads `track`, `tag` and `digest` with `jq -r --arg s "$svc" --arg v "$variant"`.

## Trap 2: tab is IFS whitespace

Bash treats tab as whitespace in `IFS`. Thus `IFS=$'\t' read -r a b c` joins two adjacent tabs into one separator. An empty field disappears, and every later column moves one place to the left. The script then reads the wrong value into each variable after the empty field.

Rule:

1. Do not send a field that can be empty through `@tsv` and `IFS=$'\t' read`.
2. If a field can be empty, read it with `jq --arg` in the loop, or give it a non-empty placeholder.

## Analysis

* `Ops.mk` target `verify-mirror-pins` sends `track` through `@tsv`. It only prints the track, so the result is a display with doubled backslashes, not a wrong decision.
* `Ops.mk` target `check-versions` reads `shortCommit` through `@tsv`. It selects only sources that have `shortCommit`, so no field is empty.

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Workflow conventions](/supply-chain/workflow-conventions--01a18383d8e0.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [Ops.mk skips the shell lint without shellcheck and has a wrong help line](/issues/ops-mk-skips-the-shell-lint-without-shellcheck-and-has-a-wrong-help-line--01a18395b64c.md)
