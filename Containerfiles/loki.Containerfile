# Trusted Loki
#
# Three stages, and every one of them exists for a verified reason:
#
#   builder — compiles loki AND logcli from the pinned source COMMIT with
#             upstream's Makefile tags and ldflags (GO_FLAGS at v3.7.8).
#
#   certs   — CA trust donor. ubi9-micro ships NO /etc/pki/ca-trust of any kind.
#             Loki makes outbound TLS calls to object stores, and logcli to any
#             https:// Loki it is pointed at.
#
#   runtime — our trusted ubi9-micro. bash and coreutils but no package manager,
#             so the passwd entry is appended by hand.
#
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
ARG TARGETARCH

WORKDIR /src
# Placed in the build context by scripts/fetch-source.sh (pinned COMMIT, tag
# asserted to resolve to it).
COPY src/loki/ /src/

# GOTOOLCHAIN=local: go.mod asks for go 1.26.5 and the pinned toolchain image
# (1.26.6, the patch upstream's own Dockerfile uses) satisfies it. `local` makes
# a future go.mod that wants more fail the build instead of silently
# downloading an unpinned compiler.
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOTOOLCHAIN=local

# Version is the ref without its v: upstream's tools/image-tag strips it and the
# vendor binary reports 3.7.8. Revision is the pinned shortCommit (the vendor
# stamps git's dynamic abbreviation, 8 characters here). BuildDate is the
# source COMMIT date, never wall-clock, so a rerun stamps the same string.
#
# -trimpath is ours, not upstream's. -s -w is upstream's.
#
# The final `-version` greps are the guard for the failure that matters: an
# ldflags path that no longer matches pkg/util/build still links, and the binary
# then reports an empty version that no consumer would notice.
RUN set -euo pipefail; \
    LDFLAGS="-s -w -X github.com/grafana/loki/v3/pkg/util/build.Version=${SOURCE_VERSION#v} \
      -X github.com/grafana/loki/v3/pkg/util/build.Revision=${SOURCE_SHORT_REF} \
      -X github.com/grafana/loki/v3/pkg/util/build.Branch=HEAD \
      -X github.com/grafana/loki/v3/pkg/util/build.BuildUser=infrashift@trusted-service-containers \
      -X github.com/grafana/loki/v3/pkg/util/build.BuildDate=$(date -u -d "${SOURCE_DATE}" +%Y-%m-%dT%H:%M:%SZ)"; \
    GOARCH="${TARGETARCH}" go build -trimpath -tags=netgo \
      -ldflags="${LDFLAGS}" -o /out/loki ./cmd/loki ; \
    GOARCH="${TARGETARCH}" go build -trimpath -tags=netgo \
      -ldflags="${LDFLAGS}" -o /out/logcli ./cmd/logcli ; \
    /out/loki -version | grep -q "version ${SOURCE_VERSION#v} (branch: HEAD, revision: ${SOURCE_SHORT_REF})"; \
    /out/logcli --version 2>&1 | grep -q "version ${SOURCE_VERSION#v} "

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
      org.opencontainers.image.title="Trusted Loki" \
      org.opencontainers.image.description="Grafana Loki log store and logcli, built from source on trusted UBI9 Micro" \
      org.opencontainers.image.maintainer="Ryan Craig <ryan.craig@infrashift.io>" \
      org.opencontainers.image.vendor="Infrashift" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.architecture="${TARGETARCH}" \
      io.infrashift.image.variant="ubi9-micro" \
      io.infrashift.build.recipe.revision="${GIT_COMMIT}" \
      io.infrashift.build.toolchain="${TOOLCHAIN_BASE}@${TOOLCHAIN_DIGEST}" \
      io.infrashift.build.ca.source="${CA_BASE}@${CA_DIGEST}" \
      io.infrashift.build.crosscheck.image="${CROSSCHECK_IMAGE}@${CROSSCHECK_DIGEST}" \
      io.openshift.tags="loki,logging,logs,ubi9,vetted"

USER root

COPY --from=certs /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ubi9-micro ships no /usr/share/zoneinfo; logcli's --timezone and LogQL's
# date functions call time.LoadLocation().
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/loki /usr/bin/loki
COPY --from=builder /out/logcli /usr/bin/logcli

# Upstream's container config and the licence files, from the pinned source
# tree. The config is single-binary filesystem storage under /loki, so the image
# runs standalone the way docker.io/grafana/loki does; deployments mount their own.
COPY --from=builder /src/cmd/loki/loki-docker-config.yaml /etc/loki/local-config.yaml
COPY --from=builder /src/LICENSE /src/LICENSING.md /usr/share/licenses/loki/

# Passwd entry appended (no shadow-utils). GID 0 plus `chmod g=u` keeps the
# image usable under OpenShift's arbitrary-UID SCC. /loki holds chunks, the
# TSDB index, the WAL and the compactor's working directory.
RUN set -euo pipefail; \
    test -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; \
    test "$(stat -c %s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)" -gt 100000; \
    printf 'loki:x:1001:0:Trusted Loki service account:/loki:/sbin/nologin\n' >> /etc/passwd; \
    mkdir -p /etc/pki/tls/certs /etc/ssl /loki /etc/loki; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; \
    /usr/bin/loki -verify-config -config.file=/etc/loki/local-config.yaml; \
    chown -R 1001:0 /loki /etc/loki; \
    chmod -R g=u /loki /etc/loki

ENV HOME=/loki \
    SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    TZ=UTC

WORKDIR /loki

# EXPOSE is metadata only. 3100 is above 1024, so USER 1001 needs no capability.
EXPOSE 3100

# Without a persistent mount, every restart loses all stored logs -- silently.
VOLUME /loki

ENTRYPOINT ["loki"]
CMD ["-config.file=/etc/loki/local-config.yaml"]

USER 1001
