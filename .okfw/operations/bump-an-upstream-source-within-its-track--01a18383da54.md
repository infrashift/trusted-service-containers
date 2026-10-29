---
id: "01a18383-da54-76a9-8b64-942c67d65d0b"
title: "Bump an upstream source within its track"
type: "runbook"
tags:
  - "runbook"
  - "source"
  - "drift"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:42-05:00"
description: "Take a drift-upstream proposal for a build-track source, add the hashes that it cannot compute, and merge it after a clean review."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:42-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-upstream.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/2f1a347"
    title: "Bump dapr and loki (2026-10-28)"
  - resource: "https://github.com/infrashift/trusted-service-containers/commit/9600a87"
    title: "Bump nats, prometheus, seaweedfs (2026-10-28)"
  - resource: "https://github.com/infrashift/trusted-service-containers/issues/24"
    title: "Upstream drift tracking issue #24"
---

# Bump an upstream source within its track

This runbook moves a build-track source in the `sources` map of `versions.json` to a newer release inside its track. The usual input is a proposal from the [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md).

## Examples

* Commit `2f1a347` (2026-10-28) moved dapr to v1.18.9 and loki to v3.7.9. The blocking findings in the review of #35 were all `golang.org/x/net` advisories, and the new releases require a fixed `x/net`. The commit took the values from the drift proposal in GitHub issue #24, with two corrections: the loki `shortCommit` and stale notes.
* Commit `9600a87` (2026-10-28) moved nats, prometheus and seaweedfs, also from #24. It added the two values that the proposal flagged: the nats release tarball hashes and the prometheus web UI hash.

## Before you start

WARNING: Do not widen a track as part of a bump. A track change is a policy decision and needs its own reviewed pull request.

1. Read the drift tracking issue (label `upstream-drift`). Read the "Needs attention" list.
2. Read the upstream release notes. A source bump changes the application version, not only the build.

## Procedure

1. Check out the branch `automation/upstream-drift`, or create a branch from `main` and copy the change.
2. For each source, make sure that `ref` matches the track. Make sure that the commit is the 40-hex commit of that tag.
3. If the source has `shortCommit`, make sure that it is the abbreviation that the vendor binary reports. The drift script computes it from a full clone, but the vendor can use a different length. Commit `2f1a347` corrected loki to the 8-character value.
4. Copy each `crosscheck.releaseTarballSha256` value from the vendor release.
5. Make sure that each value matches the hash of the downloaded file.
6. Copy each asset `sha256` value from the release checksums of the vendor. Until you do, `scripts/fetch-assets.sh` fails the build.
7. Re-pin by hand each cross-check tag that the script did not move, with its per-platform digest.
8. Update the `note` and `reason` text of each changed entry, so it does not describe an old pin.
9. Run `make -f Ops.mk validate` and `make -f Ops.mk verify-pins`.
10. Open the pull request. A human must open it, because `GITHUB_TOKEN` cannot.
11. Read the review comment. Blocking must be 0, or the pull request must say why `quarantine/` is the correct result.
12. If one finding still blocks and no release in the track fixes it, [waive the CVE](/operations/waive-a-cve--01a18383da9f.md).

After the merge, the next drift run closes the tracking issue when every pin is current.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [Re-pin a toolchain](/operations/re-pin-a-toolchain--01a18383da2e.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [loki](/images/loki--01a183832eba.md)
* [nats](/images/nats--01a183832e00.md)
* [prometheus](/images/prometheus--01a183832e94.md)
* [seaweedfs](/images/seaweedfs--01a183832ee2.md)
