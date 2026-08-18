# Upstream trust

`upstreamTrust` in `versions.json` drives **signature verification only**. It
never touches a CVE threshold. Grep for `trust_class` in
`.github/pdp/policies.rego` before merging any change and confirm it appears in
no CVE rule.

| class | verified against | used by |
|---|---|---|
| `dhi` | `.github/pdp/keyring/dhi-latest.pub` (TOFU-pinned) | traefik, postgres |
| `internal` | `.github/pdp/public-keys/upstream/trusted-base-images-release.pub` | our ubi9-micro base |
| `none` | nothing — records "not applicable" | nexus3, and the vendor images we cross-check against |

## Three states, never two

`verified` / `failed` / `not-applicable`. Do not collapse to a boolean.

- **`failed` is fatal for every class, including `none`.** A class may decline
  to verify; it may not verify and lose.
- **`not-applicable` is honoured only where the class does not require
  verification.** Claiming it on a `dhi` image is `UPSTREAM_SIGNATURE_REQUIRED`.
- **`verified` against the wrong key is not verified.** The evidence records
  `verified_with`, and `UPSTREAM_KEYRING_MISMATCH` denies if it is not the
  keyring the class mandates.

## The keyring is pinned, not fetched

`scripts/mirror-leg.sh` fetches Docker's live keyring, compares it to the
committed copy, and then **verifies against the committed copy**. A rotation
produces `DHI_KEYRING_DRIFT` — a reviewable PR rather than a silent trust
transfer. TOFU-every-time is not a trust model.

## `none` means we checked and could not verify

Not "we didn't look". `cosign download signature oryd/kratos:v26.2.0` returns
`Base64Signature` present but `Cert: false, Chain: false` — a keyed signature
whose public key Ory does not publish. Recording that explicitly is what stops
someone later reading "pulled by digest" as "verified".
