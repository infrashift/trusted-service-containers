# Trusted PgBouncer
#
# A NATIVE build (ADR-010), language c. PgBouncer is C, and the build track
# compiles only static Go binaries. The PGDG EL9 RPM requires c-ares, which no
# UBI 9 or PGDG repository ships, so the package kind cannot install it. This
# file compiles the pinned source commit on a pinned UBI builder:
#
#   * The builder is the pinned ubi9-minimal base. gcc, make, the autotools,
#     and the libevent and OpenSSL headers come from the Red Hat signed UBI
#     repositories, with the gpgcheck the base image configures. No
#     third-party repository exists here.
#   * The source is the pinned 40-hex commit. scripts/build-leg.sh has already
#     compared its file tree with the release archive that versions.json pins
#     by sha256 (scripts/fetch-archive.sh).
#   * --with-openssl links the OpenSSL of UBI dynamically: HALO needs
#     client_tls_* and server_tls_*. DNS uses libevent (evdns), not c-ares.
#   * The runtime is ubi9-minimal too: it ships libevent, libssl and
#     libcrypto, which ubi9-micro does not, and its CA trust bundle.
#
# scripts/lint-containerfiles.sh enforces the shape.

ARG BUILDER_BASE
ARG BUILDER_DIGEST
ARG UPSTREAM_BASE
ARG UPSTREAM_DIGEST

# ---------------------------------------------------------------------------
# Stage 1: compile, install into /out, and prove TLS works.
# ---------------------------------------------------------------------------
FROM ${BUILDER_BASE}@${BUILDER_DIGEST} AS builder

ARG BUILD_PACKAGES
ARG SOURCE_DATE

USER root

# Signed UBI packages only. The base image's own repository files keep
# gpgcheck=1 and the Red Hat key; nothing here touches them.
RUN set -euo pipefail; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 install ${BUILD_PACKAGES}; \
    microdnf clean all

COPY src/pgbouncer/ /src/pgbouncer/
WORKDIR /src/pgbouncer

# The commit carries no configure script: ./autogen.sh generates it with the
# UBI autotools, as the vendor's `make dist` does. SOURCE_DATE_EPOCH is the
# committer date of the pinned commit. The .git directory is removed first.
# The compiler and linker flags are the arch-neutral part of the RHEL
# hardening set: FORTIFY, stack protector, stack-clash protection, PIE and
# full RELRO. Only the `pgbouncer` target is built and installed: the default
# target and `make install` also build the man pages, and pandoc is not in
# UBI. --strip-debug drops the DWARF data and keeps the symbol table.
RUN set -euo pipefail; \
    rm -rf .git; \
    export SOURCE_DATE_EPOCH="$(date -u -d "${SOURCE_DATE}" +%s)"; \
    ./autogen.sh; \
    ./configure --prefix=/usr --with-openssl --without-cares --without-pam --without-ldap --without-systemd \
      CFLAGS="-O2 -g -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -fPIE" \
      LDFLAGS="-pie -Wl,-z,relro -Wl,-z,now"; \
    make -j"$(nproc)" V=1 pgbouncer; \
    install -D -m 0755 pgbouncer /out/usr/bin/pgbouncer; \
    strip --strip-debug /out/usr/bin/pgbouncer; \
    ls -l /out/usr/bin

# Smoke test in the builder, as UID 1001 (PgBouncer refuses root): the
# version names OpenSSL and evdns, and a client that requires TLS completes
# the PostgreSQL SSLRequest handshake. The throwaway self-signed key is made
# in /tmp of this stage and never leaves it.
USER 1001
RUN set -euo pipefail; \
    ver="$(/out/usr/bin/pgbouncer --version)"; echo "$ver"; \
    grep -q '^PgBouncer 1\.' <<<"$ver"; \
    grep -q '^tls: OpenSSL 3\.' <<<"$ver"; \
    grep -q '^adns: evdns' <<<"$ver"; \
    tls="$(mktemp -d)"; \
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost \
      -keyout "$tls/key" -out "$tls/cert" 2>/dev/null; \
    printf '[databases]\nsmoke = host=127.0.0.1 port=5432 dbname=smoke\n[pgbouncer]\nlisten_addr = 127.0.0.1\nlisten_port = 6432\nunix_socket_dir =\nauth_type = scram-sha-256\nauth_file = %s/users\nclient_tls_sslmode = require\nclient_tls_key_file = %s/key\nclient_tls_cert_file = %s/cert\nlogfile = %s/log\n' \
      "$tls" "$tls" "$tls" "$tls" > "$tls/pgbouncer.ini"; \
    : > "$tls/users"; \
    /out/usr/bin/pgbouncer "$tls/pgbouncer.ini" & pid=$!; \
    out=""; \
    for _ in $(seq 1 50); do \
      out="$(openssl s_client -starttls postgres -connect 127.0.0.1:6432 -brief </dev/null 2>&1 || true)"; \
      grep -q 'CONNECTION ESTABLISHED' <<<"$out" && break; sleep 0.1; \
    done; \
    kill "$pid"; wait "$pid" || true; \
    grep -q 'CONNECTION ESTABLISHED' <<<"$out" || { echo "$out" >&2; cat "$tls/log" >&2; echo "TLS handshake failed" >&2; exit 1; }; \
    grep 'Protocol version' <<<"$out"; \
    rm -rf "$tls"; \
    echo "TLS handshake: established"

