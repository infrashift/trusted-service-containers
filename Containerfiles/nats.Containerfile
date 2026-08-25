# Trusted NATS Server
#
# Three stages, and every one of them exists for a verified reason:
#
#   builder — compiles from the pinned source COMMIT with the flags the vendor's
#             release pipeline uses. NOT the flags in the upstream repo's
#             .docker/Dockerfile-build: that is a dev build and does not match
#             anything the vendor publishes (hydra has no such file at all, and
#             keto's sets CGO_ENABLED=1).
#
#   certs   — CA trust donor. ubi9-micro ships NO /etc/pki/ca-trust of any kind
#             (verified by listing the layer: all four paths Go's crypto/x509
#             probes are absent). Without this stage every outbound TLS call
#             fails with `x509: certificate signed by unknown authority`.
#
#   runtime — our trusted ubi9-micro. It has bash and coreutils but no package
#             manager, so RUN works and the passwd entry is appended by hand
#             rather than created with useradd.
#
# Generated once for shape consistency and hand-maintained since.
# scripts/lint-containerfiles.sh enforces the invariants.

ARG UPSTREAM_BASE
ARG UPSTREAM_DIGEST
ARG CA_BASE
ARG CA_DIGEST
ARG TOOLCHAIN_BASE
ARG TOOLCHAIN_DIGEST

########################  builder  ########################
FROM ${TOOLCHAIN_BASE}@${TOOLCHAIN_DIGEST} AS builder

ARG SOURCE_VERSION
ARG SOURCE_REF
ARG SOURCE_SHORT_REF
ARG SOURCE_DATE
ARG SOURCE_GIT_VERSION
ARG TARGETARCH

WORKDIR /src
# Placed in the build context by scripts/fetch-source.sh, which fetches the
# pinned COMMIT (not the tag), asserts the tag resolves to it, and then removes
# .git so `go build` cannot stamp a pseudo-version from a shallow clone.
COPY src/nats/ /src/

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOTOOLCHAIN=go1.26.6
# -trimpath is copied from upstream's .goreleaser.yml at the pinned tag, and so
# was GOTOOLCHAIN until 2026-08-24. Matching both is what made this the one
# service where a byte-identical cross-check against the vendor binary was
# realistic.
#
# GOTOOLCHAIN now deliberately diverges. Upstream pins go1.26.5, which carries
# GO-2026-5026, -5972, -6089 and -6090 -- four stdlib advisories, all High with a
# fix, all blocking under our policy. They are fixed in 1.26.6. v2.14.5 is the
# newest nats release, so there is no source bump that clears them; the only
# lever is the compiler.
#
# The cost is the cross-check, which compares our binary against the vendor's
# 1.26.5 build and will now differ. That comparison is explicitly an observation
# and not a gate -- provenance records it as such -- so trading it for four
# fixable Highs is the right way round. Restore the match by bumping this to
# whatever upstream's .goreleaser.yml pins once they move past 1.26.5.
#
# go1.26.6 is also exactly what the pinned toolchain image ships, so the build
# uses that image's compiler rather than downloading one.
RUN set -euo pipefail; \
    GOARCH="${TARGETARCH}" go build -trimpath \
      -ldflags="-w \
        -X 'github.com/nats-io/nats-server/v2/server.serverVersion=${SOURCE_VERSION}' \
        -X 'github.com/nats-io/nats-server/v2/server.gitCommit=${SOURCE_SHORT_REF}'" \
      -o /out/nats-server . ; \
    /out/nats-server --version

########################  certs  ##########################
FROM ${CA_BASE}@${CA_DIGEST} AS certs

########################  runtime  ########################
FROM ${UPSTREAM_BASE}@${UPSTREAM_DIGEST}

