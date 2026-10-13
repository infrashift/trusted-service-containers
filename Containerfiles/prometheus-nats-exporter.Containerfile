# Trusted prometheus-nats-exporter
#
# Three stages, and every one of them exists for a verified reason:
#
#   builder — compiles the exporter from the pinned source COMMIT with
#             upstream's release flags (.goreleaser.yml at v0.20.2).
#
#   certs   — CA trust donor. ubi9-micro ships NO /etc/pki/ca-trust of any kind.
#             The exporter can poll an https:// NATS monitoring endpoint, and
#             can serve its own /metrics over TLS (-tlscert/-tlskey/-tlscacert).
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
ARG TARGETARCH

WORKDIR /src
# Placed in the build context by scripts/fetch-source.sh (pinned COMMIT, tag
# asserted to resolve to it).
COPY src/prometheus-nats-exporter/ /src/

# GOTOOLCHAIN=local: go.mod asks for go 1.25.10 and the pinned toolchain image
# satisfies it. The image's patch lives in versions.json
# (toolchains.go1.26.goVersion), never here: a comment naming it goes stale on
# the next security release. `local` makes a future go.mod that wants more fail
# the build instead of silently downloading an unpinned compiler.
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOTOOLCHAIN=local

# Flags are upstream's goreleaser build: -trimpath, -s -w, CGO_ENABLED=0.
# goreleaser also passes -X main.commit and -X main.date, but main.go at v0.20.2
# declares only `version`; the linker ignores -X for an undeclared symbol, so
# those two stamp nothing and are not reproduced here. Version is the ref
# WITHOUT its v (goreleaser's .Version; the vendor binary prints 0.20.2).
#
# The version check is the guard for the failure that matters: an ldflags path
# that no longer matches main.version still links, and the binary then reports
# 0.0.0, which no consumer would notice. The output is CAPTURED and compared
# whole, never piped into `grep -q` (SIGPIPE under pipefail). POSIX only: this
# stage's /bin/sh is dash.
RUN set -euo pipefail; \
    GOARCH="${TARGETARCH}" go build -trimpath \
      -ldflags="-s -w -X main.version=${SOURCE_VERSION#v}" \
      -o /out/prometheus-nats-exporter . ; \
    /out/prometheus-nats-exporter -version > /tmp/pne-version; \
    read -r v < /tmp/pne-version; \
    test "$v" = "prometheus-nats-exporter version ${SOURCE_VERSION#v}"

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
      org.opencontainers.image.title="Trusted prometheus-nats-exporter" \
      org.opencontainers.image.description="Prometheus exporter for NATS server and JetStream monitoring endpoints, built from source on trusted UBI9 Micro" \
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
      io.openshift.tags="nats,jetstream,prometheus,exporter,metrics,ubi9,vetted"

USER root

COPY --from=certs /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ubi9-micro ships no /usr/share/zoneinfo; the exporter's log timestamps and
# any TZ other than UTC call time.LoadLocation().
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/prometheus-nats-exporter /usr/bin/prometheus-nats-exporter

COPY --from=builder /src/LICENSE /usr/share/licenses/prometheus-nats-exporter/

# Passwd entry appended (no shadow-utils). GID 0 plus `chmod g=u` keeps the
# image usable under OpenShift's arbitrary-UID SCC. The exporter is stateless:
# /var/lib/prometheus-nats-exporter exists only as HOME and WORKDIR.
RUN set -euo pipefail; \
    test -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; \
    test "$(stat -c %s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)" -gt 100000; \
    printf 'nats-exporter:x:1001:0:Trusted prometheus-nats-exporter account:/var/lib/prometheus-nats-exporter:/sbin/nologin\n' >> /etc/passwd; \
    mkdir -p /etc/pki/tls/certs /etc/ssl /var/lib/prometheus-nats-exporter; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; \
    /usr/bin/prometheus-nats-exporter -version; \
    chown -R 1001:0 /var/lib/prometheus-nats-exporter; \
    chmod -R g=u /var/lib/prometheus-nats-exporter

ENV HOME=/var/lib/prometheus-nats-exporter \
    SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    TZ=UTC

WORKDIR /var/lib/prometheus-nats-exporter

# EXPOSE is metadata only. 7777 is upstream's default -port and above 1024, so
# USER 1001 needs no capability.
EXPOSE 7777

# The exporter takes the NATS monitoring URL as its one positional argument and
# polls nothing until told which endpoints to read, so CMD is upstream's
# `--help`: the image runs standalone and exits, as docker.io/natsio's does.
# Real deployments pass flags and the URL, e.g.
#   -varz -connz -subz -healthz -jsz=all http://127.0.0.1:8222
ENTRYPOINT ["prometheus-nats-exporter"]
CMD ["--help"]

USER 1001
