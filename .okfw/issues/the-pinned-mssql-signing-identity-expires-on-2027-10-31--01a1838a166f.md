---
id: "01a1838a-166f-7af7-b250-2c3bffe581dd"
title: "The pinned mssql signing identity expires on 2027-10-31"
type: "issue"
kind: "issue"
tags:
  - "issue"
  - "open"
  - "prd"
  - "mssql"
  - "signing"
created: "2026-10-28T12:23:47-05:00"
timestamp: "2026-10-28T12:24:33-05:00"
description: "The mssql Notary check pins the leaf subject of a certificate that expires on 2027-10-31; no check warns before a leaf change."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:33-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.ai/PRD.md"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
    title: "versions.json"
---

# The pinned mssql signing identity expires on 2027-10-31

## Problem

`versions.json` pins the mssql signing identity to a certificate that expires on 2027-10-31. The mirror verifies the Notary signature against the leaf subject `CN=Microsoft SCD Products RSA Signing`. When Microsoft replaces the leaf, the pinned identity can stop matching, and the mssql leg fails.

## Context

* Before the wiki adoption, `.ai/PRD.md` listed this open item: "The mssql Notary root is TOFU-pinned. `NOTATION_ROOT_DRIFT` will surface a rotation; the signing leaf expires 2027-10-31." `.ai/PRD.md` is now a pointer to the wiki, and the open items are in the [Issues overview](/issues/issues-overview--01a1837da5b0.md).
* On 2026-09-11, the root was taken from the Microsoft PKI endpoint and pinned by trust on first use. The root is valid to 2047-02-17. The root file is in `.github/pdp/keyring/`.
* The pin uses the leaf subject, because the root alone trusts every Microsoft product signature.
* `NOTATION_ROOT_DRIFT` reports a change of the root. No check reports a change of the leaf before it expires.

## Acceptance criteria

- [ ] Before 2027-10-31, a check of the live mssql signature confirms the pinned identity, or a reviewed change updates it.
- [ ] The note in `versions.json` records the date of the check.

## Related

* [The mssql image has 60 blocking findings and no triage](/issues/the-mssql-image-has-60-blocking-findings-and-no-triage--01a1838a1626.md)
* [No check asserts that DHI attestations survive the copy to GHCR](/issues/no-check-asserts-that-dhi-attestations-survive-the-copy-to-ghcr--01a1838a1514.md)
* [Supply-chain overview](/supply-chain/supply-chain-overview--01a1837da55d.md)
* [Issues overview](/issues/issues-overview--01a1837da5b0.md)
* [mssql](/images/mssql--01a183832d44.md)
