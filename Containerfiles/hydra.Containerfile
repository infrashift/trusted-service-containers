# Trusted Ory Hydra
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
COPY src/hydra/ /src/

ENV CGO_ENABLED=0 \
    GOOS=linux
RUN set -euo pipefail; \
    GOARCH="${TARGETARCH}" go build -tags=json1 \
      -ldflags="-s -w \
        -X 'github.com/ory/hydra/v2/driver/config.Version=${SOURCE_VERSION}' \
        -X 'github.com/ory/hydra/v2/driver/config.Commit=${SOURCE_REF}' \
        -X 'github.com/ory/hydra/v2/driver/config.Date=${SOURCE_DATE}'" \
      -o /out/hydra . ; \
    /out/hydra version

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
      org.opencontainers.image.title="Trusted Ory Hydra" \
      org.opencontainers.image.description="Ory Hydra OAuth2 and OpenID Connect server, built from source on trusted UBI9 Micro" \
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
      io.openshift.tags="ory,hydra,oauth2,oidc,ubi9,vetted"

USER root

# Go's crypto/x509 probes a fixed path list. The bundle plus the two
# conventional symlinks covers Go, OpenSSL consumers and SSL_CERT_FILE.
COPY --from=certs /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ubi9-micro ships no /usr/share/zoneinfo and no /etc/localtime, but the
# upstream images this replaces all do. Without it time.LoadLocation() fails
# for anything but UTC.
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/hydra /usr/bin/hydra

# ubi9-micro has bash and coreutils but no shadow-utils, so the passwd entry is
# appended rather than created with useradd. Without a UID 1001 entry, os/user
# lookups return "unknown userid" and $HOME is undefined.
# GID 0 plus `chmod g=u` keeps the image usable under OpenShift's arbitrary-UID
# SCC, which runs the container as a random UID in group 0.
RUN set -euo pipefail; \
    test -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; \
    test "$(stat -c %s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)" -gt 100000; \
    printf 'ory:x:1001:0:Trusted Ory Hydra service account:/home/ory:/sbin/nologin\n' >> /etc/passwd; \
    mkdir -p /etc/pki/tls/certs /etc/ssl /home/ory; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; \
    chown -R 1001:0 /home/ory; \
    chmod -R g=u /home/ory

ENV HOME=/home/ory \
    SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    TZ=UTC

WORKDIR /home/ory

# EXPOSE is metadata only: it binds nothing and grants nothing. All ports here
# are above 1024, so USER 1001 needs no capability to bind them.
EXPOSE 4444 4445

ENTRYPOINT ["hydra"]
CMD ["serve", "all"]

USER 1001
