---
id: "01a18382-f4e6-74a5-9715-ead08998b4d1"
title: "ADR-006: Never pass --replace to cosign attest"
type: "decision"
tags:
  - "decision"
  - "cosign"
  - "attestation"
created: "2026-10-28T12:16:00-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "ADR-006 bans the --replace flag on cosign attest, because it deletes vendor attestations and overwrites the SBOM of the other architecture."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/lint-workflows.sh"
x:
  adr: 6
---

# ADR-006: Never pass --replace to cosign attest

ADR-006 bans the flag `--replace` on `cosign attest`. `scripts/lint-workflows.sh` fails if the flag appears.

**Status:** Accepted, 2026-08-18.

## Context

The reference repository used `cosign attest --replace` safely, because it built all its images. In this repository, the mirror track keeps vendor attestations. Also, one image has an SBOM for each architecture.

## Decision

Never pass `--replace` to `cosign attest`. Check 9 of `scripts/lint-workflows.sh` searches each `cosign attest` line in `scripts/` and `.github/workflows/` for the flag. If it finds the flag, the lint fails.

## Consequences

* `--replace` would delete the vendor attestations. The mirror track exists to keep them.
* `--replace` would overwrite the amd64 SBOM when the pipeline writes the arm64 SBOM.
* Reruns add attestations and do not replace them. Thus `scripts/release-leg.sh` takes the newest review verdict by `evaluatedAt`. See [Promotion](/architecture/promotion--01a18382f371.md).

## Related

* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Promotion](/architecture/promotion--01a18382f371.md)
* [ADR-005: Pin cosign to v2.6.1](/decisions/adr-005-pin-cosign-to-v2-6-1--01a18382f4c6.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
