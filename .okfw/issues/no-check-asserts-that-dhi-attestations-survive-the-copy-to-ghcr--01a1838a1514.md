---
id: "01a1838a-1514-7a1f-90c6-c6f5a8128e7a"
title: "No check asserts that DHI attestations survive the copy to GHCR"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "prd"
  - "dhi"
  - "mirror"
  - "signing"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "The mirror asserts the Notary referrer after the copy but not the DHI referrers; the cosign v2 pin is already decided."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.ai/PRD.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
    title: "SETUP-ENVIRONMENTS.md"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
    title: "scripts/mirror-leg.sh"
---

# No check asserts that DHI attestations survive the copy to GHCR

## Problem

No check asserts that the DHI signatures and attestations survive the copy of a mirror image to GHCR. The digest check in `scripts/mirror-leg.sh` cannot see referrers. regclient turns an unsupported referrers API into an empty list, not an error. Thus a copy can lose the vendor attestations and still pass.

## Context

* Before the wiki adoption, `.ai/PRD.md` listed this open item: "The GHCR OCI-referrers round trip decides the cosign pin." `.ai/PRD.md` is now a pointer to the wiki, and the open items are in the [Issues overview](/issues/issues-overview--01a1837da5b0.md). `SETUP-ENVIRONMENTS.md` section 1 tells the operator to run a spike that copies nexus3 to GHCR and lists its referrers.
* The checklist in `SETUP-ENVIRONMENTS.md` has the box "Referrers spike passed; `tools.lock` cosign pin confirmed". The box is not checked, and no file records the result of the spike.
* The cosign part of the item is decided. `tools.lock` pins cosign v2.6.1. `SETUP-ENVIRONMENTS.md` section 7 gives a second reason for v2: cosign v3 fails against the DHI simplesigning payloads. PR #13 (2026-09-15) installs cosign from `tools.lock`.
* `scripts/mirror-leg.sh` copies with `--referrers` and `--digest-tags`, so the copy works with or without the GHCR referrers API.
* `scripts/mirror-leg.sh` asserts the referrer after the copy only for the trust class `notation` (mssql). It does not assert the DHI referrers.
* `scripts/release-leg.sh` copies referrers again at promotion. It does not assert that they arrived.

## Acceptance criteria

- [ ] A check after the copy fails when the DHI signature or attestation referrers are not on the GHCR copy.
- [ ] Break the check on purpose and confirm that it fails.
- [ ] The [Mirror track](/architecture/mirror-track--01a18382f29c.md) concept, [ADR-005: Pin cosign to v2.6.1](/decisions/adr-005-pin-cosign-to-v2-6-1--01a18382f4c6.md) and the `SETUP-ENVIRONMENTS.md` checklist show the result.

## Related

* [Nobody has measured whether Docker OIDC covers registry.scout.docker.com](/issues/nobody-has-measured-whether-docker-oidc-covers-registry-scout-docker-com--01a1838a159a.md)
* [The four DHI digests and attestationRepo were placeholders](/issues/the-four-dhi-digests-and-attestationrepo-were-placeholders--01a1838a1552.md)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [postgres](/images/postgres--01a183832d06.md)
* [traefik](/images/traefik--01a183832cbc.md)
* [SETUP-ENVIRONMENTS.md and exceptions.yaml have stale setup text](/issues/setup-environments-md-and-exceptions-yaml-have-stale-setup-text--01a18395b5a2.md)
