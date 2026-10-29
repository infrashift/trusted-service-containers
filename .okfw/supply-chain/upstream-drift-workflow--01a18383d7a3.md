---
id: "01a18383-d7a3-7969-8a4e-1276f708362d"
title: "Upstream Drift workflow"
type: "component"
tags:
  - "supply-chain"
  - "workflow"
  - "drift"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The drift-upstream.yml workflow finds newer releases, sources and toolchains inside each track, validates the change, and proposes it to a human."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/drift-upstream.yml"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-upstream.sh"
    title: "scripts/drift-upstream.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/propose-drift.sh"
    title: "scripts/propose-drift.sh"
---

# Upstream Drift workflow

The `Upstream Drift` workflow (`.github/workflows/drift-upstream.yml`) checks each day for newer upstream references inside each track. It checks mirror tags, build-track sources and toolchains. It never edits a track.

## Trigger and actor

| Item | Value |
|---|---|
| Trigger | `schedule` at 06:47 UTC each day, and `workflow_dispatch` |
| Environment | `Build-Actor`, so that the job can read the Docker Hub token |
| Job permissions | `contents: write`, `issues: write` |
| Concurrency | One run at a time. A new run does not cancel the old one. |

The job only pulls from upstream registries, as a mirror leg does. Thus it belongs to the build actor. If `Build-Actor` gets required reviewers, the nightly runs wait for approval.

## What drift-upstream.sh does

### Mirror track

1. List the upstream tags with `regctl tag ls`.
2. Select the highest tag that matches the track, with `sort -V`. Then check the candidate against the track again.
3. If the track matches exactly one tag, the tag is a rolling tag. A new digest behind it is the signal. Re-pin the digest.
4. If the track matches several tags, the tags are immutable version tags. Move the pin to a newer tag if one exists.
5. If an immutable tag points at a new digest, raise an "UPSTREAM RETAG" alarm.

### Build track

1. List the source tags with `git ls-remote`, and select the highest match in the track.
2. Write the new `ref` and the 40-hex commit. Sources with a `repos` map, for example Ory, move all repositories together or the run fails.
3. If the source has a `shortCommit`, compute it from a full bare clone. A blobless clone gives a different abbreviation length.
4. Move each cross-check reference that contains the old version string, and resolve its per-platform digest.
5. Raise an alarm for each value that the script cannot compute. Examples are release tarball hashes, asset hashes, and cross-check tags without the old version.

### Toolchains

1. Resolve the per-architecture digest of each toolchain tag.
2. If it moved, read `GOLANG_VERSION` from the new image config, and write the digest and `goVersion`.
3. Read each pinned architecture back. If the architectures ship different Go versions, raise an alarm.

## Validate before the proposal

If `versions.json` changed, the workflow validates it against the schema and evaluates `data.tsc.pdp.repo_decision`. If the change would fail the repo gate, the workflow stops. A proposal that CI rejects would waste the time of a reviewer.

Then `scripts/propose-drift.sh` pushes the branch `automation/upstream-drift` and updates one tracking issue with the label `upstream-drift`. Alarms alone go to the issue and do not push a branch.

## Analysis

The validation step gives the PDP fixed gitleaks values: `findings: []` and `config_bytes: 2994`. `scripts/repo-gate.sh` measures these values. On 2026-10-28, `.gitleaks.toml` has 3000 bytes, so the fixed value is already wrong. The step checks only `versions.json`, so the decision does not change. The step does not obey the rule "measured facts, not asserted literals".

## Related

* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Base Image Drift workflow](/supply-chain/base-image-drift-workflow--01a18383d780.md)
* [Bump an upstream source within its track](/operations/bump-an-upstream-source-within-its-track--01a18383da54.md)
* [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md)
* [Two jq traps](/supply-chain/two-jq-traps--01a18383d94f.md)
* [The 2026-09-30 drift proposal had wrong crosscheck pins and stale hashes](/issues/the-2026-09-30-drift-proposal-had-wrong-crosscheck-pins-and-stale-hashes--01a1838a12ff.md)
* [Mirror pins and the prometheus-nats-exporter source are behind the 2026-10-28 drift report](/issues/mirror-pins-and-the-prometheus-nats-exporter-source-are-behind-the-2026-10-28-drift-report--01a1838a139f.md)
* [The drift workflow validates its proposal with asserted gitleaks values](/issues/the-drift-workflow-validates-its-proposal-with-asserted-gitleaks-values--01a18395b484.md)
