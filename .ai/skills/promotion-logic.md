# Promotion

`development/` → `trusted/` or `quarantine/`. Never rebuild; the promoted image
is byte-identical to what was built and reviewed, asserted a third time in
`scripts/release-leg.sh`.

## The verdict comes from a signed attestation

Not from a workflow artifact — an artifact is mutable by anyone who can re-run a
job. `release-leg.sh` reads the review verdict via `cosign verify-attestation`
against `.github/pdp/public-keys/review.pub`, and takes the newest by
`evaluatedAt` (`--replace` is banned, so reruns accumulate).

It then checks the verdict's `commitSha` equals the merged head SHA. A verdict
issued against a different commit is a verdict about different bits, however
recent it looks.

## Tags

| | trusted | quarantine |
|---|---|---|
| mirror | `<upstream_tag>`, `-<shortsha>`, `-<YYYYMMDD>` | `-<shortsha>` **only** |
| build | `<version>-<shortsha>-<arch>`, then manifest lists | `-<shortsha>-<arch>` |

Quarantine never gets the bare upstream-shaped tag, so a registry-mirror typo
cannot silently resolve to a quarantined image. **No `:latest`, anywhere.**

## Manifest lists are build-track only

Filtered structurally via `manifest_matrix`, not by a condition inside the job.
Reassembling a mirrored index would replace the vendor's signed index with one
they never signed. `scripts/release-manifest.sh` also withholds the lists
entirely unless **every** arch reached `trusted/`.

## Dual signing

Pass 1 keyed with `--tlog-upload=false` — the sovereign signature, leaking
nothing about release cadence to a public log. Pass 2 keyless with tlog on, so a
third party can independently confirm the release happened.
