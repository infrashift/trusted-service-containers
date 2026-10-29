---
id: "01a18382-f3b7-7bd6-89ce-f755dd5d4f0e"
title: "Dual signing at release"
type: "component"
tags:
  - "architecture"
  - "promotion"
  - "signing"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The release actor signs twice: a keyed signature with no transparency log entry, then a keyless signature with one."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-leg.sh"
---

# Dual signing at release

The release actor signs each promoted image twice. The first signature is keyed and private. The second signature is keyless and public.

## The two passes

1. **Keyed, with `--tlog-upload=false`.** This is the sovereign signature. It tells a public log nothing about the release cadence.
2. **Keyless, with the transparency log on.** Then a third party can confirm independently that the release occurred.

To verify our review verdict on a promoted image, use the review key:

```bash
cosign verify-attestation \
  --key .github/pdp/public-keys/review.pub \
  --type https://infrashift.io/attestation/review/v1 \
  --insecure-ignore-tlog \
  ghcr.io/infrashift/trusted-service-containers/trusted/traefik:3-debian13
```

For a mirrored DHI image, the vendor attestations come with the copy. `regctl artifact list` on the promoted reference shows them.

## Related

* [Promotion](/architecture/promotion--01a18382f371.md)
* [The three actors](/architecture/the-three-actors--01a18382f33a.md)
* [ADR-005: Pin cosign to v2.6.1](/decisions/adr-005-pin-cosign-to-v2-6-1--01a18382f4c6.md): the cosign version.
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
