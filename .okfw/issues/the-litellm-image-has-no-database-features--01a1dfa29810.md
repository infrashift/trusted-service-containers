---
id: "01a1dfa2-9810-7c9f-b029-d7b354be4347"
title: "The litellm image has no database features"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "litellm"
  - "native"
  - "python"
created: "2026-11-15T08:35:37-06:00"
timestamp: "2026-11-15T08:35:37-06:00"
description: "Virtual keys, spend logs and the admin UI login with a database need Prisma and Node.js, which the litellm image does not carry; the owner wants them later, under the constraints of ADR-010."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/litellm.Containerfile"
---

# The litellm image has no database features

## Problem

The [litellm](/images/litellm--01a1df710394.md) image runs the stateless LiteLLM proxy: a config file, a master key, and Valkey for the shared state. It has no database features: virtual keys, spend logs, and the admin UI login against a database. These features need Prisma, the Prisma query engine binaries and Node.js. The image has none of them.

On 2026-11-15 the owner decided to add the database features later ("Add them later? Yes").

## Context

* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md) put the database features out of scope. It says that they need a new decision.
* LiteLLM installs Prisma with the `extra-proxy` extra. At run time Prisma generates its client and downloads its query engine, unless the engine is already present.
* The DHI LiteLLM image had four blocking findings on 2026-11-15, all in its bundled Node.js 24.19.0. This is the reason that ADR-010 built the image without Node.js. See [On 2026-11-15 DHI Valkey had 2 unfixed Criticals, DHI LiteLLM 4 Node findings and DHI Ollama none](/findings/on-2026-11-15-dhi-valkey-had-2-unfixed-criticals-dhi-litellm-4-node-findings-and-dhi-ollama-none--01a1dee755b1.md).
* UBI9 AppStream has Node.js 24.22.1 in the `nodejs:24` module stream (ADR-010).
* The database would be [postgresql17](/images/postgresql17--01a1dd2247ba.md).

## Design constraints (from ADR-010)

A change that adds the database features must keep every property of the kind `native`:

1. **A new decision first.** An ADR, or an amendment to ADR-010, accepted by the owner, before any code.
2. **Signed UBI packages only.** Node.js comes from the signed UBI repositories (`nodejs:24`), with `gpgcheck=1`. No NodeSource repository, no `curl | sh`, and no repository that the Containerfile lint rejects.
3. **Hash-locked Python.** Prisma (`prisma` and its dependencies) enters through `locks/litellm/requirements.in` and the hash lock, with `--require-hashes --no-deps --only-binary=:all:`. The review still requires that the venv equals the lock.
4. **No download at run time.** The Prisma query engine and the generated client are made in the builder, from inputs pinned by hash. The runtime must not fetch a binary, an npm package or a schema engine at start.
5. **No compiler or pip in the runtime stage.** Node.js and the engine are runtime dependencies only. `npm` stays out of the runtime stage if possible.
6. **We own every finding.** Node.js and npm findings, and the Prisma engine, count against the CVE gate. A Node.js finding that UBI has not fixed blocks, as the krb5-libs findings did.
7. **The same gates.** The five required labels, UID 1001 in GID 0, a smoke test in the Containerfile (with a database), and the master-key refusal of the entrypoint.
8. **Optional, not default, if possible.** The stateless proxy stays the default. A second variant, or a switch, carries the database features, so that HALO deployments without a database do not carry Node.js.

## Acceptance criteria

- [ ] The owner accepts a decision for the database features (an ADR or an amendment to ADR-010).
- [ ] The litellm image, or a second variant, runs with `DATABASE_URL` against postgresql17: virtual keys, spend logs and the UI login work in a smoke test.
- [ ] The image downloads nothing at start.
- [ ] The first review of the change has Blocking 0, or the pull request explains the quarantine.

## Related

* [litellm](/images/litellm--01a1df710394.md)
* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [postgresql17](/images/postgresql17--01a1dd2247ba.md)
* [drift-upstream.sh does not propose new LiteLLM releases](/issues/drift-upstream-sh-does-not-propose-new-litellm-releases--01a1df7103b9.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
