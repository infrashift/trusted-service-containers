---
id: "01a1dd22-47a6-7b88-8386-0ea6b48207e0"
title: "ADR-009: A package build installs signed RPMs at pinned NEVRAs"
type: "decision"
tags:
  - "decision"
  - "build"
  - "package"
  - "p-tsc-4"
created: "2026-11-14T20:56:13-06:00"
timestamp: "2026-11-14T20:56:13-06:00"
description: "Non-Go software that a vendor ships as signed RPMs is built as kind package: exact NEVRAs from one pinned repository and key, verified with rpm -q."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/.github/pdp/policies.rego"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/build-leg.sh"
    title: "scripts/build-leg.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/review-leg.sh"
    title: "scripts/review-leg.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/package-observe.sh"
    title: "scripts/package-observe.sh"
  - resource: "https://download.postgresql.org/pub/repos/yum/keys/README.txt"
    title: "PGDG RPM GPG keys"
x:
  adr: 9
  answers: "P-TSC-4 (HALO PLAN.md section 7), for package-based images"
---

# ADR-009: A package build installs signed RPMs at pinned NEVRAs


A build entry of kind `package` installs signed RPMs at exact NEVRAs from one pinned repository onto our base. The review actor proves that the image holds exactly those NEVRAs, signed by the pinned key.

**Status:** Proposed, 2026-11-14. It needs a review by `@infrashift/security-admins`, because it changes `.github/pdp/policies.rego`, `schemas/versions.schema.json` and `versions.json`.

## Context

The build track compiles static Go binaries only: `CGO_ENABLED=0`, a toolchain pin, and a binary cross-check against the vendor image, or a first-party declaration when we are the vendor. See [Build track](/architecture/build-track--01a18382f2d2.md) and [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md). HALO asks for an ADR on images that are not Go (P-TSC-4 in the HALO `PLAN.md`, section 7).

On 2026-11-14 the owner decided to build PostgreSQL 17 on UBI in this repository. The DHI postgres 17 legs had 144 blocking Debian findings that only Docker can clear. See [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md).

PostgreSQL is C. Its vendors publish signed binary packages for RHEL. A compile from source here would add a C toolchain, a second dependency set, and a binary that nobody else built. A signed vendor package needs none of that, but it needs a different proof.

## The package source

We checked UBI9 AppStream first, because its content is signed by Red Hat and is freely redistributable.

* On 2026-11-14 the `modules.yaml` of `ubi9/9/x86_64/appstream` listed maven, nginx, nodejs, php, redis and ruby. It had no `postgresql` stream.
* The only PostgreSQL packages in UBI9 AppStream were `postgresql` and `postgresql-private-libs`, version 13. The server package is not in UBI.
* aarch64 gave the same result.

Thus we use the official PGDG EL9 repository, `https://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-<arch>`.

* PGDG signs each architecture with a different key. x86_64 uses `PGDG-RPM-GPG-KEY-RHEL` (fingerprint `D4BF08AE67A0B4C7A1DBCCD240BCA2B408B40D20`). aarch64 uses `PGDG-RPM-GPG-KEY-AARCH64-RHEL` (fingerprint `B031F89FC983E98262906B6E177B343BB9738825`).
* We fetched both keys from `keyUrl` on 2026-11-14. Neither key is on `keyserver.ubuntu.com`, so the pin is trust on first use, as for the DHI keyring.
* Every pinned RPM and both `repomd.xml.asc` files verified against these keys on 2026-11-14.
* The keys are in `.github/pdp/keyring/` as `.asc` files with `.sha256` sidecars. `versions.json` pins each one by file sha256 and by fingerprint.

## Decision

A new image kind, `package`, joins `mirror` and `build`. A package entry has no `source`, `toolchain`, `crosscheck` or `build` block. It has a `base`, and a `packages` block that names a repository from the new top-level `packageRepos` map:

```json
"packages": {
  "repo": "pgdg17-el9",
  "version": "17.12",
  "track": "^17\\.[0-9]+-[0-9]+PGDG\\.rhel9(\\.[0-9]+)?$",
  "amd64": ["postgresql17-17.12-1PGDG.rhel9.8.x86_64", "..."],
  "arm64": ["postgresql17-17.12-1PGDG.rhel9.8.aarch64", "..."]
}
```

* `packageRepos.<repo>.<arch>` pins `baseurl`, `key`, `keyFingerprint` and `keySha256` for each architecture.
* Each architecture pins exact NEVRAs. PGDG can publish a different release on each architecture.
* `track` bounds the VERSION-RELEASE of every NEVRA. `version` is the release tag.
* The provenance mode is the package set: the base, the repository, the key and the NEVRAs. There is no binary cross-check, because there is no compile. The signed verdict records `provenanceMode: package`, next to `vendor-crosscheck` and `first-party` of ADR-008.

