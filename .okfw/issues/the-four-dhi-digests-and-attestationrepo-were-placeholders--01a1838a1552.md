---
id: "01a1838a-1552-73ab-9aa2-3494ad4e0323"
title: "The four DHI digests and attestationRepo were placeholders"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "resolved"
  - "prd"
  - "dhi"
  - "postgres"
  - "traefik"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "versions.json shipped placeholder DHI digests and an attestationRepo field; PR #2 resolved the digests and removed the field on 2026-08-24."
status: "deprecated"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.ai/PRD.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/pull/2"
    title: "PR #2"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
    title: "SETUP-ENVIRONMENTS.md"
---

# The four DHI digests and attestationRepo were placeholders

## Problem

`versions.json` shipped the four DHI digests (traefik `runtime` and `dev`, postgres `runtime` and `dev`) as all-zero placeholders. It also had an `attestationRepo` field with the literal value `DISCOVER_AT_BOOTSTRAP`. An authenticated session was necessary to resolve both. `scripts/mirror-leg.sh` refuses to mirror a placeholder pin.

## Context

* Before the wiki adoption, `.ai/PRD.md` listed this open item: "Four DHI digests and `attestationRepo` need an authenticated session." `.ai/PRD.md` is now a pointer to the wiki, and the open items are in the [Issues overview](/issues/issues-overview--01a1837da5b0.md).
* `SETUP-ENVIRONMENTS.md` section 7 gives the procedure to resolve the digests with `regctl manifest head`.

## Acceptance criteria

- [x] The four DHI pins are real digests.
- [x] The mirror finds the DHI attestations.

## Resolution

Resolved on 2026-08-24 in PR #2.

* `3f62ef8` resolved the four placeholder digests.
* `fa26b25` removed `attestationRepo`. DHI publishes attestations as OCI referrers in the repository of the image, not in a separate repository. The field could only be wrong.
* `SETUP-ENVIRONMENTS.md` section 7 records an end-to-end check on 2026-08-24: traefik and postgres, both platforms, 15 referrers each, and every signature verified.

## Related

* [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md)
* [Nobody has measured whether Docker OIDC covers registry.scout.docker.com](/issues/nobody-has-measured-whether-docker-oidc-covers-registry-scout-docker-com--01a1838a159a.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [The notes in versions.json are stale](/issues/the-notes-in-versions-json-are-stale--01a18395b56b.md)
