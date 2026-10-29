# Working in this repository

Conventions that are load-bearing. Most exist because the sibling repo
`trusted-base-oci-images` got them wrong in a way that was invisible until
someone looked closely.

## Run this before proposing anything

```bash
make -f Ops.mk validate
```

Schema, gitleaks config, single-policy check, workflow lint, Containerfile
lint, doc path lint, the wiki check (`okfw` must be on PATH), shellcheck, script
tests and the policy tests (85% coverage floor). It is fast. There is no reason to skip it.

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

## `observe` is not a pass

An `observe` leg with blocking findings gets a green `review/cve-policy` and
lands in `quarantine/`. PR #29 was merged two minutes after a review comment
showing a Critical and seven Highs per arch, because the check was green. Before
merging any image PR, **read the review comment**: Blocking must be 0, or the
PR must say why quarantine is the intended outcome. Scan the local build first
([Add an upstream image](./.okfw/operations/add-an-upstream-image--01a18383d9be.md),
step 6) so the review is not where you find out.

## Toolchains are pins that rot

`toolchains` sit on a rolling tag that Go security releases move. A `stdlib`
finding on a build leg is **our compiler's**, not the source's or the base's:
re-pin the toolchain (`goVersion` records the patch). `drift-upstream.sh` and
`verify-build-pins` both watch it now; before 2026-10-13 nothing did. Never set
`GOTOOLCHAIN` to a version string -- it downloads that compiler and silently
ignores a bumped image. And a toolchain, base or source change rebuilds every
image that references it; `lint-workflows.sh` check 11 holds `build.yml` to that.

## Dual provenance is an observation, never a gate

Go builds are not reproducible here — we measured, in detail
([the measurement](./.okfw/findings/a-nats-binary-built-from-source-did-not-match-the-vendor-binary-on-2026-08-18--01a1838a6cfc.md)).
The policy gates that the comparison was **performed** and is **well-formed**,
never its outcome. If someone proposes promoting it to a gate, read
[ADR-004](./.okfw/decisions/adr-004-dual-provenance-is-an-observation-not-a-gate--01a18382f4a6.md) first.

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

Write wiki concepts and docs **after** the thing they describe exists.
`scripts/lint-skills.sh` fails CI if a backticked path in a doc does not
resolve — the direct fix for the reference's cards citing four files that were
never created. It does not scan `.okfw/` yet (an open wiki issue), so check
every path you cite in a concept by hand.

## Project knowledge lives in the wiki

The `.ai/` cards, the PRD and `docs/build-track/` moved into the OKF wiki in
`.okfw/`; the old files are pointers. Issues, plans and dated findings are
tracked there too — the wiki, not GitHub Issues, is the tracker of record.

* Write all prose in `.okfw/` in Simplified Technical English (ASD-STE100). The rules and examples are in the wiki: run `okfw search "simplified technical english"`.
* Start at the [wiki map](./.okfw/wiki-map--01a1837da4d8.md). Open a bundle overview before you open the concepts in that bundle.
* Track issues and plans in the wiki. List the open issues with `okfw search --kind issue --tag open`.
* Run `make -f Ops.mk check-wiki` after you change a concept. `validate` runs it too.

<!-- BEGIN okfw -->
## Project knowledge base (okfw)

trusted-service-containers keeps a local-first OKF wiki in `.okfw/`: markdown concepts with
YAML frontmatter, linked to each other. The files are the whole database —
search and the link graph are computed from them on demand, so there is no
index to build and nothing to sync. Each directory's `index.md` is generated
and gives a cheap overview before you open anything (OKF section 8).

- **Search before you derive.** `okfw search "<query>"` / `okfw_search`. The
  wiki holds what the code does not say — why things are built the way they
  are, what was considered and rejected, dependency and security findings,
  operational context, open work. Check it before explaining a design,
  assessing risk, or running an analysis someone may already have recorded and
  adjudicated.
- **Browse top-down.** Each directory's `index.md` lists its concepts with
  their descriptions (`okfw_read {"ref":"<dir>/"}` over MCP). Open only what fits.
- **Search before you write**, too, so a new concept links to what already
  exists instead of duplicating it.
- **Link actively** — `[Title](/dir/file.md)` from the wiki root, or
  `./<file>.md`. Links are what makes the wiki more than a folder.
- **One idea per concept**, with a one-sentence `description`.
- **Use `okfw move` / `okfw delete`, never `mv` / `rm`.** `move` repairs every
  link to the concept and its own relative links, and both keep the `index.md`
  listings current; the shell commands break the links and leave the listings
  stale.
- **`status` is the OKF lifecycle field** (`draft`/`stable`/`deprecated`), not
  task state. Mark superseded knowledge rather than deleting it.
- **Custom metadata goes under `x:`** — the schema is closed and rejects any
  other unrecognized key.
- Don't edit `index.md` or `log.md`; okfw generates them.

Results are capped and say so: `truncated`, or `… N more`, means you did not
see everything — raise the limit or page with `--offset`/`"offset"`.

`okfw mcp` serves all of this as MCP stdio tools named `okfw_*`.
<!-- END okfw -->