### The build actor

`scripts/build-leg.sh` reads the kind from `versions.json` and refuses any other kind. For a package entry it does these steps:

1. Refuse a key file whose sha256 or fingerprint differs from the pins, or that holds more than one primary key.
2. Build `Containerfiles/postgresql17.Containerfile`. The Containerfile upgrades the base from the UBI repositories first. Then it checks the key sha256, imports the key, and writes the repository file with `gpgcheck=1` and `repo_gpgcheck=1`.
3. Install the exact NEVRAs. Then run `rpm -q` on each NEVRA and check that its header signature names the pinned key ID.
4. Run `scripts/package-verify.sh` on the built image. It records `rpm -q` for each pin and the signer key ID of every installed package.
5. Sign `package-verification.json` and attach it as the attestation `https://infrashift.io/attestation/package-verification/v1`.

### The review actor

`scripts/review-leg.sh` re-derives each claim. It reads nothing material from the evidence that it can get elsewhere.

| Value | Where the review actor gets it |
|---|---|
| The pinned base, repository URL, key fingerprint, key sha256, version and NEVRAs | The checked-out `versions.json` |
| The kind | The checked-out `versions.json`. The matrix must agree. |
| The repository file (`baseurl`, `gpgcheck`, `repo_gpgcheck`) | The image on GHCR, with `regctl image get-file` |
| The key sha256 and fingerprint | The key file in the image on GHCR |
| The installed NEVRAs | The rpm database of the image on GHCR, with `syft` |
| The `rpm -q` result and the signer key IDs | The signed build evidence. The review cannot run `rpm`. |

### The policy

The leg rules apply when `input.track` is `package`. The base and label rules of the build track apply to both built tracks.

| Code | Denies when |
|---|---|
| `PACKAGE_PIN_MALFORMED` | The pins are not a non-empty NEVRA list with a 40-hex fingerprint, a key sha256, an https URL and a version. |
| `PACKAGE_EVIDENCE_MALFORMED` | The installed list, the verified list or the signature list is not a list of the correct shape. |
| `PACKAGE_REPO_MISMATCH` | The `baseurl` in the image differs from the pin. |
| `PACKAGE_GPGCHECK_DISABLED` | `gpgcheck` or `repo_gpgcheck` in the image is not `1`. |
| `PACKAGE_KEY_FINGERPRINT_MISMATCH` | The key in the image has another fingerprint. |
| `PACKAGE_KEY_SHA256_MISMATCH` | The key file in the image has another sha256. |
| `PACKAGE_NEVRA_NOT_INSTALLED` | A pinned NEVRA is not in the live rpm database. |
| `PACKAGE_NEVRA_NOT_VERIFIED` | The build did not record `rpm -q` finding a pinned NEVRA. |
| `PACKAGE_SIGNATURE_UNVERIFIED` | A pinned NEVRA has no signature by the pinned key. |
| `PACKAGE_UNPINNED_FROM_REPO` | A package that the pinned key signed is not pinned. |
| `PACKAGE_SIGNATURE_SET_INCOMPLETE` | The signature list does not cover exactly the live package set. |
| `PACKAGE_VERSION_LABEL_DISAGREES` | `org.opencontainers.image.version` is not the pinned version. |
| `PACKAGE_REVISION_LABEL_DISAGREES` | `org.opencontainers.image.revision` is not the version-release of the pins. |
| `PACKAGE_SOURCE_LABEL_DISAGREES` | `org.opencontainers.image.source` is not the pinned repository. |
| `PACKAGE_VERIFICATION_NOT_RECORDED` | The positive predicate `package_mode_valid` does not hold. It repeats every condition. |

Each comparison of two values uses a different sentinel on each side. `PACKAGE_VERIFICATION_NOT_RECORDED` negates a positive predicate, as point 4 of the [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md) requires. The observation `PACKAGE_PROVENANCE` records the repository, the key and the NEVRAs in the signed verdict and the PR comment. The CVE gate is the same as for every other image.

