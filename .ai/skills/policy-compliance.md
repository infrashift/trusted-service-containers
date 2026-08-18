# Policy

**One file, one package.** `.github/pdp/policies.rego`, package `tsc.pdp`.
There are no other `.rego` files and there must never be —
`scripts/check-no-orphan-rego.sh` enforces it. The reference accumulated six
orphaned policy files that contradicted the live one; two would have denied
every image, and nobody noticed because nothing evaluated them.

## Two entrypoints

| query | scope |
|---|---|
| `data.tsc.pdp.repo_decision` | the repository: secrets, `versions.json` schema, exception hygiene. Once per PR. |
| `data.tsc.pdp.decision` | one leg, either track. |

Evaluate with `jq -e` on the result: it exits non-zero on `null`/`false`, so a
policy that failed to load is a hard failure, never a silent pass. Do **not**
pass `--strict-builtin-errors` — under the default a builtin error becomes
undefined, which empties the waiver set and leaves every Critical unwaived.
That is the fail-closed direction.

## The fail-closed contract

Documented in full at the top of the policy. Read it before editing. Summary in
[`../../CLAUDE.md`](../../CLAUDE.md).

## One CVE gate for every image

Critical blocks unconditionally. High blocks when `fix_state == "fixed"` —
actionable, a re-pin clears it. Unfixable Highs are recorded and never block: no
action we control clears them, and blocking would gate every image on a vendor's
backport schedule. No trust class appears in any CVE rule.

## Tests are not optional

74 tests, 85% coverage floor. Every rule needs a test that fails without it.
Break new checks deliberately and confirm they fail — three lint rules here
initially passed by matching their own comments.

```bash
make -f Ops.mk policy-test
```
