---
id: "01a1dd22-47ba-7825-b424-745c7afba1af"
title: "postgresql17"
type: "image"
tags:
  - "image"
  - "postgresql17"
  - "package"
created: "2026-11-14T20:56:13-06:00"
timestamp: "2026-11-14T20:56:13-06:00"
description: "PostgreSQL 17 from signed PGDG RPMs at pinned NEVRAs on our ubi9-minimal; package track, UID 26, the postgres env contract of the DHI image."
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/postgresql17.Containerfile"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/rootfs/postgresql17/usr/local/bin/docker-entrypoint.sh"
    title: "rootfs/postgresql17/usr/local/bin/docker-entrypoint.sh"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
    title: "versions.json"
---

# postgresql17


postgresql17 is the PostgreSQL 17 database server and its client tools. We install the signed PGDG RPMs at pinned NEVRAs onto our own `ubi9-minimal`. It replaces the DHI [postgres](/images/postgres--01a183832d06.md) mirror for HALO and Chit.

## Track

Package track (kind `package`). See [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md). UBI9 AppStream has no PostgreSQL 17, so the packages come from the PGDG EL9 repository `pgdg17-el9`. Each architecture has its own repository URL and signing key.

The image installs four PGDG packages: `postgresql17-server`, `postgresql17` (the client tools), `postgresql17-libs` (`libpq`) and `postgresql17-contrib`. The other packages come from the signed UBI repositories.

`postgresql17-contrib` gives the extensions of the Docker and DHI images, for example `pgcrypto`. The first Chit migration runs `CREATE EXTENSION pgcrypto`, and it failed without contrib on 2026-11-14. contrib links `libperl` and `libpython` for its PL transform modules, so the perl and python3 runtime libraries come with it.

## Trust class

`internal`. The build leg verifies the `ubi9-minimal` base against the release key of the sibling repository, as for every built image. The PGDG signature is checked by the package rules of the policy, not by a trust class.

## Enforcement

See `versions.json` for the current value. The image started in `observe` on 2026-11-14, as step 5 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md) requires. The first review of PR #55 gave both legs **PASS**, namespace `trusted`, 0 blocking and 14 waived (`EXC-2026-0041`). Thus the same PR moved the image to `enforce`, as step 7 allows.

## Why the key is postgresql17

* A package entry has one implicit variant, `runtime`, like a build entry. Thus "postgresql with a 17 variant" is not available.
* One repository for each major makes a major upgrade impossible to receive by accident. A PostgreSQL 17 data directory cannot be read by PostgreSQL 18. A major upgrade is a dump and a restore, never a tag move.
* The name follows Red Hat (`rhel9/postgresql-17`) and does not collide with the mirror key `postgres`.

## Interface

| Item | Value |
|---|---|
| Image | `ghcr.io/infrashift/trusted-service-containers/trusted/postgresql17:<version>` (for example `17.12`), also `<version>-<shortsha>` and `<version>-<YYYYMMDD>` |
| User | UID 26, the RHEL `postgres` user. Its primary group is GID 0. The image never needs root, and the entrypoint refuses to start as root. |
| Port | 5432. `PGPORT` changes it for the server, the initdb pass and `psql`. |
| Volume | `/var/lib/pgsql/data`, owned by `26:0`, mode `0770` |
| Data directory | `PGDATA=/var/lib/pgsql/data/userdata`, as in the Red Hat images. The entrypoint creates it with mode `0700`. |
| Entrypoint | `docker-entrypoint.sh`, command `postgres`. A first argument that starts with `-` goes to `postgres`. |
| Stop signal | `SIGINT`, the PostgreSQL fast shutdown |
| Client tools | `psql`, `pg_isready`, `createdb`, `pg_dump` and the others, on `PATH` from `/usr/pgsql-17/bin` |
| Locale | The PostgreSQL 17 builtin provider, `C.UTF-8`. The order of text does not depend on the glibc of the image. |

### Environment

The entrypoint keeps the contract of the Docker official and DHI postgres images.

