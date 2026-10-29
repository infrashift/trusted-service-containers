---
id: "01a18382-f4c6-747b-a32d-7e7a5f2b155f"
title: "ADR-005: Pin cosign to v2.6.1"
type: "decision"
tags:
  - "decision"
  - "cosign"
  - "tools"
created: "2026-10-28T12:16:00-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "ADR-005 pins cosign to v2.6.1 so that our attestation layout matches the sibling repository; both repositories must move to v3 together."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/tools.lock"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/SETUP-ENVIRONMENTS.md"
    title: "SETUP-ENVIRONMENTS.md section 0 and 1"
x:
  adr: 5
---

# ADR-005: Pin cosign to v2.6.1

ADR-005 pins cosign to v2.6.1, so that our attestations use the same on-registry layout as the sibling repository `infrashift/trusted-base-images`.

**Status:** Accepted, 2026-08-18.

## Context

cosign v3 sets `--new-bundle-format=true` by default and writes attestations as OCI referrers. cosign v2 writes the legacy `sha256-<digest>.att` tags. The sibling repository uses v2. Verification of the `internal` trust class reads the attestation layout of the sibling repository.

## Decision

Pin cosign to v2.6.1 in `tools.lock`.

* `scripts/install-tools.sh` installs cosign itself. It refuses a binary whose sha256 is not the value in `tools.lock`. There is no `sigstore/cosign-installer` step.
* The checksums come from the cosign release file `cosign_checksums.txt`. We verified its keyless signature before we used it. The signer identity is the sigstore release service account, through Google. It is not a GitHub Actions workflow identity.

WARNING: Do not move one repository to cosign v3 alone. Move this repository and the sibling repository together, or do not move them.

To change the pin, do these steps:

1. Verify the keyless signature of `cosign_checksums.txt` again, as the comment in `tools.lock` shows.
2. Change the version and the two checksums together.

## Consequences

* The `internal` verification of our base images continues to work.
* Every `regctl image copy` uses `--referrers` and `--digest-tags`, so the mirror works with both layouts.
* The GHCR round-trip test for OCI referrers decides the pin. Section 1 of `SETUP-ENVIRONMENTS.md` describes that test. Examine the pin again after the test.

## Related

* [Dual signing at release](/architecture/dual-signing-at-release--01a18382f3b7.md)
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [ADR-006: Never pass --replace to cosign attest](/decisions/adr-006-never-pass-replace-to-cosign-attest--01a18382f4e6.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md): the tool pins.
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
