# Registry hygiene

Three namespaces under `ghcr.io/infrashift/trusted-service-containers/`:

| namespace | contents | lifetime |
|---|---|---|
| `development/` | per-PR scratch | deleted by `cleanup-dev.yml` after release |
| `trusted/` | passed policy | permanent |
| `quarantine/` | failed policy, fully evidenced | permanent |

One package **per service**; the variant rides in the tag, because the upstream
tag already encodes it unambiguously.

## Cleanup is deliberately narrow

`scripts/cleanup-dev.sh` deletes individual package **versions**, never whole
packages, and only when *every* tag on a version belongs to that PR. A version
shared with another PR or a promoted tag is reported and kept.

`Ops.mk clean-ghcr-namespace` refuses any namespace but `development` —
quarantine holds signed, referenced artifacts and is a documented state, not a
wastebasket.

## Quarantine is not a discard

A quarantined image is mirrored, scanned, signed, and carries a signed verdict
recording why it failed. What is withheld is the clean tag under `trusted/`.
