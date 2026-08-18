# Mirror integrity

The mirror track never rebuilds. Rebuilding would destroy the vendor's
signature and, for DHI, the zero-known-CVE claim.

## The digest is the claim

We cannot add a label without changing the digest, so the equivalent proof is
content-addressed instead of asserted — and checked five times by three actors:

1. `versions.json` pins the upstream **index** digest (CODEOWNERS-protected).
2. `scripts/mirror-leg.sh` copies **by digest**, never by tag.
3. It then asserts the destination resolves to the same digest.
4. `scripts/review-leg.sh` re-resolves **live from GHCR** and compares against
   the repo's `versions.json` — not against the evidence bundle.
5. `scripts/release-leg.sh` asserts it a third time on the promoted reference.

## Copy the index, never a child manifest

DHI signs the index. Splitting per-arch and reassembling produces a digest the
vendor never signed, and orphans every referrer. `INDEX_PLATFORM_DRIFT` and
`PLATFORM_SET_MISMATCH` catch a dropped architecture.

## Both referrer mechanisms, always

Every `regctl image copy` passes `--referrers` **and** `--digest-tags`.
The first carries OCI 1.1 referrers; the second carries the legacy
`sha256-<digest>.sig`/`.att` tags cosign v2 writes. Both, so the mirror is
correct regardless of which cosign generation produced any given upstream
signature and regardless of whether GHCR implements `/referrers`.

## Filter `unknown/unknown` before scanning

Upstream indexes carry BuildKit attestation manifests as extra entries — both
nexus3 3.90.1 and 3.90.5 do, at different sizes. Handing one to syft fails
confusingly. Attestation shape varies between patch releases of the same
upstream, so assume nothing.

## Promote with regctl, not `cosign copy`

`cosign copy` understands only cosign's own legacy tags and would silently drop
DHI's referrer-based attestations — losing the one thing the mirror exists to
preserve.
