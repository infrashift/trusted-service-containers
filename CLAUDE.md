# Working in this repository

Conventions that are load-bearing. Most exist because the sibling repo
`trusted-base-oci-images` got them wrong in a way that was invisible until
someone looked closely.

## Run this before proposing anything

```bash
make -f Ops.mk validate
```

Schema, gitleaks config, single-policy check, workflow lint, Containerfile
lint, shellcheck, and 74 policy tests. It is fast. There is no reason to skip it.

## versions.json is the only place a digest lives

No digest is hardcoded in a Containerfile, a workflow, or a script — the
Containerfile lint fails the build if one appears. Every pin is a full
`sha256:` digest; a tag is not a pin, and `source_ref` must be a 40-hex commit
because tags move and can be force-pushed.

A **`track`** is an anchored regex bounding where a pin may legally go.
**Never widen one as part of another change.** It is a policy decision and needs
its own reviewed PR. Anchors are mandatory: `3\.90\.` without them also matches
`13.90.7`.

## Fail closed, and prove it

`.github/pdp/policies.rego` documents a five-point contract at the top. The
short version:

- `> 0` against a missing value is **undefined** in Rego, i.e. silently
  non-violating. Every numeric field has an `is_number()` guard.
- Every enum is read via `object.get()` with a `"<missing>"` sentinel against a
  closed set. Unknown or absent violates.
- When two fields must match, each side gets a **different** sentinel default,
  so "both absent" compares unequal and denies.
- Never write `not <thing_is_bad>` — an undefined helper makes `not` true, which
  fails open. Define the positive predicate and negate that.
- Every new rule needs a test that fails without it. Coverage floor is 85%.

This class of bug is not theoretical here. Three separate lint rules I wrote
initially passed by matching their own comments, and `binary-crosscheck.sh`
reported a MATCH by comparing two empty strings. **When you add a check, break
it deliberately and confirm it fails.**

## Never pass `--replace` to `cosign attest`

It was safe in the reference repo. Here it would delete the vendor attestations
the mirror track exists to preserve, and clobber the amd64 SBOM when writing the
arm64 one. `scripts/lint-workflows.sh` enforces this.

## The digest is the claim

Mirrored images get no labels of ours — adding one changes the digest. Our
provenance lives in an attestation instead. Built images carry five required
labels, and the ARGs behind them **must be re-declared after the runtime
`FROM`**: ARGs before the first `FROM` are global build args, out of scope
inside a stage, and the labels expand to empty strings. That is a real bug the
reference had to fix, and both the Containerfile lint and the policy's
`BUILD_LABEL_EMPTY` rule catch it.

## The review actor does not trust the build actor

`review.yml` re-resolves digests **live from GHCR** and re-reads trust class from
the checked-out `versions.json`, never from the evidence bundle. That is what
makes downgrading an image's verification require a CODEOWNERS-reviewed commit
rather than a workflow edit. Keep it that way.

## Dual provenance is an observation, never a gate

Go builds are not reproducible here — we measured, in detail, in
`docs/build-track/dual-provenance.md`. The policy gates that the comparison was
**performed** and is **well-formed**, never its outcome. If someone proposes
promoting it to a gate, read that document first.

## Workflow conventions

- Every `uses:` pinned to a 40-char SHA; every tool version pinned in `tools.lock`.
- `permissions: {}` at the top, least privilege per job.
- Untrusted values reach shell through `env:` and are referenced as `"$VAR"`,
  never interpolated. jq takes them via `--arg`.
- The matrix injection guard is **byte-identical** in `build.yml`, `review.yml`
  and `release.yml`. `build-matrix.json` crosses that boundary three times; if
  one copy drifts, that boundary is silently unguarded. The lint enforces it.
- `pr-gate.yml`'s `BUILD_PATHS` regex must cover `build.yml`'s `paths:` filter.
  Also linted — the reference has a dedicated commit fixing exactly this drift.

## Two `jq` traps that cost real debugging time

- **`@tsv` escapes backslashes.** A regex sent through it arrives
  double-escaped and matches nothing, which reads like a config error rather
  than a tooling bug. Pass only slugs through `@tsv`; look everything else up
  with `jq --arg` inside the loop.
- **Tab is IFS whitespace**, so `IFS=$'\t' read` *collapses* consecutive tabs
  and an empty field silently shifts every column after it.

## Documentation follows the code

Write `.ai/` cards and docs **after** the thing they describe exists.
`scripts/lint-skills.sh` fails CI if a backticked path in a card does not
resolve — the direct fix for the reference's cards citing four files that were
never created.
