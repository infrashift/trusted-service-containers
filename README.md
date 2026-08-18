# Trusted Service Containers

Service containers for the Infrashift platform, published to GHCR with a
verifiable chain of custody: pinned upstream → scanned → policy-gated →
signed by three separate actors → promoted.

Sibling to [`infrashift/trusted-base-images`](https://github.com/infrashift/trusted-base-images),
which builds the UBI base images this repo builds on.

---

## Two tracks, one pipeline

The images divide into two kinds, and that split drives the whole design.

### Mirror track — we do not rebuild

`traefik`, `postgres`, `nexus3` arrive already hardened and already attested.
Rebuilding them would destroy the vendor's signature and, for Docker Hardened
Images, their zero-known-CVE claim. So we copy them **content-addressed**,
preserving OCI referrers, and layer our own scan, signing and policy gate on top.

The load-bearing property:

```console
$ regctl manifest head ghcr.io/infrashift/trusted-service-containers/trusted/traefik:3-debian13
sha256:…
$ regctl manifest head dhi.io/traefik:3-debian13
sha256:…   # identical
```

**The digest is the claim.** The reference repo stamps an
`io.infrashift.image.upstream.digest` label because it builds its images; we
cannot add a label without changing the digest, and the replacement is stronger
— a label is something we assert, a digest is a fact anyone can re-derive with
no trust in us at all. It is checked five times, by three different actors, at
three stages.

### Build track — no official UBI variant exists

The Ory services, NATS and Dapr publish only distroless, Alpine and Windows
variants. All are static `CGO_ENABLED=0` Go binaries, so we build them from a
pinned source **commit** onto our own `ubi9-micro`.

| Image | Upstream | Track |
|---|---|---|
| `kratos` `hydra` `keto` `oathkeeper` | `github.com/ory/*` | `v26.x.y`, lockstep |
| `nats` | `github.com/nats-io/nats-server` | `v2.14.z` |
| `daprd` `dapr-placement` `dapr-scheduler` | `github.com/dapr/dapr` | `v1.18.z`, lockstep |

---

## Consuming the images

```
ghcr.io/infrashift/trusted-service-containers/trusted/<service>:<tag>
```

Mirror-track tags **are** the upstream tags, so migration is a one-line change:

```diff
- dhi.io/traefik:3-debian13
+ ghcr.io/infrashift/trusted-service-containers/trusted/traefik:3-debian13
```

Alongside the rolling tag, each release also publishes immutable
`<tag>-<shortsha>` and `<tag>-<YYYYMMDD>` variants.

**There is no `:latest`.** Across eleven services with runtime and dev
variants it has no defensible meaning, and it invites pulling a `-dev` image —
root, with a shell and a package manager — into production.

### Verify what you pulled

```bash
# Our review verdict, signed by the Review actor
cosign verify-attestation \
  --key .github/pdp/public-keys/review.pub \
  --type https://infrashift.io/attestation/review/v1 \
  --insecure-ignore-tlog \
  ghcr.io/infrashift/trusted-service-containers/trusted/traefik:3-debian13

# For mirrored DHI images, the vendor's own attestations rode along
regctl artifact list ghcr.io/infrashift/trusted-service-containers/trusted/traefik:3-debian13
```

### `quarantine/` is a documented state, not a bin

An image that fails policy is still mirrored, scanned, signed, and carries a
signed verdict recording exactly why it failed. What is withheld is the clean
upstream-shaped tag under `trusted/`. Quarantined images get **only** an
immutable `-<shortsha>` tag, so a registry-mirror typo cannot silently resolve
to one — using it requires naming the exact commit.

---

## How a change flows

```
PR ──► pr-gate.yml      repo gate: secrets, schema, policy tests, lints
       build.yml        mirror legs + build legs → signed evidence
       review.yml       re-verify independently, evaluate policy, sign a verdict
merge► release.yml      promote to trusted/ or quarantine/, dual-sign
       cleanup-dev.yml  remove this PR's development images
```

Three GitHub Environments hold three different cosign keys under the **same**
secret name. Isolation comes entirely from the `environment:` binding, and
`Review-Actor` has Required Reviewers — so a Review signature *is* proof a human
approved.

Two scheduled workflows watch for drift: `drift-base.yml` (our UBI base) and
`drift-upstream.yml` (every pinned upstream). Both propose changes **inside**
each entry's declared track and never widen one.

---

## Policy

One file, one package: `.github/pdp/policies.rego` (`tsc.pdp`), with 74 tests
and a fail-closed contract documented at the top.

**One CVE gate for every image**, regardless of trust class or track: Criticals
block unconditionally; Highs block when upstream has published a fix (a re-pin
clears them); unfixable Highs are recorded but never block, because no action we
control clears them and blocking would gate every image on a vendor's backport
schedule.

The only per-image escape is a dated, justified entry in
`.github/pdp/exceptions.yaml` — capped at 90 days, evaluated against a caller-
supplied `evaluated_at` so a decision replays identically a year later. Waived
findings are reported in a distinct `waived` state, never silently dropped.

`upstream_trust` drives **signature verification only**, never CVE thresholds:

| class | meaning |
|---|---|
| `dhi` | Docker Hardened Images; verified against a TOFU-pinned copy of Docker's keyring |
| `internal` | our own base images, verified against the sibling repo's release key |
| `none` | unverifiable. `cosign download signature oryd/kratos:v26.2.0` returns `Cert: false, Chain: false` — a keyed signature whose public key the vendor does not publish |

---

## Local development

```bash
make -f Ops.mk help
make -f Ops.mk validate      # schema, gitleaks config, policy tests, all lints
make -f Ops.mk verify-pins   # re-resolve every pin against the live registries
```

`versions.json` is the sovereign source of truth; no digest is hardcoded
anywhere else. It sits behind `@infrashift/security-admins` because a `track`
widening is a one-character-class edit, indistinguishable at a glance from a
routine digest bump, that converts every future release from a reviewed decision
into an automated one.

## Further reading

- [`SETUP-ENVIRONMENTS.md`](SETUP-ENVIRONMENTS.md) — one-time setup runbook
- [`docs/build-track/dual-provenance.md`](docs/build-track/dual-provenance.md) —
  what the binary cross-check does and does not prove, with measurements
- [`.ai/PRD.md`](.ai/PRD.md) — architecture and the reasoning behind it
