---
id: "01a1e09b-ffa6-7ecd-bae1-3dda14f6814f"
title: "No UBI 9 or PGDG repository shipped c-ares for the PGDG PgBouncer RPM on 2026-11-15"
type: "finding"
tags:
  - "finding"
  - "measurement"
  - "pgbouncer"
  - "package"
created: "2026-11-15T13:08:02-06:00"
timestamp: "2026-11-15T13:08:02-06:00"
description: "The PGDG EL9 pgbouncer 1.26.1 RPM requires c-ares, which no UBI 9 (BaseOS, AppStream, CodeReady Builder) or PGDG repository shipped on either architecture."
status: "draft"
resource: "https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-9-x86_64/repodata/repomd.xml"
sources:
  - resource: "https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-9-aarch64/repodata/repomd.xml"
    title: "PGDG common EL9 aarch64 repodata"
  - resource: "https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/baseos/os/repodata/repomd.xml"
    title: "UBI9 BaseOS x86_64 repodata"
  - resource: "https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/x86_64/appstream/os/repodata/repomd.xml"
    title: "UBI9 AppStream x86_64 repodata"
---

# No UBI 9 or PGDG repository shipped c-ares for the PGDG PgBouncer RPM on 2026-11-15

On 2026-11-15, the PGDG EL9 PgBouncer RPM could not be installed from signed repositories that are free to use. It requires `c-ares`, and no UBI 9 or PGDG repository had a package that supplies it.

## Method

For each repository, we downloaded `repodata/repomd.xml`, then the `primary.xml` file that it names. We read the `<requires>` of the newest `pgbouncer` package. Then we searched every package of every repository for a `<provides>` entry or a file that matches `libcares` or `c-ares`.

We then reproduced the install. On the pinned `ubi9-minimal` (`bases.ubi9-minimal.amd64`), we wrote the PGDG common repository file as the package kind writes it: the committed key `.github/pdp/keyring/pgdg-rpm-gpg-key-rhel.asc`, `gpgcheck=1` and `repo_gpgcheck=1`. Then we ran `microdnf install pgbouncer-1.26.1-1PGDG.rhel9.8.x86_64`.

## Result

| Repository | Base URL | `repomd.xml` revision | Result |
|---|---|---|---|
| PGDG common, x86_64 | `https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-9-x86_64` | 1794765430 | `pgbouncer-1.26.1-1PGDG.rhel9.8.x86_64`, signed with key ID `40bca2b408b40d20`. No `c-ares`. |
| PGDG common, aarch64 | `https://download.postgresql.org/pub/repos/yum/common/redhat/rhel-9-aarch64` | 1794765493 | `pgbouncer-1.26.1-1PGDG.rhel9.8.aarch64`, signed with key ID `177b343bb9738825`. No `c-ares`. |
| PGDG 17, x86_64 and aarch64 | `https://download.postgresql.org/pub/repos/yum/17/redhat/rhel-9-<arch>` | 1794486842, 1794486853 | No `pgbouncer` (only `pgbouncer_fdw_17`). No `c-ares`. |
| UBI9 BaseOS, x86_64 and aarch64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/<arch>/baseos/os` | 1794413174, 1794416385 | No `c-ares`. `libevent`, `openldap`, `pam`, `openssl-libs`, `systemd` and `python3` are present. |
| UBI9 AppStream, x86_64 and aarch64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/<arch>/appstream/os` | 1794480320, 1794466179 | No `c-ares`. `python3-psycopg2` 2.8.6 and `libpq` 13.23 are present. |
| UBI9 CodeReady Builder, x86_64 and aarch64 | `https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi9/9/<arch>/codeready-builder/os` | 1794413204, 1794416378 | No `c-ares`. |

The PGDG RPM requires `c-ares >= 1.13` and `libcares.so.2()(64bit)`, on both architectures. Both RPM signatures verified with `rpm -K` against the PGDG keys that `packageRepos.pgdg17-el9` already pins. The install failed with:

```text
nothing provides libcares.so.2()(64bit) needed by pgbouncer-1.26.1-1PGDG.rhel9.8.x86_64 from pgdg-common-el9
nothing provides c-ares >= 1.13 needed by pgbouncer-1.26.1-1PGDG.rhel9.8.x86_64 from pgdg-common-el9
```

With all UBI repositories enabled, `microdnf install c-ares` gave "No package matches". RHEL 9 ships `c-ares` in BaseOS, but UBI does not carry it.

The RPM also requires `python3-psycopg2`, for its `mkauth.py` script. PGDG common has a newer `python3-psycopg2` (2.9.12) than UBI9 AppStream, and that package pulls `libpq5` 18 from PGDG. These packages have other versions than `pgbouncer`, so the package kind could not pin them in the same entry.

## Consequence

The package kind of [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md) cannot install PgBouncer. We build it as the kind `native` of [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md), without c-ares. PgBouncer then uses the DNS resolver of libevent (`evdns`). See [pgbouncer](/images/pgbouncer--01a1e09bec5d.md).

## Related

* [pgbouncer](/images/pgbouncer--01a1e09bec5d.md)
* [UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15](/findings/ubi-9-and-epel-9-shipped-no-valkey-package-on-2026-11-15--01a1dee755a1.md): the same check for Valkey.
* [Findings overview](/findings/findings-overview--01a1837da578.md)
