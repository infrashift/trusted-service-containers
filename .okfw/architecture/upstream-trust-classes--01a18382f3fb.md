---
id: "01a18382-f3fb-70ec-92c8-374d34672b4d"
title: "Upstream trust classes"
type: "component"
tags:
  - "architecture"
  - "upstream-trust"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The four trust classes, the key that each class verifies the upstream signature against, and the three signature states that the policy accepts."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
    title: "versions.json (upstreamTrust)"
---

# Upstream trust classes

The trust class of an image decides only how we verify its upstream signature. It never changes a CVE threshold.

## The four classes

The field `upstreamTrust` in `versions.json` sets the trust class.

| Class | Verified against | Used by |
|---|---|---|
| `dhi` | `.github/pdp/keyring/dhi-latest.pub`, a TOFU-pinned copy of the Docker keyring | [traefik](/images/traefik--01a183832cbc.md), [postgres](/images/postgres--01a183832d06.md) |
| `internal` | `.github/pdp/public-keys/upstream/trusted-base-images-release.pub`, the release key of the sibling repository | our `ubi9-micro` base, and thus each built image |
| `notation` | `.github/pdp/keyring/microsoft-supply-chain-rsa-root-ca-2022.crt` (TOFU-pinned), plus the leaf subject in `notation.trustedIdentity` | [mssql](/images/mssql--01a183832d44.md) |
| `none` | Nothing. The evidence records "not applicable". | [nexus3](/images/nexus3--01a183832d26.md), [whoami](/images/whoami--01a183832d61.md), and the vendor images of the binary cross-check |

## Signature verification only

WARNING: Do not use the trust class in a CVE rule.

1. Before you merge a change to the policy, search for `trust_class` in `.github/pdp/policies.rego`.
2. Make sure that no CVE rule uses it.

One CVE gate applies to each image, for each trust class and each track.

## Three states, never two

The signature check has three results: `verified`, `failed` and `not-applicable`. Do not reduce them to a boolean.

* `failed` is fatal for each class, also for `none`. A class can decline to verify. It cannot verify and fail.
* The policy accepts `not-applicable` only where the class does not require verification. On a `dhi` image, `not-applicable` gives `UPSTREAM_SIGNATURE_REQUIRED`.
* A signature that the pipeline verified against the wrong key is not verified. The evidence records `verified_with`. If `verified_with` is not the keyring that the class requires, `UPSTREAM_KEYRING_MISMATCH` denies.

## `none` means that we checked and could not verify

`none` does not mean "we did not look". On 2026-08-18, the command `cosign download signature oryd/kratos:v26.2.0` returned a `Base64Signature`, but `Cert: false, Chain: false`. That is a keyed signature, and Ory does not publish the public key. "We cannot verify it" is not the same as "unsigned". When we record this explicitly, a later reader cannot read "pulled by digest" as "verified".

## Related

* [Pinned upstream keyrings and identities](/architecture/pinned-upstream-keyrings-and-identities--01a18382f417.md): the pinned keyrings and the notation identity.
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Mission and core principles](/architecture/mission-and-core-principles--01a18382f27f.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