# ---------------------------------------------------------------------------
# Stage 2: runtime on the pinned ubi9-minimal.
# ---------------------------------------------------------------------------
FROM ${UPSTREAM_BASE}@${UPSTREAM_DIGEST}

# Re-declared after FROM. ARGs before the first FROM are global build args and
# are NOT in scope inside a build stage, so the LABELs below would silently
# expand to empty strings. The policy's BUILD_LABEL_EMPTY rule catches this.
ARG UPSTREAM_BASE
ARG UPSTREAM_DIGEST
ARG BUILDER_BASE
ARG BUILDER_DIGEST
ARG SOURCE_URL
ARG SOURCE_REF
ARG SOURCE_VERSION
ARG ARCHIVE_SHA256
ARG BUILD_DATE
ARG TARGETARCH
ARG GIT_COMMIT

# The first five are REQUIRED by .github/pdp/policies.rego.
LABEL org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.revision="${SOURCE_REF}" \
      org.opencontainers.image.version="${SOURCE_VERSION}" \
      io.infrashift.image.upstream.digest="${UPSTREAM_DIGEST}" \
      io.infrashift.image.upstream.source="${UPSTREAM_BASE}" \
      org.opencontainers.image.title="Trusted PgBouncer" \
      org.opencontainers.image.description="PgBouncer compiled from a pinned commit with OpenSSL on trusted UBI9 Minimal" \
      org.opencontainers.image.maintainer="Ryan Craig <ryan.craig@infrashift.io>" \
      org.opencontainers.image.vendor="Infrashift" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="ISC" \
      org.opencontainers.image.architecture="${TARGETARCH}" \
      io.infrashift.image.variant="ubi9-minimal" \
      io.infrashift.build.recipe.revision="${GIT_COMMIT}" \
      io.infrashift.build.native.builder="${BUILDER_BASE}@${BUILDER_DIGEST}" \
      io.infrashift.build.native.archive.sha256="${ARCHIVE_SHA256}" \
      io.openshift.tags="pgbouncer,postgresql,connection-pooler,ubi9,vetted"

USER root

# Upgrade the base from the Red Hat signed UBI repositories, so the runtime
# libraries (openssl-libs and libevent above all) are the newest that UBI
# publishes.
RUN set -euo pipefail; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 upgrade; \
    microdnf clean all

COPY --from=builder /out/usr/bin/pgbouncer /usr/bin/pgbouncer
COPY rootfs/pgbouncer/ /

# UID 1001 with primary GID 0, as in the Go images: with `chmod g=u` the
# paths also work under OpenShift's arbitrary-UID SCC. ubi9-minimal has no
# useradd, so the entry is appended. The binary links the libevent and the
# OpenSSL of UBI.
RUN set -euo pipefail; \
    echo "pgbouncer:x:1001:0:PgBouncer:/var/lib/pgbouncer:/sbin/nologin" >> /etc/passwd; \
    mkdir -p /var/lib/pgbouncer; \
    chown -R 1001:0 /var/lib/pgbouncer /etc/pgbouncer; \
    chmod -R g=u /var/lib/pgbouncer /etc/pgbouncer; \
    pgbouncer --version; \
    ldd /usr/bin/pgbouncer | grep -q 'libssl\.so\.3'; \
    ldd /usr/bin/pgbouncer | grep -q 'libevent-2\.1\.so'; \
    if ldd /usr/bin/pgbouncer | grep -q 'not found'; then ldd /usr/bin/pgbouncer >&2; exit 1; fi

# The runtime smoke test, as the runtime user: PgBouncer starts with the
# shipped configuration and accepts TCP connections on 6432.
USER 1001
RUN set -euo pipefail; \
    pgbouncer /etc/pgbouncer/pgbouncer.ini 2>/tmp/smoke.log & pid=$!; \
    ok=no; \
    for _ in $(seq 1 50); do \
      if (exec 3<>/dev/tcp/127.0.0.1/6432) 2>/dev/null; then ok=yes; break; fi; sleep 0.1; \
    done; \
    kill "$pid"; wait "$pid" || true; \
    test "$ok" = yes || { cat /tmp/smoke.log >&2; echo "pgbouncer did not listen on 6432" >&2; exit 1; }; \
    rm -f /tmp/smoke.log; \
    echo "runtime: listening on 6432 as $(id -u):$(id -g)"

ENV HOME=/var/lib/pgbouncer \
    LANG=C.UTF-8 \
    TZ=UTC

WORKDIR /var/lib/pgbouncer

# EXPOSE is metadata only. 6432 is above 1024, so UID 1001 needs no capability.
EXPOSE 6432

ENTRYPOINT ["pgbouncer"]
CMD ["/etc/pgbouncer/pgbouncer.ini"]

USER 1001
