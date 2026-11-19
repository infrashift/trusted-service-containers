---
id: "01a1f161-6a04-7545-8162-e6b163ce10a7"
title: "ADR-012: A keyless Sigstore signature gets the trust class sigstore"
type: "decision"
tags:
  - "decision"
  - "sigstore"
  - "trust-class"
  - "cosign"
created: "2026-11-18T19:17:35-06:00"
timestamp: "2026-11-18T19:17:35-06:00"
description: "The class sigstore verifies a keyless signature offline against a TUF-pinned Sigstore trusted root, with a closed issuer set and a narrow identity regex; cosign v2.6.1 needs --new-bundle-format."
---

# ADR-012: A keyless Sigstore signature gets the trust class sigstore

ADR-012 adds the trust class `sigstore` for an upstream image with a keyless Sigstore signature.

**Status:** Accepted, 2026-11-18.

## Context

The OpenBao project publishes `ghcr.io/openbao/openbao-ubi`. Its release workflow signs each image keylessly. A Fulcio certificate binds the signature to the workflow identity, and Rekor records it. The signature is an OCI referrer in the Sigstore bundle format.

The four classes before this ADR do not fit:

* `dhi` and `internal` verify with a public key. A keyless signature has no key.
* `notation` verifies a Notary Project signature.
* `none` means that we checked and could not verify. We can verify this signature, so `none` would be false.

## Decision

Add the class `sigstore`. It applies to mirror entries only.

* The key material is the Sigstore public-good trusted root. We committed it as `.github/pdp/keyring/sigstore-public-good-trusted-root.json` with a `.sha256` sidecar. We got it with `cosign initialize`, which checks the TUF signatures. Its sha256 equalled the hash in the TUF targets metadata.
* The entry names the OIDC issuer and an anchored identity regex in a `sigstore` block. The issuer comes from a closed set in the policy, which holds only GitHub Actions today. The identity must name one repository and one workflow file at a release tag. The repository gate refuses a wildcard span, an alternation, a group and a branch.
* `scripts/mirror-leg.sh` verifies offline with `cosign verify --new-bundle-format --trusted-root` against the committed root. `TUF_ROOT` is an empty directory, so cosign cannot use another root.
* The build actor reads the sha256 of the live root from the TUF metadata. A difference gives `SIGSTORE_ROOT_DRIFT`.
* `scripts/review-leg.sh` verifies the GHCR copy again, from the checked-out `versions.json`.
* The class requires a signature. It does not require attestations.

## Cosign v2.6.1

[ADR-005](/decisions/adr-005-pin-cosign-to-v2-6-1--01a18382f4c6.md) keeps cosign at v2.6.1. We tested the pinned binary on 2026-11-18 against `openbao-ubi:2.7.2`:

* v2.6.1 reads a bundle referrer only with `--new-bundle-format`. Without the flag it finds no signature. `--trusted-root` also requires the flag.
* The flag changes what cosign reads. It does not change the layout that we write, so ADR-005 still holds.
* The pinned identity verified, with an empty TUF cache. Another tag, another workflow, a fork, another issuer, a root with no Fulcio CA and a root with no Rekor log each failed.

## Consequences

* A rotation of a Fulcio CA or a log key stops each `sigstore` leg until a reviewed PR updates the root.
* The review step on GHCR needs the signature referrer to survive the copy. `regctl image copy --referrers` copies it. The first OpenBao run proves this in CI.
* Each new issuer, for example GitLab, is a policy change with its own PR.

## Related

* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [Pinned upstream keyrings and identities](/architecture/pinned-upstream-keyrings-and-identities--01a18382f417.md)
* [ADR-005: Pin cosign to v2.6.1](/decisions/adr-005-pin-cosign-to-v2-6-1--01a18382f4c6.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
