---
id: "01a1e09b-ec5d-75e1-82cc-a9dfdc9414fd"
title: "pgbouncer"
type: "image"
tags:
  - "image"
  - "pgbouncer"
  - "native"
created: "2026-11-15T13:07:57-06:00"
timestamp: "2026-11-15T13:07:57-06:00"
description: "PgBouncer 1.26 compiled with OpenSSL from a pinned commit on UBI; native kind (ADR-010), UID 1001, port 6432, no c-ares."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/pgbouncer.Containerfile"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/rootfs/pgbouncer/etc/pgbouncer/pgbouncer.ini"
    title: "rootfs/pgbouncer/etc/pgbouncer/pgbouncer.ini"
  - resource: "https://github.com/pgbouncer/pgbouncer"
    title: "PgBouncer"
  - resource: "https://www.pgbouncer.org/downloads/"
    title: "PgBouncer downloads"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
    title: "versions.json"
---

# pgbouncer

pgbouncer is the PgBouncer connection pooler for PostgreSQL. We compile the pinned PgBouncer source commit with OpenSSL on a pinned UBI builder, and ship it on our own `ubi9-minimal`. HALO runs it in front of [postgresql17](/images/postgresql17--01a1dd2247ba.md) in production.

## Track

Native track (kind `native`, language `c`). See [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md). The package kind cannot install PgBouncer: the PGDG EL9 RPM requires `c-ares`, and no UBI 9 or PGDG repository ships it. See [No UBI 9 or PGDG repository shipped c-ares for the PGDG PgBouncer RPM on 2026-11-15](/findings/no-ubi-9-or-pgdg-repository-shipped-c-ares-for-the-pgdg-pgbouncer-rpm-on-2026-11-15--01a1e09bffa6.md).

* **Source.** `sources.pgbouncer` pins the 40-hex commit of the release tag `pgbouncer_1_26_1`. The tag is annotated and not signed. `ref` is the tag name, so `scripts/fetch-source.sh` can check that the tag names the pinned commit. Thus the image version and the release tag are `pgbouncer_1_26_1`, not `1.26.1`.
* **Release archive.** `sources.pgbouncer.archive` pins the GitHub archive of the tag. `scripts/fetch-archive.sh` downloads it, checks the sha256, and fails the build unless its file tree equals the tree of the commit.
* **Builder.** The pinned `ubi9-minimal`. `gcc`, `make`, `autoconf`, `automake`, `libtool`, `pkgconf-pkg-config`, `libevent-devel`, `openssl-devel` and `openssl` come from the Red Hat signed UBI repositories (`native.buildPackages`). The builder never reaches the image.
* **Build.** The commit has no `configure` script, so `./autogen.sh` makes it with the UBI autotools. Then `./configure --with-openssl --without-cares --without-pam --without-ldap --without-systemd` and `make pgbouncer`, with the architecture-neutral part of the RHEL hardening flags (`_FORTIFY_SOURCE=2`, `-fstack-protector-strong`, `-fstack-clash-protection`, PIE, full RELRO). TLS links the OpenSSL of UBI dynamically. DNS uses the resolver of libevent (`evdns`). `SOURCE_DATE_EPOCH` is the committer date of the commit. Only the binary is installed, stripped of debug data. There are no man pages, because `pandoc` is not in UBI.
* **No vendor comparison.** The build records the sha256 of `/usr/bin/pgbouncer` as a change detector.

### The archive hash is not a vendor hash

CAUTION: For Valkey, the archive sha256 comes from a second place that the vendor controls (`valkey-io/valkey-hashes`). For PgBouncer, it does not.

* PgBouncer publishes a sha256 only for its `make dist` tarball, at `https://www.pgbouncer.org/downloads/files/1.26.1/pgbouncer-1.26.1.tar.gz.sha256`.
* That tarball is the tree of the commit plus five generated autotools files: `configure`, `config.guess`, `config.sub`, `install-sh` and `lib/usual/config.h.in`. `scripts/fetch-archive.sh` requires identical trees, so it cannot use that tarball.
* Thus the pinned sha256 is the sha256 of the GitHub archive of the tag, which we calculated on 2026-11-15. It shows that GitHub serves the same tree for the tag and the commit. It is not an independent check of the commit.
* On 2026-11-15 we compared by hand: the vendor tarball had the published sha256, and its tree without the five generated files was identical to the tree of the commit.

