---
id: "01a1dee7-55a1-7530-8a33-1c98eeb889b1"
title: "UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "valkey"
  - "package"
  - "p-tsc-4"
created: "2026-11-15T05:11:05-06:00"
timestamp: "2026-11-15T05:11:05-06:00"
description: "UBI9 AppStream, BaseOS and CodeReady Builder, UBI10 AppStream and EPEL9 had no valkey RPM; EPEL9 retired it when RHEL 9.7 added it."
status: "draft"
resource: "https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/appstream/os/repodata/repomd.xml"
sources:
  - resource: "https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/repodata/repomd.xml"
    title: "EPEL 9 Everything x86_64 repodata"
  - resource: "https://src.fedoraproject.org/rpms/valkey/raw/epel9/f/dead.package"
    title: "Fedora dist-git rpms/valkey, branch epel9, dead.package"
---

# UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15

On 2026-11-15, no freely available EL9 repository had a Valkey RPM. RHEL 9.7 ships Valkey, but UBI does not carry it, and EPEL 9 removed its own package.

## Method

For each repository, we downloaded `repodata/repomd.xml`, then the `primary.xml` file that it names. Then we searched the `<name>` elements for `valkey`, `redis` and `keydb`. For UBI9 AppStream, we also read `modules.yaml`.

## Result

| Repository | Base URL | `repomd.xml` revision | Result |
|---|---|---|---|
| UBI9 AppStream, x86_64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/appstream/os` | 1794480320 | No `valkey`. `redis` 7.2.16 from the module stream `redis:7`, with `redis-devel` and `redis-doc`. |
| UBI9 AppStream, aarch64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/aarch64/appstream/os` | 1794466179 | The same as x86_64. |
| UBI9 BaseOS, x86_64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/baseos/os` | 1794413174 | No `valkey`. |
| UBI9 CodeReady Builder, x86_64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/codeready-builder/os` | 1794413204 | No `valkey`. |
| UBI10 AppStream, x86_64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi10/10/x86_64/appstream/os` | 1794489664 | No `valkey` and no `redis`. |
| EPEL 9 Everything, x86_64 | `https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64` | 1794706553 | No `valkey`. `keydb` and `hiredis` are present. |
| EPEL 9 Everything, aarch64 | `https://dl.fedoraproject.org/pub/epel/9/Everything/aarch64` | 1794706554 | No `valkey`. |

The UBI9 `modules.yaml` listed the modules maven, nginx, nodejs, php, redis and ruby. It had no `valkey` module.

## Why EPEL 9 has no Valkey

The Fedora dist-git repository `rpms/valkey` has an `epel9` branch. On that branch, the file `dead.package` says "Added to RHEL 9.7 rhbz#2369374". EPEL removes a package when RHEL starts to ship it. UBI carries only a part of RHEL AppStream, and Valkey is not in that part.

## The Red Hat Valkey images

* `registry.access.redhat.com/rhel9/valkey-8` answered HTTP 403: "This repo requires terms acceptance and is only available on registry.redhat.io". The image exists, but it needs an entitled pull.
* `registry.access.redhat.com/ubi9/valkey-8` answered HTTP 404.

## Consequence

The package kind of [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md) cannot install Valkey from a free, signed EL9 repository. The RHEL 9.7 package is not UBI content. It needs a subscription in CI, and only UBI content is freely redistributable. See [ADR-010: Valkey builds from source on UBI, LiteLLM and Ollama mirror DHI](/decisions/adr-010-valkey-builds-from-source-on-ubi-litellm-and-ollama-mirror-dhi--01a1dee688b9.md).

## Related

* [ADR-010: Valkey builds from source on UBI, LiteLLM and Ollama mirror DHI](/decisions/adr-010-valkey-builds-from-source-on-ubi-litellm-and-ollama-mirror-dhi--01a1dee688b9.md)
* [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md): the same check for PostgreSQL on 2026-11-14.
* [Findings overview](/findings/findings-overview--01a1837da578.md)
