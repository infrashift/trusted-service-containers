# Dual provenance: what the binary cross-check does and does not prove

For every built image we record two hashes:

- **A** — the sha256 of the binary *we* compiled from the pinned source commit.
- **B** — the sha256 of the same binary extracted from the vendor's official
  image, pinned by per-platform digest.

Both go into `crosscheck.json`, into the signed
`https://infrashift.io/attestation/binary-crosscheck/v1` attestation, into the
SLSA predicate's `runDetails.byproducts`, and into the PR comment table.

## It is not a gate

A mismatch **does not fail the build** and must never be made to. Do not add it
to `violations` in `policies.rego`.

What the policy *does* gate is that the comparison was **performed**
(`DUAL_PROVENANCE_NOT_RECORDED`), that its fields are **well-formed**
(`DUAL_PROVENANCE_MALFORMED`), and that it compared against the **pinned**
reference (`DUAL_PROVENANCE_REFERENCE_UNPINNED`). The outcome never affects the
decision.

That distinction has already earned its keep: an early version of
`binary-crosscheck.sh` used `buildah from --pull=always`, which fails for an
image in local storage. It printed two empty strings and exited 0, and the
caller compared `"" == ""` and recorded a **MATCH**. The script now asserts both
hashes match `^[0-9a-f]{64}$` before emitting them, and `build-leg.sh` validates
them again before comparing.

## What we measured

Against `nats-server` v2.14.5 on 2026-08-18, we tried hard to reproduce the
vendor's binary and **did not succeed**, despite matching every build input
visible to `go version -m`:

| Input | Ours | Official |
|---|---|---|
| Go toolchain | go1.26.5 | go1.26.5 |
| Dependency set | identical (10 deps, identical hashes) | — |
| `-trimpath` | true | true |
| `CGO_ENABLED` / `GOARCH` / `GOOS` / `GOAMD64` | 0 / amd64 / linux / v1 | identical |
| `DefaultGODEBUG` | identical | — |
| `mod` | `v2.14.5` | `v2.14.5` |
| `vcs.revision` / `vcs.time` / `vcs.modified` | identical, `modified=false` | — |
| Embedded short commit | `d3bc04533` (9 chars) | `d3bc04533` |
| **sha256** | `f2b1d11e…` | `e1a2f9ba…` |

Getting that far required fixing three real defects, each found only by
actually running the comparison:

1. **The short commit was 7 characters, not 9.** goreleaser stamps
   `{{.ShortCommit}}`, whose length is git's *dynamic* abbreviation for the full
   repository. We clone `--depth 1`, where git abbreviates to the 7-char
   minimum, so the correct value cannot be derived at build time — it is pinned
   as `sources.<key>.shortCommit` in `versions.json`, and `Ops.mk` asserts it is
   a prefix of the full commit.
2. **`fetch-source.sh` wrote its metadata inside the checkout**, leaving
   untracked files that made Go stamp `vcs.modified=true`. Metadata now goes to
   `src/.meta/`.
3. **`fetch-source.sh` deleted `.git`**, which cost the module version
   (`(devel)` instead of `v2.14.5`) and all `vcs.*` provenance. It is now kept:
   the pseudo-version problem that motivated deleting it is solved by fetching
   the *tag*, not by discarding provenance.

Whatever difference remains is not visible in `go version -m`. **NATS is
therefore recorded as `best-effort`, not `flag-matched`.** If someone identifies
the residual input, raise the tier back.

## So what is it worth?

- **A match** would be meaningful: an independent builder, from the published
  source, producing bit-identical output. We do not currently achieve it for any
  service.
- **A mismatch proves nothing on its own.** It is the expected result.
- **A *change* in the relationship is the real signal.** If a leg has matched
  stably and then stops, or if the hashes shift without a source change, that is
  worth investigating. Treat the recorded hashes as a change-detector over time.
- It is also the only independent read we have on upstreams whose signatures we
  cannot verify. `cosign download signature oryd/kratos:v26.2.0` returns
  `Cert: false, Chain: false` — a keyed signature whose public key Ory does not
  publish. Recording these hashes now means that if a vendor ever starts
  publishing verifiable signatures, we already hold the historical series.

## The stronger anchor, where it exists

NATS has one the others do not: `nats-docker` does not compile the binary, it
downloads the GitHub release tarball and verifies a sha256 **hardcoded in its
Dockerfile**. That value is published in two independent places, and we
confirmed on 2026-08-18 that the tarball hash matches and that the binary inside
the official image is byte-identical to the released tarball. That is a real
supply-chain check, and it is worth more than the from-source comparison.

## Rule

If anyone proposes promoting the cross-check to a gate, point them here first.
Gating on it requires reproducible builds. We measured. We do not have them.