The repo gate adds `VERSIONS_PACKAGE_FIELD_MISSING`, `VERSIONS_PACKAGE_TRUST_CLASS_INVALID`, `VERSIONS_PACKAGE_KIND_CONFLICT`, `VERSIONS_PACKAGE_BASE_DANGLING`, `VERSIONS_PACKAGE_REPO_DANGLING`, `VERSIONS_PACKAGE_REPO_INVALID`, `VERSIONS_PACKAGE_NEVRAS_MISSING`, `VERSIONS_PACKAGE_NEVRA_INVALID`, `VERSIONS_PACKAGE_VERSION_DISAGREES`, `VERSIONS_PACKAGE_TRACK_MISMATCH`, `VERSIONS_PACKAGE_ARCH_SKEW` and `VERSIONS_PACKAGE_NAME_DUPLICATE`. `VERSIONS_TRACK_UNANCHORED` also covers `packages.track`.

### Drift and the other checks

* `scripts/drift-upstream.sh` reads the `primary.xml` of each repository. It proposes the newest VERSION-RELEASE inside the track that every pinned package has on every architecture. It never changes a key: a key at `keyUrl` that differs from the committed copy is an alarm.
* `make -f Ops.mk verify-package-pins` checks that each pinned NEVRA is still in its repository and that each live key equals the committed copy. `verify-pins` runs it.
* `make -f Ops.mk check-keyring` holds each package key to its sidecar, to `keySha256` and to `keyFingerprint`. The Repo Gate runs it.
* `scripts/lint-containerfiles.sh` checks the shape of a package Containerfile: one stage on the pinned base, the five labels from the correct build arguments, no way to disable a signature check, an upgrade before the third-party key exists, `rpm -q` verification, a non-root `USER` in GID 0, and runtime fields that agree with `versions.json`.
* The matrix guard in `build.yml`, `review.yml` and `release.yml` accepts the kind `package` and stays byte-identical. A package leg runs in the build job. `build.yml` rebuilds a package image when its base or its repository entry changes.
* The release tags are those of the build track: `<version>-<shortsha>-<arch>`, then the manifest lists `<version>`, `<version>-<shortsha>` and `<version>-<YYYYMMDD>`.

## The proof

On 2026-11-14 we broke each check deliberately, one break at a time, and confirmed that a test failed.

* 62 breaks of `.github/pdp/policies.rego` made `opa test` fail. They deleted each new rule, removed each condition from each predicate, used one sentinel on both sides, compared key IDs case-sensitively, took the wrong 16 hex digits of the fingerprint, unanchored the NEVRA pattern and the track, and removed `package` from the tracks. Nine early breaks did not fail. Two showed two rules with the same code, which are now one rule. Six showed a missing test, which now exists. One showed that "pinned NEVRA is installed" follows from two other conditions, so the predicate no longer repeats it.
* 16 breaks of the Containerfile made `scripts/lint-containerfiles.sh` fail.
* 5 breaks of the package section of `scripts/drift-upstream.sh` made `scripts/test-drift-upstream.sh` fail.
* A removed package-repository reference in the `build.yml` matrix made `scripts/lint-workflows.sh` fail.
* A wrong fingerprint and a wrong `keySha256` in `versions.json` each made `check-keyring` fail.

## Consequences

* A package image has no independent binary check. Its trust comes from the vendor signature, which the review re-derives, and from the pinned NEVRAs.
* The UBI dependencies (for example `systemd-libs`, `libicu` and `krb5-libs`) are not pinned by NEVRA. They come from the Red Hat signed UBI repositories with `gpgcheck=1`, at build time. The SBOM and `package-verification.json` record each one and its signer. A rebuild picks up every fix that UBI publishes.
* A fix that RHEL publishes can reach the UBI repositories days later. The first postgresql17 scan found exactly that for `krb5-libs`. See [The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17](/issues/the-ubi-repositories-do-not-yet-carry-the-krb5-libs-fix-for-14-highs-in-postgresql17--01a1dd21edb8.md).
* A PGDG key rotation stops every build until a reviewed PR updates the key, `keySha256` and `keyFingerprint`.
* The build matrix carries a third kind. Any tool that reads the matrix must accept it.
* P-TSC-4 also asks about LiteLLM (Python) and Ollama (CGO and CUDA). This ADR answers it only for software that a vendor ships as signed RPMs. The other two need their own decision.

## Related

* [postgresql17](/images/postgresql17--01a1dd2247ba.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md)
* [ADR-008: A first-party build declares that no vendor binary exists](/decisions/adr-008-a-first-party-build-declares-that-no-vendor-binary-exists--01a1dbc581d4.md)
* [The review actor re-derives the facts](/architecture/the-review-actor-re-derives-the-facts--01a18382f356.md)
* [Fail-closed policy contract](/supply-chain/fail-closed-policy-contract--01a18383d851.md)
* [Pinned upstream keyrings and identities](/architecture/pinned-upstream-keyrings-and-identities--01a18382f417.md)
* [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md)
* [Decisions overview](/decisions/decisions-overview--01a1837da541.md)
