---
id: "01a18382-f417-7729-b7d7-3526e99e0810"
title: "Pinned upstream keyrings and identities"
type: "component"
tags:
  - "architecture"
  - "upstream-trust"
  - "keyring"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "Why we verify against a committed copy of each upstream keyring, and why the notation class pins a signing identity as well as a root."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/mirror-leg.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/tree/main/.github/pdp/keyring"
    title: "Committed upstream keyrings"
---

# Pinned upstream keyrings and identities

We verify an upstream signature against a committed copy of the vendor keyring, not against the live one. A change of the live keyring becomes a PR that a human reviews.

## The keyring is pinned, not fetched

`scripts/mirror-leg.sh` does these steps for a `dhi` image:

1. Fetch the live Docker keyring.
2. Compare it with the committed copy, `.github/pdp/keyring/dhi-latest.pub`.
3. Verify the signature against the committed copy.

A rotation of the live keyring gives `DHI_KEYRING_DRIFT`. The rotation becomes a reviewable PR, not a silent transfer of trust. A new TOFU at each run is not a trust model.

## `notation` pins a root and an identity

A Notary Project signature chains to a CA root. The Microsoft supply-chain root signs many products, not only SQL Server. If we trusted the root alone, we would accept the signature of any Microsoft product on any digest.

Thus `versions.json` also holds `notation.trustedIdentity`: the exact `x509.subject` of the signing leaf. The repository gate refuses a `notation` entry without it (`VERSIONS_NOTATION_IDENTITY_MISSING`).

`scripts/mirror-leg.sh` verifies a `notation` image with these steps:

1. Make a temporary notation home that holds only the committed root.
2. Add a trust policy that applies to the one upstream repository only.
3. Verify at the level `strict`.
4. Fetch the live root from `notation.rootUrl`.
5. Compare the live root with the committed root. A difference gives `NOTATION_ROOT_DRIFT`.

`tools.lock` pins the `notation` tool. The installer checks the published checksum of the tool.

## `sigstore` pins a trusted root, an issuer and an identity

A keyless Sigstore signature has no vendor key. A Fulcio certificate binds the signature to the OIDC identity of the signing workflow, and Rekor records it. The Sigstore trusted root holds the Fulcio CAs and the log keys. Fulcio certifies every workflow on GitHub, so the root alone trusts too much.

Thus `versions.json` also holds the `sigstore` block:

* `certificateOidcIssuer`: one issuer from a closed set in the policy. Today the set holds only GitHub Actions.
* `certificateIdentityRegexp`: an anchored regex for one repository and one workflow file at a release tag. The repository gate refuses a wildcard span, an alternation, a group and a branch (`VERSIONS_SIGSTORE_IDENTITY_INVALID`).

`scripts/mirror-leg.sh` verifies a `sigstore` image with these steps:

1. Read the sha256 of the live trusted root from the TUF metadata of the Sigstore public-good repository.
2. Compare it with the committed root. A difference gives `SIGSTORE_ROOT_DRIFT`.
3. Verify the signature with `cosign verify --new-bundle-format --trusted-root` against the committed root. `TUF_ROOT` is an empty directory, so cosign cannot use another root. Cosign v2.6.1 needs `--new-bundle-format` to read the bundle referrer.

`scripts/review-leg.sh` verifies the copy on GHCR again, from the checked-out `versions.json` and the committed root.

To update the root after a rotation, get it with a TUF client, for example `cosign initialize`. Compare its sha256 with the TUF metadata. Then change the root and its `.sha256` sidecar in one PR.

## Related

* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [mssql](/images/mssql--01a183832d44.md): the only `notation` image.
* [traefik](/images/traefik--01a183832cbc.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
