---
id: "01a18395-b534-73fb-9faf-c281b44f6d63"
title: "README.md describes an older image set and an old test count"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "docs"
created: "2026-10-28T12:36:28-05:00"
timestamp: "2026-10-28T12:36:43-05:00"
description: "README.md omits four build images, says 85 policy tests, and argues against :latest with twelve services instead of 17 images."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:36:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/README.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies_test.rego"
    title: ".github/pdp/policies_test.rego"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
    title: "versions.json"
---

# README.md describes an older image set and an old test count

## Problem

`README.md` describes an older image set. Its build track list does not name four images, its test count is old, and its argument against `:latest` uses an old image count.

## Context

On 2026-10-28, `README.md` and `versions.json` disagreed in these places:

* The build track table names the Ory images, nats and the dapr images. It does not name prometheus, loki, seaweedfs and `prometheus-nats-exporter`. `versions.json` has 12 build track images.
* The text before the table says "The Ory services, NATS and Dapr publish only distroless, Alpine and Windows variants". It does not give the reason for the four newer images.
* The policy section says that `.github/pdp/policies.rego` has "85 tests". `.github/pdp/policies_test.rego` has 99 rules whose names start with `test_`. The coverage floor is 85%, which is possibly the source of the number.
* The `:latest` section says "Across twelve services". `versions.json` has 17 images.

The wiki does not repeat these numbers. [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md) and [ADR-002: No latest tag](/decisions/adr-002-no-latest-tag--01a18382f469.md) give the counts of 2026-10-28.

## Acceptance criteria

- [ ] The build track table in `README.md` names all 12 build track images, or links to the [Images overview](/images/images-overview--01a1837da526.md).
- [ ] `README.md` gives no test count, or a check keeps the count correct.
- [ ] The `:latest` section gives no image count, or gives the correct count.

## Analysis

A fixed count in prose goes stale with each new image or test. A link to `versions.json` or to the wiki stays correct. `README.md` is not a build path, so this fix starts no image build.

## Related

* [Images overview](/images/images-overview--01a1837da526.md)
* [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md)
* [ADR-002: No latest tag](/decisions/adr-002-no-latest-tag--01a18382f469.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
