# Trusted Valkey
#
# A NATIVE build (ADR-010), language c. Valkey is C, and the build track
# compiles only static Go binaries. No free signed EL9 repository ships Valkey,
# so this file compiles the pinned source commit on a pinned UBI builder:
#
#   * The builder is the pinned ubi9-minimal base. gcc, make and the OpenSSL
#     headers come from the Red Hat signed UBI repositories, with the gpgcheck
#     the base image configures. No third-party repository exists here.
#   * The source is the pinned 40-hex commit. scripts/build-leg.sh has already
#     compared its file tree with the release archive that versions.json pins
#     by the sha256 of valkey-io/valkey-hashes (scripts/fetch-archive.sh).
#   * BUILD_TLS=yes links the OpenSSL of UBI dynamically. HALO needs TLS.
#   * The runtime is ubi9-minimal too: it ships libssl and libcrypto, which
#     ubi9-micro does not, and its CA trust bundle.
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

COPY src/valkey/ /src/valkey/
WORKDIR /src/valkey

# SOURCE_DATE_EPOCH (the committer date of the pinned commit) replaces the
# wall-clock build id that src/mkreleasehdr.sh would stamp. The .git directory
# is removed first, so the release header carries no local git state.
# valkey-check-aof, valkey-check-rdb and valkey-sentinel are the server binary
# under other names; the runtime stage links them instead of shipping three
# more copies. --strip-debug drops the DWARF data (about 15 MB per binary) and
# keeps the symbol table that the Valkey crash report prints.
RUN set -euo pipefail; \
    rm -rf .git; \
    export SOURCE_DATE_EPOCH="$(date -u -d "${SOURCE_DATE}" +%s)"; \
    make -j"$(nproc)" BUILD_TLS=yes USE_SYSTEMD=no MALLOC=jemalloc V=1; \
    make install PREFIX=/out/usr BUILD_TLS=yes USE_SYSTEMD=no MALLOC=jemalloc USE_REDIS_SYMLINKS=no; \
    strip --strip-debug /out/usr/bin/valkey-server /out/usr/bin/valkey-cli /out/usr/bin/valkey-benchmark; \
    ls -l /out/usr/bin

# Smoke test in the builder: a TLS PING with a throwaway self-signed key that
# never leaves this stage.
RUN set -euo pipefail; \
    /out/usr/bin/valkey-server --version; \
    tls=/tmp/tls; mkdir -p "$tls"; \
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost \
      -keyout "$tls/key" -out "$tls/cert" 2>/dev/null; \
    /out/usr/bin/valkey-server --port 0 --tls-port 6380 --tls-cert-file "$tls/cert" \
      --tls-key-file "$tls/key" --tls-ca-cert-file "$tls/cert" --tls-auth-clients no \
      --save "" --appendonly no --daemonize yes --logfile /tmp/tls.log; \
    for _ in $(seq 1 50); do \
      out="$(/out/usr/bin/valkey-cli --tls --cacert "$tls/cert" -p 6380 PING 2>/dev/null || true)"; \
      [ "$out" = "PONG" ] && break; sleep 0.1; \
    done; \
    test "$out" = "PONG" || { cat /tmp/tls.log >&2; echo "TLS PING failed" >&2; exit 1; }; \
    /out/usr/bin/valkey-cli --tls --cacert "$tls/cert" -p 6380 SHUTDOWN NOSAVE || true; \
    rm -rf "$tls"; \
    echo "TLS PING: PONG"

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
      org.opencontainers.image.title="Trusted Valkey" \
      org.opencontainers.image.description="Valkey compiled from a pinned commit with TLS on trusted UBI9 Minimal" \
      org.opencontainers.image.maintainer="Ryan Craig <ryan.craig@infrashift.io>" \
      org.opencontainers.image.vendor="Infrashift" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="BSD-3-Clause" \
      org.opencontainers.image.architecture="${TARGETARCH}" \
      io.infrashift.image.variant="ubi9-minimal" \
      io.infrashift.build.recipe.revision="${GIT_COMMIT}" \
      io.infrashift.build.native.builder="${BUILDER_BASE}@${BUILDER_DIGEST}" \
      io.infrashift.build.native.archive.sha256="${ARCHIVE_SHA256}" \
      io.openshift.tags="valkey,cache,key-value,ubi9,vetted"

USER root

# Upgrade the base from the Red Hat signed UBI repositories, so the runtime
# libraries (openssl-libs above all) are the newest that UBI publishes.
RUN set -euo pipefail; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 upgrade; \
    microdnf clean all

COPY --from=builder /out/usr/bin/valkey-server /usr/bin/valkey-server
COPY --from=builder /out/usr/bin/valkey-cli /usr/bin/valkey-cli
COPY --from=builder /out/usr/bin/valkey-benchmark /usr/bin/valkey-benchmark
COPY rootfs/valkey/ /

# UID 1001 with primary GID 0, as in the Go images: with `chmod g=u` the data
# directory also works under OpenShift's arbitrary-UID SCC. ubi9-minimal has
# no useradd, so the entry is appended.
#
# Then the runtime smoke test: the binary links the OpenSSL of UBI, starts
# with persistence off, and answers PING.
RUN set -euo pipefail; \
    echo "valkey:x:1001:0:Valkey:/data:/sbin/nologin" >> /etc/passwd; \
    for n in valkey-check-aof valkey-check-rdb valkey-sentinel; do ln -s valkey-server "/usr/bin/$n"; done; \
    mkdir -p /data; \
    chown -R 1001:0 /data /etc/valkey; \
    chmod -R g=u /data /etc/valkey; \
    valkey-server --version; \
    ldd /usr/bin/valkey-server | grep -q 'libssl\.so\.3'; \
    valkey-server /etc/valkey/valkey.conf --save "" --appendonly no --daemonize yes --logfile /tmp/smoke.log --dir /tmp; \
    for _ in $(seq 1 50); do \
      out="$(valkey-cli PING 2>/dev/null || true)"; [ "$out" = "PONG" ] && break; sleep 0.1; \
    done; \
    test "$out" = "PONG" || { cat /tmp/smoke.log >&2; echo "PING failed" >&2; exit 1; }; \
    test "$(valkey-cli CONFIG GET save | sed -n 2p)" = ""; \
    test "$(valkey-cli CONFIG GET appendonly | sed -n 2p)" = "no"; \
    valkey-cli SHUTDOWN NOSAVE || true; \
    rm -f /tmp/smoke.log; \
    echo "runtime PING: PONG, persistence off"

ENV HOME=/data \
    LANG=C.UTF-8 \
    TZ=UTC

WORKDIR /data

# EXPOSE is metadata only. 6379 is above 1024, so UID 1001 needs no capability.
EXPOSE 6379

VOLUME /data

ENTRYPOINT ["valkey-server", "/etc/valkey/valkey.conf"]

USER 1001
