---
id: "01a1df71-03b9-71b5-b01b-cad373c605bf"
title: "drift-upstream.sh does not propose new LiteLLM releases"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "litellm"
  - "drift"
  - "native"
created: "2026-11-15T07:41:28-06:00"
timestamp: "2026-11-15T07:41:28-06:00"
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-upstream.sh"
description: "A native python image pins a hash lock, which drift-upstream.sh cannot regenerate; a LiteLLM bump is a manual lock and pin change."
---

# drift-upstream.sh does not propose new LiteLLM releases

## Problem

`scripts/drift-upstream.sh` proposes new releases for git sources, mirror tags, toolchains and package NEVRAs. It does not look at the [litellm](/images/litellm--01a1df710394.md) image. A native python image has no git source. Its pinned input is a hash lock, and a new release needs a new lock: the resolver, the hashes and the new sha256 pin. The script cannot make that change safely in an unattended run.

## Context

* LiteLLM releases often. On 2026-11-15 the newest release that is not a pre-release was 1.109.1, and PyPI had release candidates for 1.110.0.
* A new lock can also change the other 116 distributions. A reviewer must see that diff.

## Acceptance criteria

- [ ] The drift workflow reports when PyPI has a newer release of `native.distribution` than `native.version`, as an alarm, without a change to the lock.
- [ ] Or a decision records that LiteLLM bumps stay manual.

## Related

* [litellm](/images/litellm--01a1df710394.md)
* [Upstream drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
