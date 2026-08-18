# Trusted Service Containers — architecture

Authoritative source of truth for why this repository is shaped the way it is.
Sibling to `infrashift/trusted-base-images`, which builds the UBI bases.

## Mission

Publish service containers whose provenance can be independently verified by
someone who does not trust us.

## The split that drives everything

Two kinds of image, two integrity models.

**Mirror track** (traefik, postgres, nexus3). These arrive already hardened and
already attested. Rebuilding would destroy the vendor's signature and, for DHI,
their zero-known-CVE claim. So we copy content-addressed, preserving OCI
referrers, and layer our own scan, signing and policy gate on top.

**Build track** (Ory ×4, NATS, Dapr ×3). No official UBI variant exists — that
was verified, not assumed. All are static `CGO_ENABLED=0` Go binaries, so we
build from a pinned source **commit** onto our own `ubi9-micro`.

## Core principles

1. **`versions.json` is sovereign.** No digest lives anywhere else. Enforced by
   `scripts/lint-containerfiles.sh`.
2. **The digest is the claim.** For mirrored images we cannot add a label
   without changing the digest, so the proof is content-addressed rather than
   asserted — checked five times, by three actors, at three stages. A label is
   something we assert; a digest is a fact anyone can re-derive.
3. **Fail closed, and prove it.** Rego's `> 0` against a missing value is
   *undefined*, i.e. silently non-violating. Every numeric field is guarded,
   every enum is closed, every equality uses distinct sentinels so "both absent"
   denies. 74 tests, 85% coverage floor.
4. **Trust class drives signature verification only**, never CVE thresholds.
5. **One CVE gate for every image.** The only per-image escape is a dated,
   justified, reviewed exception — capped at 90 days and evaluated against a
   caller-supplied timestamp so decisions replay identically.
6. **Key isolation is the `environment:` binding.** Three actors, three keys,
   one secret name. `Review-Actor` has Required Reviewers, so a Review signature
   *is* proof a human approved.
7. **Never rebuild during promotion.** The promoted image is byte-identical to
   what was reviewed, asserted again at release.

## Actors

| actor | environment | does |
|---|---|---|
| Build | `Build-Actor` | mirror or build, scan, produce signed evidence |
| Review | `Review-Actor` | **independently re-derive** the facts, evaluate policy, sign a verdict |
| Release | `Release-Actor` | verify the signed verdict, promote, dual-sign |

The review actor deliberately does not trust the build actor: it re-resolves
digests live from GHCR and re-reads trust class from the checked-out
`versions.json`, never from the evidence bundle. That is what makes downgrading
an image's verification require a CODEOWNERS-reviewed commit rather than a
workflow edit.

## Layout

```
versions.json              sovereign source of truth
schemas/                   JSON Schema for the above
Containerfiles/            build track only
rootfs/                    baked-in service config
.github/pdp/               the ONE policy, its tests, exceptions, public keys
.github/workflows/         seven workflows
scripts/                   all pipeline logic; workflows stay thin
docs/build-track/          measurements and reasoning
.ai/skills/                rule cards
```

## Decisions worth recording

- **`enforcement: "observe"`** lets a new upstream be onboarded and triaged
  without red-lighting `main`. It still publishes every violation and still
  routes to `quarantine`; it is not a route into `trusted/`.
- **No `:latest`.** Meaningless across eleven services with runtime and dev
  variants, and it invites pulling a `-dev` image into production.
- **Quarantine is a documented state.** Fully evidenced, immutably tagged, and
  never given the clean upstream-shaped tag.
- **Dual provenance is an observation, never a gate.** We measured: Go builds
  are not reproducible here. See `docs/build-track/dual-provenance.md`.
- **cosign pinned to v2.6.1** to stay interoperable with the sibling repo. v3
  changes the on-registry attestation layout; migrate both together.

## Inherited defects we deliberately did not repeat

The reference repo (`trusted-base-oci-images`) is the model for this design, and
these are the places it went wrong. Each has a mechanical guard here.

| defect there | guard here |
|---|---|
| 0-byte `.gitleaks.toml` — zero rules, exits 0, while the pipeline attested `gitleaks_passed: true` | real config, CI assertion, and the policy reads *measured* config bytes |
| six orphaned `.rego` files contradicting the live one | `check-no-orphan-rego.sh` |
| `human.pub` required by two scripts, never created | no human key; Required Reviewers *is* the gate |
| paths filter drifted from the gate's regex | `lint-workflows.sh` |
| live private keys in the working tree | `.gitignore`, gitleaks rules, `/dev/shm` keygen |
| live OIDC token published in a public attestation | `ATTESTATION_PREDICATE_LEAK` |
| tools installed from unpinned `main` into the signing job | `tools.lock` |
| cleanup read a distro key as a PR number | explicit `pullRequest` field |
| skill cards citing four files that never existed | `lint-skills.sh` |

## Open items

- The GHCR OCI-referrers round trip decides the cosign pin. See
  `SETUP-ENVIRONMENTS.md` §1.
- Four DHI digests and `attestationRepo` need an authenticated session.
- Whether Docker OIDC covers `registry.scout.docker.com`.
- nexus3's day-one CVE count is unknown; it will very likely quarantine.
