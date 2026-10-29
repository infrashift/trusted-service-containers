---
id: "01a18383-d9be-702a-a36e-71746d24572b"
title: "Add an upstream image"
type: "runbook"
tags:
  - "runbook"
  - "onboarding"
  - "versions"
created: "2026-10-28T12:16:58-05:00"
timestamp: "2026-10-28T12:24:43-05:00"
description: "The seven steps to add an image to versions.json: track, trust class, anchored track, pin, observe, a local scan, and the review comment."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:24:43-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/drift-upstream.sh"
    title: "scripts/drift-upstream.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/CLAUDE.md"
    title: "CLAUDE.md"
---

# Add an upstream image

This runbook adds a new upstream image to `versions.json`. It has seven steps. The first step is a trust decision, not a digest. `CLAUDE.md` refers to step 6, "Validate, and scan the local build".

## Step 1: Choose the track

1. Choose the mirror track if a suitable hardened image exists. Do not build it again.
2. Choose the build track only if no official variant on our base exists.
3. Make sure of that claim. Read the tag list of the vendor and look for a UBI variant.

## Step 2: Decide the trust class

The trust class decides the signature checks only. See the upstream trust rules in the [architecture overview](/architecture/architecture-overview--01a1837da50c.md).

1. If the vendor signs, try to verify the signature before you choose `none`:

   ```bash
   cosign download signature <image>:<tag>
   ```

2. If the output shows `Cert: false, Chain: false` and the vendor publishes no public key, the class is `none`. Record that you checked. Do not record that you skipped the check.
3. Look for a Notary Project signature. `cosign tree <image>@<digest>` lists referrers of type `application/vnd.cncf.notary.signature`. `notation inspect` shows the certificate chain.
4. Find the root CA of the chain. If the vendor PKI endpoint publishes it, the class is `notation`. Then do these steps:
   1. Put the root certificate in `.github/pdp/keyring/`, with a `.sha256` sidecar.
   2. Set `keyring` on the image entry.
   3. Set `notation.trustedIdentity` to the subject of the leaf certificate. The root alone would trust every product of the vendor.

## Step 3: Write an anchored track

WARNING: Always anchor a track. `3\.90\.` without anchors also matches `13.90.7`. The repo gate rejects an unanchored track and a track that does not match its own pin.

1. Write the track with `^` and `$`, for example `^3\.90\.[0-9]+-ubi$`.
2. For a rolling tag, write the literal tag as the track, for example `^3-debian13$`. The vendor moves the digest behind the tag, and that move is the signal.
3. Before you write a track that matches several tags, check how `sort -V` orders the tags of the vendor. `scripts/drift-upstream.sh` proposes the highest match.
4. Check the hotfix suffixes. A hotfix suffix sorts below its base: `2025-CU8-GDR1-rhel-10` sorts before `2025-CU8-rhel-10`. A CU track would never propose that GDR security release.
5. If the vendor moves a rolling tag on every fix, as mssql does with `2025-latest`, pin the rolling tag. Then only the digest moves.
6. If the upstream publishes one bare single-platform manifest and no index (mssql), declare exactly that one platform. `scripts/manifest-platforms.sh` reads it from the config blob.

## Step 4: Pin by digest, and by commit for a build entry

1. Get the index digest:

   ```bash
   regctl manifest head --format '{{.GetDescriptor.Digest}}' <repo>:<tag>
   ```

   Do not use `docker inspect`. It gives the digest for your local architecture.
2. For a build entry, pin a 40-hex commit. A tag is not a pin, because a tag can move.
3. If the vendor stamps a short commit into the binary, also pin `shortCommit`. It is the dynamic abbreviation of git, so you cannot cut it from the full SHA. See [ADR-004: Dual provenance is an observation, not a gate](/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md).

### Build entries: use a current toolchain

To match the compiler of the vendor is a cross-check concern. To be current is a CVE concern, and only the CVE concern gates. PR #29 kept go1.26 at 1.26.6 because the vendor binary had the same patch. Go 1.26.9 had fixed a Critical and seven Highs in `stdlib` five days before. Both architectures came back blocked.

