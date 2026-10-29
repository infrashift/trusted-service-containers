---
id: "01a18382-f392-7969-93d9-e85a2f6c8253"
title: "Release tags and manifest lists"
type: "component"
tags:
  - "architecture"
  - "promotion"
  - "tags"
created: "2026-10-28T12:15:59-05:00"
timestamp: "2026-10-28T12:23:40-05:00"
description: "Which tags each track gets in trusted/ and quarantine/, why there is no latest tag, and why only the build track gets manifest lists."
status: "draft"
generated:
  by: "claude-code/opus-5-5"
  at: "2026-10-28T12:23:40-05:00"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-leg.sh"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/scripts/release-manifest.sh"
    title: "release-manifest.sh"
---

# Release tags and manifest lists

The tags of an image depend on its track and its namespace. An image in `quarantine/` never gets the bare upstream-shaped tag. No image gets a `latest` tag.

## Tags

| Track | `trusted/` | `quarantine/` |
|---|---|---|
| mirror | `<upstream_tag>`, `<upstream_tag>-<shortsha>`, `<upstream_tag>-<YYYYMMDD>` | `-<shortsha>` only |
| build | `<version>-<shortsha>-<arch>`, then manifest lists | `-<shortsha>-<arch>` |

A mirrored image in `trusted/` uses the upstream tag. Thus a consumer changes one line to move to it:

```diff
- dhi.io/traefik:3-debian13
+ ghcr.io/infrashift/trusted-service-containers/trusted/traefik:3-debian13
```

Next to the rolling tag, each release also publishes the immutable `-<shortsha>` and `-<YYYYMMDD>` tags.

An image in `quarantine/` never gets the bare upstream-shaped tag. Thus a typing error in a registry mirror cannot resolve to a quarantined image. To use a quarantined image, a consumer must give the exact commit. There is no `latest` tag anywhere. See [ADR-002: No latest tag](/decisions/adr-002-no-latest-tag--01a18382f469.md).

## Manifest lists are for the build track only

`build.yml` calculates a separate matrix, `manifest_matrix`. `release.yml` uses it to select the legs that get manifest lists. The structure of the workflow does the filtering, not a condition inside the job. A new list for a mirrored image would replace the signed vendor index with an index that the vendor never signed.

`scripts/release-manifest.sh` makes no manifest list unless each architecture of the image reached `trusted/`.

## Related

* [Promotion](/architecture/promotion--01a18382f371.md)
* [Registry namespaces and cleanup](/architecture/registry-namespaces-and-cleanup--01a18382f3dd.md)
* [ADR-002: No latest tag](/decisions/adr-002-no-latest-tag--01a18382f469.md)
* [ADR-003: Quarantine is a documented state](/decisions/adr-003-quarantine-is-a-documented-state--01a18382f486.md)
* [Architecture overview](/architecture/architecture-overview--01a1837da50c.md)