When a drift bump moves the archive URL, calculate the new sha256 from the new GitHub archive, and do the comparison with the vendor tarball again before you merge.

## Trust class

`internal`. The build leg verifies the `ubi9-minimal` builder and runtime base against the release key of the sibling repository, as for every built image.

## Enforcement

See `versions.json` for the current value. The image starts in `observe`, as step 5 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md) requires. No waiver applies to this image. For the first scan, see [The first pgbouncer scan found no Critical and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-pgbouncer-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-15--01a1e0a478c1.md). Its legs go to `quarantine/` until UBI publishes the `krb5-libs` fix.

## Interface

| Item | Value |
|---|---|
| Image | `ghcr.io/infrashift/trusted-service-containers/trusted/pgbouncer:<version>` (for example `pgbouncer_1_26_1`), also `<version>-<shortsha>` and `<version>-<YYYYMMDD>` |
| Binary | `/usr/bin/pgbouncer` |
| User | UID 1001, primary group GID 0. `/etc/pgbouncer` and `/var/lib/pgbouncer` are `g=u`, so an arbitrary UID in GID 0 also works. PgBouncer does not start as root. |
| Port | 6432 |
| Volume | None. PgBouncer keeps no state. |
| Entrypoint | `pgbouncer`, with the default argument `/etc/pgbouncer/pgbouncer.ini`. An argument to the container replaces the path. |
| TLS | Built in (OpenSSL 3 of UBI). `client_tls_*` and `server_tls_*` work. |
| DNS | libevent `evdns`. There is no c-ares. |
| Not built | PAM, LDAP and systemd notification. `auth_type = pam` and `auth_type = ldap` do not work. |

### The configuration

`rootfs/pgbouncer/etc/pgbouncer/pgbouncer.ini` is ours. Each setting that it does not name is the PgBouncer default.

* `listen_addr = *` and `listen_port = 6432`.
* `unix_socket_dir =` (empty): there is no unix socket.
* `auth_type = scram-sha-256` and `auth_file = /etc/pgbouncer/userlist.txt`. The shipped auth file has no user, so nobody can log in.
* No database in `[databases]`.
* `logfile =` and `pidfile =` (empty): logs go to stderr, and there is no pid file.

### Smoke tests

The Containerfile runs two tests:

1. In the builder, as UID 1001: `pgbouncer --version` names OpenSSL 3 and `evdns`, and a client that requires TLS (`openssl s_client -starttls postgres`) completes the handshake against `client_tls_sslmode = require`. The self-signed key does not leave the builder stage.
2. In the runtime stage: `pgbouncer --version`, a check that the binary links `libssl.so.3` and `libevent-2.1.so` and has no missing library, and, as UID 1001, a start with the shipped configuration that accepts a TCP connection on 6432.

## What HALO sets

* Its own `pgbouncer.ini`, auth file and TLS files, mounted over `/etc/pgbouncer` or in another directory with the path as the container argument.
* `client_tls_sslmode`, `client_tls_key_file` and `client_tls_cert_file` for clients, and `server_tls_sslmode` (and the CA file) towards PostgreSQL.

## Related

* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [No UBI 9 or PGDG repository shipped c-ares for the PGDG PgBouncer RPM on 2026-11-15](/findings/no-ubi-9-or-pgdg-repository-shipped-c-ares-for-the-pgdg-pgbouncer-rpm-on-2026-11-15--01a1e09bffa6.md)
* [postgresql17](/images/postgresql17--01a1dd2247ba.md)
* [valkey](/images/valkey--01a1df5f8878.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Images overview](/images/images-overview--01a1837da526.md)
