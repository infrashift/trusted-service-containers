---
id: "01a18382-f3dd-73b0-9ab6-5ec4a35010bf"
title: "Registry namespaces and cleanup"
type: "component"
tags:
  - "architecture"
  - "registry"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "The three GHCR namespaces, how long each keeps images, and the narrow rules that limit cleanup to development/."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/cleanup-dev.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Ops.mk"
    title: "Ops.mk (clean-ghcr-namespace)"
---

# Registry namespaces and cleanup

The registry has three namespaces under `ghcr.io/infrashift/trusted-service-containers/`. The cleanup removes images only from `development/`. The `trusted/` and `quarantine/` namespaces are permanent.

## Namespaces

| Namespace | Contents | Lifetime |
|---|---|---|
| `development/` | The images of one PR, before review | `cleanup-dev.yml` deletes them after the release |
| `trusted/` | Images that have no violations, in `enforce` or `observe` mode | Permanent |
| `quarantine/` | Images that have violations, with full evidence. In `enforce` mode the verdict is `FAIL`. In `observe` mode the verdict is `PASS`. | Permanent |

The PDP sets the namespace from the count of violations only. The enforcement value does not change the namespace. See `.github/pdp/policies.rego` (`target_namespace`).

There is one package for each image. The tag identifies the variant, because the upstream tag already identifies it clearly.

## Cleanup is narrow

* `scripts/cleanup-dev.sh` deletes single package versions, never a whole package.
* It deletes a version only when each tag on that version belongs to the PR. If another PR or a promoted tag shares a version, the script reports the version and keeps it.
* `cleanup-dev.yml` reads the PR number from the explicit `pullRequest` field of the release result. The reference repository read a distro key as a PR number.
* `make -f Ops.mk clean-ghcr-namespace` refuses each namespace except `development`.

## Quarantine is not a discard

The pipeline mirrors or builds, scans and signs a quarantined image like all other images. The image has a signed verdict that records its violations. The pipeline holds back only the clean tag under `trusted/`. See [ADR-003: Quarantine is a documented state](/decisions/adr-003-quarantine-is-a-documented-state--01a18382f486.md).

## Related

* [Promotion](/architecture/promotion--01a18382f371.md)
* [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md)
* [ADR-003: Quarantine is a documented state](/decisions/adr-003-quarantine-is-a-documented-state--01a18382f486.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
