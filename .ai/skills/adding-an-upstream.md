# Adding a new upstream image

Step one is a trust decision, not a digest.

## 1. Which track?

- **Mirror** if a suitable hardened image already exists. Do not rebuild it.
- **Build** only if no official variant on our base exists. Verify that claim:
  check the vendor's tag list for a UBI variant before assuming.

## 2. Declare the trust class

See [`upstream-trust.md`](upstream-trust.md). If the vendor signs, try to verify
before claiming `none`:

```bash
cosign download signature <image>:<tag>
```

`Cert: false, Chain: false` with no published public key means `none` — record
*that we checked*, not that we skipped.

Also look for a Notary Project signature: `cosign tree <image>@<digest>` lists
`application/vnd.cncf.notary.signature` referrers, and `notation inspect`
shows the certificate chain. If the root is a vendor CA you can fetch from the
vendor's own PKI endpoint, the class is `notation`: vendor the root certificate under
`.github/pdp/keyring/`, set `keyring`, and pin `notation.trustedIdentity` to
the leaf subject. See `upstream-trust.md`.

## 3. Write an anchored track

`^3\.90\.[0-9]+-ubi$`, not `3\.90\.`. Unanchored also matches `13.90.7`. The
repo gate rejects unanchored tracks and tracks that do not contain their own pin.

For a rolling tag the track is the literal tag (`^3-debian13$`) — the vendor
moves the digest behind it, which is the whole signal.

Check how `sort -V` orders the vendor's tags before writing a multi-tag track.
`scripts/drift-upstream.sh` proposes the highest-sorting match, and a hotfix
suffix sorts *below* its base: `2025-CU8-GDR1-rhel-10` comes before
`2025-CU8-rhel-10`, so a CU track would never propose a GDR security release.
When the vendor repoints a rolling tag on every fix (mssql `2025-latest`), pin
that and let only the digest move.

A bare single-platform manifest with no index (mssql) is supported: declare
exactly the one platform, and `scripts/manifest-platforms.sh` reads it from the
config blob instead of the index.

## 4. Pin by digest, and by commit for build entries

`regctl manifest head --format '{{.GetDescriptor.Digest}}' <repo>:<tag>` — the
index digest. Not `docker inspect`, which gives your local architecture's.

Build entries pin a 40-hex commit. If the vendor stamps a short commit, pin
`shortCommit` too: it is git's *dynamic* abbreviation and cannot be sliced from
the full SHA. See [`../../docs/build-track/dual-provenance.md`](../../docs/build-track/dual-provenance.md).

## 5. Onboard in `observe`

`enforcement: "observe"` still computes and publishes every violation and still
routes to `quarantine`. It only stops the pipeline hard-failing while the
day-one CVE triage happens. It is **not** a route into `trusted/`.

## 6. Validate

```bash
make -f Ops.mk validate
make -f Ops.mk verify-pins
```
