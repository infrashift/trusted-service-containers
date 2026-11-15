---
id: "01a1df5f-8878-74da-a246-df8a2c754412"
title: "valkey"
type: "image"
tags:
  - "image"
  - "valkey"
  - "native"
created: "2026-11-15T07:22:22-06:00"
timestamp: "2026-11-15T07:22:22-06:00"
status: "draft"
resource: "https://github.com/infrashift/trusted-service-containers/blob/main/Containerfiles/valkey.Containerfile"
sources:
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/rootfs/valkey/etc/valkey/valkey.conf"
    title: "rootfs/valkey/etc/valkey/valkey.conf"
  - resource: "https://github.com/valkey-io/valkey-hashes"
    title: "valkey-hashes"
  - resource: "https://github.com/infrashift/trusted-service-containers/blob/main/versions.json"
    title: "versions.json"
description: "Valkey 9.1 compiled with TLS from a pinned commit on UBI; native kind (ADR-010), UID 1001, protected mode on, persistence configurable off."
---

# valkey

valkey is the Valkey key-value server and its client tools. We compile the pinned Valkey source commit with TLS on a pinned UBI builder, and ship it on our own `ubi9-minimal`. It is the shared cache and state store of HALO, and the router and rate-limit store of LiteLLM.

## Track

Native track (kind `native`, language `c`). See [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md). No free signed EL9 repository ships Valkey, the vendor image has no signature, and the DHI image had two Debian Criticals with no fix. See [UBI 9 and EPEL 9 shipped no Valkey package on 2026-11-15](/findings/ubi-9-and-epel-9-shipped-no-valkey-package-on-2026-11-15--01a1dee755a1.md).

* **Source.** `sources.valkey` pins the 40-hex commit of the release tag. Valkey tags are lightweight and not signed.
* **Release archive.** `sources.valkey.archive` pins the sha256 of the release archive, from the separate repository `valkey-io/valkey-hashes`. `scripts/fetch-archive.sh` downloads the archive, checks the sha256, and fails the build unless the file tree of the archive equals the tree of the commit.
* **Builder.** The pinned `ubi9-minimal`. `gcc`, `make`, `openssl-devel`, `pkgconf-pkg-config` and `openssl` come from the Red Hat signed UBI repositories (`native.buildPackages`). The builder never reaches the image.
* **Build.** `make BUILD_TLS=yes USE_SYSTEMD=no MALLOC=jemalloc`. TLS links the OpenSSL of UBI dynamically. jemalloc and Lua come from the `deps/` tree of Valkey. `SOURCE_DATE_EPOCH` is the committer date of the commit. The binaries are stripped of debug data.
* **No vendor comparison.** The build records the sha256 of `/usr/bin/valkey-server` as a change detector. The vendor builds on Debian with another compiler and glibc, so a comparison would always differ.

## Trust class

`internal`. The build leg verifies the `ubi9-minimal` builder and runtime base against the release key of the sibling repository, as for every built image.

## Enforcement

See `versions.json` for the current value. The image starts in `observe`, as step 5 of [Add an upstream image](/operations/add-an-upstream-image--01a18383d9be.md) requires. For the first scan, see [The first valkey scan found no Critical and 14 krb5-libs Highs on 2026-11-15](/findings/the-first-valkey-scan-found-no-critical-and-14-krb5-libs-highs-on-2026-11-15--01a1df6016ea.md).

## Interface

| Item | Value |
|---|---|
| Image | `ghcr.io/infrashift/trusted-service-containers/trusted/valkey:<version>` (for example `9.1.3`), also `<version>-<shortsha>` and `<version>-<YYYYMMDD>` |
| User | UID 1001, primary group GID 0. `/data` and `/etc/valkey` are `g=u`, so an arbitrary UID in GID 0 also works. |
| Port | 6379 |
| Volume | `/data`, the working directory. RDB snapshots and the AOF directory go there. |
| Entrypoint | `valkey-server /etc/valkey/valkey.conf`. Arguments to the container are appended, so they override the file. |
| Binaries | `valkey-server`, `valkey-cli`, `valkey-benchmark`; `valkey-check-aof`, `valkey-check-rdb` and `valkey-sentinel` are links to `valkey-server`. No `redis-*` names. |
| TLS | Built in (`BUILD_TLS=yes`). Turn it on with `--tls-port`, `--tls-cert-file`, `--tls-key-file` and `--tls-ca-cert-file`, and `--port 0` for TLS only. |

### The configuration

`rootfs/valkey/etc/valkey/valkey.conf` is ours. Each setting that it does not name is the Valkey default.

* `bind * -::*` and port 6379: all interfaces, IPv6 when the host has it.
* `protected-mode yes`: with no password and no ACL user, Valkey refuses every client that is not on the loopback interface. To serve the network, set a password (`--requirepass`) or an ACL file. Do not turn protected mode off instead.
* `dir /data`, `logfile ""` (stdout), `daemonize no`, `supervised no`.
* Persistence has the Valkey defaults: RDB snapshots on, AOF off. To turn persistence off, add `--save "" --appendonly no`.

### Smoke tests

The Containerfile runs two tests:

1. In the builder: a TLS `PING` with a self-signed key that does not leave the builder stage.
2. In the runtime stage: `valkey-server --version`, a check that the binary links `libssl.so.3`, and a `PING` with persistence off (`CONFIG GET save` is empty).

## What HALO sets

* A password or an ACL file, because protected mode refuses remote clients without one.
* `--save "" --appendonly no` when the data is a cache that can be lost.
* TLS arguments and a certificate when traffic leaves the host.
* LiteLLM points its router and rate-limit store (`redis_host`, `redis_port`, `redis_password`) at this server. LiteLLM uses the `redis` Python client, which speaks the same protocol.

## Related

* [ADR-010: Valkey and LiteLLM build on UBI as the kind native](/decisions/adr-010-valkey-and-litellm-build-on-ubi-as-the-kind-native--01a1dee688b9.md)
* [Build track](/architecture/build-track--01a18382f2d2.md)
* [Images overview](/images/images-overview--01a1837da526.md)
