# CVE exceptions

An exception is an accepted risk with an owner and a date. It is not a way to
make a red check go green. Register: `.github/pdp/exceptions.yaml`.

## Before adding one

Check whether a newer release **within the declared track** clears the finding:

```bash
make -f Ops.mk verify-pins
```

For a `dhi` image especially — those advertise a near-zero known-CVE baseline,
so a finding there is far more likely a stale pin than an acceptable risk. The
policy says so in the `remediation_hint` on every CVE violation.

## Every field is required

`id`, `image`, `variant`, `package`, non-empty `cves[]`, `issued`, `expires`,
`owner`, `ticket`, and a `justification` of at least 40 characters of actual
reasoning. An entry missing `expires` or carrying "n/a" waives **nothing** and
raises `EXCEPTION_INVALID` so the author finds out why rather than wondering.

Maximum window is 90 days from `issued`, for every image regardless of trust
class. Enforced in policy, not left to reviewer discipline.

## Waived is a visible state

Waived findings appear in `decision.waived`, in the PR comment's "Waived CVEs"
table with owner and expiry, and in the signed review verdict. A promoted image
permanently carries the record of what was waived to get it there. Nothing is
silently dropped.

## Expiry is deterministic

Evaluated against `input.evaluated_at`, supplied by the workflow.
`time.now_ns()` is called nowhere in the policy. Re-running the gate on archived
evidence a year later reproduces the identical decision — which is what makes a
signed verdict worth signing.