WARNING: Do not set `GOTOOLCHAIN` to a version string. If you do, `go` downloads that compiler and ignores the pinned toolchain image. The Containerfile lint rejects it unless it equals `goVersion`.

1. Read `toolchains.<name>.goVersion` in `versions.json`. It is the compiler patch.
2. Compare it with https://go.dev/doc/devel/release.
3. Run `make -f Ops.mk verify-build-pins`. It fails if the rolling tag of a toolchain moved.
4. Set `GOTOOLCHAIN=local`.

## Step 5: Onboard in observe

1. Set `enforcement` to `observe` on the new image.

`observe` still computes and publishes every violation. It only stops a hard failure of the pipeline during the first CVE triage. A leg with violations goes to `quarantine/`, as it does under `enforce`. A leg with no violations goes to `trusted/` in either mode. Thus `observe` is not a route into `trusted/`.

## Step 6: Validate, and scan the local build

Do this step before you open the pull request. Do not find the problems in the review.

1. Run the static checks and re-resolve the pins:

   ```bash
   make -f Ops.mk validate
   make -f Ops.mk verify-pins
   ```

2. For a build entry, build the Containerfile locally. Scan that local image.
3. For a mirror entry, scan the upstream image by digest. A mirror entry has no local build. `scripts/mirror-leg.sh` copies the image by digest and stops if the digest changes. Then it scans each platform by its child manifest digest. Get the child digest of each platform:

   ```bash
   regctl manifest head --platform <os/arch> --format '{{.GetDescriptor.Digest}}' <upstreamRepo>@<pinned-digest>
   ```

4. Scan each image with the thresholds of the PDP. A Critical blocks with or without a fix. A High blocks when it has a fix. For a mirror entry, `<image>` is `registry:<upstreamRepo>@<child-digest>`.

   ```bash
   grype <image> --fail-on critical
   grype <image> --only-fixed --fail-on high
   ```

5. If either command fails, fix the cause before you open the pull request. Use a newer source or toolchain, for example.
6. If you cannot fix it, say so in the pull request. Say why `quarantine/` is the correct result.

A local build that runs is not a local build that passes the review.

## Step 7: Read the review comment before you merge

`observe` keeps `review/cve-policy` green when blocking findings exist. A green check is not the signal. The review comment is the signal.

1. Read the review comment. Follow [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md).
2. If a leg shows **PASS (observe)** or a non-zero Blocking count, the image goes to `quarantine/`. Its consumer cannot use it there.
3. Triage first. The violations of each leg end with the "Next step" of the PDP.
4. If you merge anyway, state the decision in the pull request. Never merge by default.

## Analysis: after the merge

The source card of this runbook stopped at step 7. These two steps come from other concepts:

1. Add a concept for the image in `images/`. The [images overview](/images/images-overview--01a1837da526.md) gives one concept for each image in `versions.json`, and gives the procedure.
2. When a review shows zero blocking findings, move the image to `enforce`. [Move an image from observe to enforce](/operations/move-an-image-from-observe-to-enforce--01a18383dac5.md) gives the conditions and the procedure.

## Related

* [Operations overview](/operations/operations-overview--01a1837da594.md)
* [Read the review comment before you merge an image PR](/operations/read-the-review-comment-before-you-merge-an-image-pr--01a18383daeb.md)
* [Move an image from observe to enforce](/operations/move-an-image-from-observe-to-enforce--01a18383dac5.md)
* [Waive a CVE](/operations/waive-a-cve--01a18383da9f.md)
* [Containerfile policy](/supply-chain/containerfile-policy--01a18383d8bc.md)
* [CVE gate](/supply-chain/cve-gate--01a18383d875.md)
* [Upstream Drift workflow](/supply-chain/upstream-drift-workflow--01a18383d7a3.md)
* [Upstream trust classes](/architecture/upstream-trust-classes--01a18382f3fb.md)
* [Mirror track](/architecture/mirror-track--01a18382f29c.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