# Re-declared after FROM. ARGs before the first FROM are global build args and
# are NOT in scope inside a build stage, so the LABELs below would silently
# expand to empty strings. The policy's BUILD_LABEL_EMPTY rule exists to catch
# exactly this regression.
ARG UPSTREAM_BASE
ARG UPSTREAM_DIGEST
ARG CA_BASE
ARG CA_DIGEST
ARG TOOLCHAIN_BASE
ARG TOOLCHAIN_DIGEST
ARG SOURCE_URL
ARG SOURCE_VERSION
ARG SOURCE_REF
ARG CROSSCHECK_IMAGE
ARG CROSSCHECK_DIGEST
ARG IMAGE_VERSION
ARG BUILD_DATE
ARG TARGETARCH
ARG GIT_COMMIT

# The first five are REQUIRED by .github/pdp/policies.rego on the build track.
LABEL org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.revision="${SOURCE_REF}" \
      org.opencontainers.image.version="${SOURCE_VERSION}" \
      io.infrashift.image.upstream.digest="${UPSTREAM_DIGEST}" \
      io.infrashift.image.upstream.source="${UPSTREAM_BASE}" \
      org.opencontainers.image.title="Trusted NATS Server" \
      org.opencontainers.image.description="NATS messaging server with JetStream, built from source on trusted UBI9 Micro" \
      org.opencontainers.image.maintainer="Ryan Craig <ryan.craig@infrashift.io>" \
      org.opencontainers.image.vendor="Infrashift" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.architecture="${TARGETARCH}" \
      io.infrashift.image.variant="ubi9-micro" \
      io.infrashift.build.recipe.revision="${GIT_COMMIT}" \
      io.infrashift.build.toolchain="${TOOLCHAIN_BASE}@${TOOLCHAIN_DIGEST}" \
      io.infrashift.build.ca.source="${CA_BASE}@${CA_DIGEST}" \
      io.infrashift.build.crosscheck.image="${CROSSCHECK_IMAGE}@${CROSSCHECK_DIGEST}" \
      io.openshift.tags="nats,messaging,jetstream,ubi9,vetted"

USER root

# Go's crypto/x509 probes a fixed path list. The bundle plus the two
# conventional symlinks covers Go, OpenSSL consumers and SSL_CERT_FILE.
COPY --from=certs /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ubi9-micro ships no /usr/share/zoneinfo and no /etc/localtime, but the
# upstream images this replaces all do. Without it time.LoadLocation() fails
# for anything but UTC.
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/nats-server /usr/bin/nats-server

# Our config, committed and CODEOWNER-covered. Upstream's ships a cluster
# block with hardcoded credentials (ruser / T0pS3cr3t).
COPY rootfs/nats/etc/nats/nats-server.conf /etc/nats/nats-server.conf

# ubi9-micro has bash and coreutils but no shadow-utils, so the passwd entry is
# appended rather than created with useradd. Without a UID 1001 entry, os/user
# lookups return "unknown userid" and $HOME is undefined.
# GID 0 plus `chmod g=u` keeps the image usable under OpenShift's arbitrary-UID
# SCC, which runs the container as a random UID in group 0.
RUN set -euo pipefail; \
    test -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; \
    test "$(stat -c %s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)" -gt 100000; \
    printf 'nats:x:1001:0:Trusted NATS Server service account:/home/nats:/sbin/nologin\n' >> /etc/passwd; \
    mkdir -p /etc/pki/tls/certs /etc/ssl /home/nats /var/lib/nats /etc/nats; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; \
    ln -sf /usr/bin/nats-server /nats-server; \
    chown -R 1001:0 /home/nats /var/lib/nats /etc/nats; \
    chmod -R g=u /home/nats /var/lib/nats /etc/nats

ENV HOME=/home/nats \
    SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    TZ=UTC

WORKDIR /home/nats

# EXPOSE is metadata only: it binds nothing and grants nothing. All ports here
# are above 1024, so USER 1001 needs no capability to bind them.
EXPOSE 4222 8222 6222

# JetStream state. Without a persistent mount, streams and consumers are lost
# on restart, and the failure is silent until something restarts.
VOLUME /var/lib/nats

ENTRYPOINT ["nats-server"]
CMD ["--config", "/etc/nats/nats-server.conf"]

USER 1001
