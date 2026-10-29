---
id: "01a18382-f371-7c93-a00b-dd841a65bb5d"
title: "Promotion"
type: "component"
tags:
  - "architecture"
  - "promotion"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "How the release actor reads the signed verdict and copies an image, byte-identical, from development/ to trusted/ or quarantine/."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-leg.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/workflows/release.yml"
    title: "release.yml"
---

# Promotion

Promotion copies a reviewed image from `development/` to `trusted/` or `quarantine/`. It never rebuilds, so the promoted image is byte-identical to the reviewed image.

## The verdict comes from a signed attestation

`scripts/release-leg.sh` does not read the verdict from a workflow artifact. A person who can run a job again can change an artifact.

1. The release leg reads the review verdict with `cosign verify-attestation` against `.github/pdp/public-keys/review.pub`.
2. It takes the newest verdict by `evaluatedAt`. Reruns add verdicts and do not replace them, because ADR-006 bans `--replace`. See [ADR-006: Never pass --replace to cosign attest](/decisions/adr-006-never-pass-replace-to-cosign-attest--01a18382f4e6.md).
3. It checks that the `commitSha` of the verdict is equal to the merged head commit. A verdict about a different commit is a verdict about different bits, even if it is the newest verdict.
4. It asserts the digest a third time on the promoted reference. See [The digest is the claim](/architecture/the-digest-is-the-claim--01a18382f2b9.md).

## Verdict and namespace are two values

The review leg signs two values:

* `verdict` is `PASS` or `FAIL`. It decides if the pipeline shows red.
* `namespace` is where the image goes: `trusted` or `quarantine`.

The PDP sets the namespace to `trusted` when the leg has no violations, in both enforcement modes. When the leg has violations, the namespace is `quarantine`.

The two values differ only in `observe` mode. An `observe` leg with violations gets `PASS`, but it goes to `quarantine/`. An `observe` leg with no violations goes to `trusted/`. `scripts/release-leg.sh` promotes to `trusted/` only when the verdict is `PASS` and the namespace is `trusted`. If the namespace is absent or unknown, the script fails closed. See [ADR-001: Observe enforcement mode](/decisions/adr-001-observe-enforcement-mode--01a18382f44e.md).

## Related

* [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md): the tags that promotion writes.
* [Dual signing at release](/architecture/dual-signing-at-release--01a18382f3b7.md): the two signatures at release.
* [Registry namespaces and cleanup](/architecture/registry-namespaces-and-cleanup--01a18382f3dd.md): the three namespaces.
* [ADR-003: Quarantine is a documented state](/decisions/adr-003-quarantine-is-a-documented-state--01a18382f486.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