| Variable | Use |
|---|---|
| `POSTGRES_PASSWORD` or `POSTGRES_PASSWORD_FILE` | The superuser password. Required on an empty data directory, unless `POSTGRES_HOST_AUTH_METHOD=trust`. |
| `POSTGRES_USER` | The superuser that initdb creates. The default is `postgres`. |
| `POSTGRES_DB` | The database to create after initdb. The default is `POSTGRES_USER`. |
| `POSTGRES_INITDB_ARGS` | More initdb arguments. |
| `POSTGRES_HOST_AUTH_METHOD` | The `pg_hba.conf` method for TCP clients. The default is `scram-sha-256`. |

* A client in the container connects through the local socket with `trust`. Thus `podman exec ... psql -U postgres` works without a password.
* The entrypoint runs `/docker-entrypoint-initdb.d/*.sh`, `*.sql` and `*.sql.gz` once, after initdb.
* During initdb, the temporary server listens on no TCP port and on a private socket directory. A readiness probe (`psql` or `pg_isready`) thus fails until the real server starts. The Docker images answer the probe during initdb, and then stop that server.
* The server logs to stderr. The PGDG sample configuration writes log files under `PGDATA`; the entrypoint turns that off.

## What each consumer changes

Both consumers use the DHI image `postgres:17-debian` today.

WARNING: A data directory from the DHI image cannot be mounted in this image. The DHI image runs as UID 70 and uses a glibc `en_US.UTF-8` collation. Do a dump and a restore into a new volume, or start from an empty volume.

### HALO

1. `scripts/tsc-image.sh`: add the kind `package`. Read the version from `.images.postgresql17.packages.version`, not from `.sources`. The tags have the same shape as the build track.
2. `scripts/test-integration.sh`: use `tsc-image.sh postgresql17 runtime`. The environment, the `-p 127.0.0.1::5432` mapping and the `podman exec ... psql -U postgres` probe stay the same.
3. `deploy/dev/halo-dev-db.kube.yml`: change `mountPath` from `/var/lib/postgresql/17/data` to `/var/lib/pgsql/data`. `PGPORT=5442` and `-c listen_addresses=127.0.0.1` work unchanged.
4. Create the volume `halo-dev-pgdata` again, or dump and restore it. `deploy/dev/postgres/bootstrap.sql` creates the roles and databases again.

### Chit

1. `deploy/chit.kube.yml`, `deploy/chit-uat.kube.yml` and `PG_IMAGE` in the `Makefile`: use the postgresql17 image.
2. Change the `mountPath` of `chit-pgdata` from `/var/lib/postgresql/17/data` to `/var/lib/pgsql/data`.
3. The `wait-postgres` and `ensure-databases` init containers work unchanged: the image has `sh`, `pg_isready`, `psql`, `createdb` and `grep`.
4. Move the data of `chit-pgdata` with a dump and a restore.

## Verification on 2026-11-14

* A local amd64 buildah build, then a scan. See [The first postgresql17 scan found no Critical and 14 krb5-libs Highs on 2026-11-14](/findings/the-first-postgresql17-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-14--01a1dd2247cf.md).
* A smoke test: initdb from the environment, `SELECT version()`, UID 26 and GID 0, a TCP login with a password, `CREATE EXTENSION pgcrypto`, a restart on the same volume, and the data still there. The entrypoint refused `--user 0`.
* The HALO integration tests and the Chit PostgreSQL integration tests passed against this image.

## Issues and waivers

Open issues:

* [The UBI repositories do not yet carry the krb5-libs fix for 14 Highs in postgresql17](/issues/the-ubi-repositories-do-not-yet-carry-the-krb5-libs-fix-for-14-highs-in-postgresql17--01a1dd21edb8.md) (`EXC-2026-0041`)
* [The DHI postgres and traefik images have Debian base findings that only Docker can clear](/issues/the-dhi-postgres-and-traefik-images-have-debian-base-findings-that-only-docker-can-clear--01a1838a11fc.md): this image is the replacement.

## Related

* [ADR-009: A package build installs signed RPMs at pinned NEVRAs](/decisions/adr-009-a-package-build-installs-signed-rpms-at-pinned-nevras--01a1dd2247a6.md)
* [postgres](/images/postgres--01a183832d06.md): the DHI mirror that this image replaces.
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Release tags and manifest lists](/architecture/release-tags-and-manifest-lists--01a18382f392.md)
* [Images overview](/images/images-overview--01a1837da526.md)
