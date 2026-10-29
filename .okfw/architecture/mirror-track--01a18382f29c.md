---
id: "01a18382-f29c-7bdb-a718-df9722c9910a"
title: "Mirror track"
type: "component"
tags:
  - "architecture"
  - "mirror"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "How the mirror track copies a vendor image by its index digest, keeps all referrers, and never rebuilds it."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/manifest-platforms.sh"
    title: "manifest-platforms.sh"
---

# Mirror track

The mirror track copies a vendor image by its digest and keeps its signatures and attestations. It never rebuilds the image. The mirror track has five images: [traefik](/images/traefik--01a183832cbc.md), [postgres](/images/postgres--01a183832d06.md), [nexus3](/images/nexus3--01a183832d26.md), [mssql](/images/mssql--01a183832d44.md) and [whoami](/images/whoami--01a183832d61.md).

## Why we do not rebuild

We get these images as the vendor built them. Docker Hardened Images (DHI) also come with attestations. A rebuild destroys the vendor signature. For DHI, a rebuild also destroys the claim of zero known CVEs. Thus we copy the image content-addressed and keep the OCI referrers. Then we add our own scan, signatures and policy gate.

## Copy the index, never a child manifest

DHI signs the index. If you divide an index into per-architecture manifests and assemble it again, you get a digest that the vendor never signed. Then all referrers become orphans.

* The PDP rules `INDEX_PLATFORM_DRIFT` and `PLATFORM_SET_MISMATCH` find an architecture that the copy dropped.
* An upstream with a single manifest (mssql) has no index. The manifest digest is then the claim.
* For a single manifest, `scripts/manifest-platforms.sh` gets the one platform from the config blob. `PLATFORM_SET_MISMATCH` still compares it with `versions.json`.
* If the platform set is empty, `scripts/manifest-platforms.sh` exits non-zero. It never gives an empty set.

## Copy both referrer mechanisms

Each `regctl image copy` uses both `--referrers` and `--digest-tags`:

* `--referrers` copies the OCI 1.1 referrers.
* `--digest-tags` copies the legacy `sha256-<digest>.sig` and `.att` tags that cosign v2 writes.

With both flags, the mirror is correct for each cosign generation that signed an upstream image. It is also correct if GHCR does not implement the `/referrers` API.

## Remove `unknown/unknown` entries before the scan

An upstream index can hold BuildKit attestation manifests as extra entries, with the platform `unknown/unknown`. On 2026-08-18, the indexes of nexus3 3.90.1 and nexus3 3.90.5 both had `unknown/unknown` entries, at different sizes. If syft gets one of these entries, it fails with a confusing error. The shape of attestations changes between patch releases of one upstream. Thus do not assume a shape.

## Promote with regctl, not with `cosign copy`

`cosign copy` knows only the legacy cosign tags. It drops the DHI attestations, which are referrers, and gives no error. The mirror track exists to keep these attestations. Thus the release actor promotes with `regctl`.

## Related

* [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md): the five digest checks.
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md): how the mirror leg verifies the upstream signature.
* [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md): why a mirrored image gets no new manifest list.
* [ADR-006: Never pass --replace to cosign attest](/decisions/adr-006-never-pass-replace-to-cosign-attest--01a18382f4e6.md): why we ban `cosign attest --replace`.
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
