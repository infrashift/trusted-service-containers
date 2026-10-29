---
id: "01a18395-b4ba-726d-aa23-277c4a2e008c"
title: "Eight build Containerfiles say that fetch-source.sh removes .git"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "docs"
  - "build"
  - "ory"
  - "dapr"
  - "nats"
created: "2026-10-28T12:36:28-05:00"
timestamp: "2026-10-28T12:36:42-05:00"
description: "The Ory, dapr and nats Containerfiles say fetch-source.sh removes .git; the script keeps .git on purpose for VCS provenance."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:42-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/fetch-source.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/nats.Containerfile"
    title: "Containerfiles/nats.Containerfile"
---

# Eight build Containerfiles say that fetch-source.sh removes .git

## Problem

Eight build Containerfiles say that `scripts/fetch-source.sh` removes `.git`. The script keeps `.git` on purpose. The comment is wrong.

## Context

* The comment is in the Containerfiles of the four Ory images, the three dapr images and nats, for example `Containerfiles/nats.Containerfile`. It says that the script "removes .git so `go build` cannot stamp a pseudo-version from a shallow clone".
* The other four build Containerfiles (loki, prometheus, `prometheus-nats-exporter`, seaweedfs) do not have this sentence.
* `scripts/fetch-source.sh` says ".git is KEPT deliberately". Without `.git`, `go version -m` shows the module version `(devel)` and no `vcs.*` provenance. The script fetches the tag, which prevents the pseudo-version problem.
* [ADR-004](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md) records this: the first script deleted `.git`, and the fix keeps it.

## Acceptance criteria

- [ ] No Containerfile says that `scripts/fetch-source.sh` removes `.git`.
- [ ] The comment says that the script keeps `.git` and fetches the tag.

## Analysis

A change to `Containerfiles/` rebuilds every image that the change touches. Do this fix with the next change to these eight Containerfiles.

## Related

* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [kratos](/images/kratos--01a183832d7f.md)
* [hydra](/images/hydra--01a183832d9f.md)
* [keto](/images/keto--01a183832dc0.md)
* [oathkeeper](/images/oathkeeper--01a183832de0.md)
* [daprd](/images/daprd--01a183832e23.md)
* [dapr-placement](/images/dapr-placement--01a183832e48.md)
* [dapr-scheduler](/images/dapr-scheduler--01a183832e6e.md)
* [nats](/images/nats--01a183832e00.md)
