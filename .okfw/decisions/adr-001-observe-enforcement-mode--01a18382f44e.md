---
id: "01a18382-f44e-713d-b671-d09278944310"
title: "ADR-001: Observe enforcement mode"
type: "decision"
tags:
  - "decision"
  - "enforcement"
  - "observe"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "ADR-001 lets a new upstream go through review in observe mode: violations do not make the pipeline red, but they send the image to quarantine/."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-leg.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/29"
    title: "PR #29"
x:
  adr: 1
  github: 29
---

# ADR-001: Observe enforcement mode

ADR-001 adds the enforcement value `observe`. An image in `observe` mode gets a full scan and a signed `PASS` verdict. If the leg has violations, it goes to `quarantine/`. If the leg has no violations, it goes to `trusted/`.

**Status:** Accepted, 2026-08-18. Amended 2026-10-13 with the rule "observe is not a pass".

## Context

A new upstream often has findings on its first scan. A person must triage them before the image can pass in `enforce` mode. If each new upstream made `main` red until the end of the triage, nobody could add an upstream in small steps.

## Decision

Each image has an `enforcement` value in `versions.json`: `enforce` or `observe`.

* An `observe` leg still publishes each violation.
* An `observe` leg with violations goes to `quarantine/`. The `observe` value is not a route into `trusted/` for an image with violations.
* The signed review verdict has a `namespace` value that is separate from `PASS` or `FAIL`.
* The PDP sets the namespace to `trusted` only when the leg has no violations. The enforcement value does not change the namespace. See `target_namespace` in `.github/pdp/policies.rego`.
* `scripts/release-leg.sh` routes on the namespace. Thus an `observe` leg with violations and `PASS` goes to `quarantine/`. The release actor does not promote it to `trusted/`.

`.ai/PRD.md` and a code comment in `.github/pdp/policies.rego` say that `observe` "still routes to quarantine". That is true only for a leg with violations. An `observe` leg with no violations goes to `trusted/`. For example, on 2026-10-28 the `observe` build legs of loki and seaweedfs had no blocking findings and went to `trusted/`. See [On 2026-10-28 every build leg was trusted and every mirror leg was quarantined](/findings/on-2026-10-28-every-build-leg-was-trusted-and-every-mirror-leg-was-quarantined--01a1838a6fc5.md).

## Amendment: observe is not a pass

An `observe` leg with blocking findings gets a green `review/cve-policy` check, and it goes to `quarantine/`. A green check does not mean that the image is clean.

On 2026-10-13, PR #29 (prometheus-nats-exporter) merged two minutes after a review comment. The comment showed one Critical and seven High findings for each architecture. All were `stdlib` findings. The check was green, so the PR merged.

Thus, before you merge an image PR, do these steps:

1. Before you open the PR, scan the local build. Then the review is not the first place where you see the findings.
2. Read the review comment.
3. Make sure that the Blocking column is 0.
4. If the Blocking column is not 0, write in the PR why `quarantine/` is the intended result.

## Consequences

* A new upstream can join without a red `main`.
* The green check of an `observe` leg does not show the findings. The reviewer must read the review comment.
* After a clean review, a change to `versions.json` moves an image from `observe` to `enforce`. For example, prometheus moved on 2026-10-01 and prometheus-nats-exporter moved on 2026-10-14.

## Related

* [Promotion](/architecture/promotion--01a18382f371.md): verdict and namespace.
* [ADR-003: Quarantine is a documented state](/decisions/adr-003-quarantine-is-a-documented-state--01a18382f486.md)
* [prometheus-nats-exporter](/images/prometheus-nats-exporter--01a183832f0f.md): the image of PR #29.
* [Toolchain pins](/architecture/toolchain-pins--01a18382f31f.md): why the PR #29 findings came from the compiler.
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [Move an image from observe to enforce](/operations/move-an-image-from-observe-to-enforce--01a18383dac5.md)
* [Bump an upstream source within its track](/operations/bump-an-upstream-source-within-its-track--01a18383da54.md)
* [The main ruleset requires only the Repo Gate check](/issues/the-main-ruleset-requires-only-the-repo-gate-check--01a18395b44e.md)
