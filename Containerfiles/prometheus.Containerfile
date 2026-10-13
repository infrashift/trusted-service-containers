# Trusted Prometheus
#
# Three stages, and every one of them exists for a verified reason:
#
#   builder — compiles prometheus AND promtool from the pinned source COMMIT
#             with upstream's .promu.yml tags and ldflags. The web UI is the one
#             input not compiled here: a source build without Node has none, so
#             the vendor's prebuilt prometheus-web-ui tarball is embedded,
#             fetched and sha256-verified by scripts/fetch-assets.sh.
#
#   certs   — CA trust donor. ubi9-micro ships NO /etc/pki/ca-trust of any kind.
#             Prometheus makes outbound TLS calls on every HTTPS scrape and
#             service-discovery request.
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
ARG SOURCE_DATE
ARG TARGETARCH

WORKDIR /src
# Placed in the build context by scripts/fetch-source.sh (pinned COMMIT, tag
# asserted to resolve to it) and scripts/fetch-assets.sh (sha256-pinned,
# refused unless the URL names this release).
COPY src/prometheus/ /src/
COPY src/.assets/prometheus/ /assets/

# GOTOOLCHAIN=local: go.mod asks for go 1.26.0 and the pinned toolchain image
# satisfies it. `local` makes a future go.mod that wants more fail the build
# instead of silently downloading an unpinned compiler. Upstream's .promu.yml
# builds with Go 1.27, which is why the cross-check is best-effort.
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOTOOLCHAIN=local

# The UI tarball unpacks to web/ui/static/{mantine-ui,react-app}/..., the shape
# upstream's scripts/package_assets.sh writes. web/ui/static is gitignored
# upstream, so it does not mark the worktree modified. compress_assets.sh then
# gzips it and generates web/ui/embed.go, exactly as `make assets-compress`.
#
# The grep on embed.go is the guard for the failure that matters: with no
# assets, `builtinassets` still compiles, the binary still starts, and only a
# human opening the browser finds the UI missing.
#
# Version is the ref without its v (promu stamps the VERSION file, 3.15.0, and
# the two are asserted equal). BuildDate is the source COMMIT date in promu's
# format, never wall-clock, so a rerun stamps the same string. Branch is HEAD,
# which is what upstream's tag builds report.
#
# -s -w is ours, not upstream's (promu does not strip): unstripped, the two
# binaries are 147MB + 120MB. Stripping drops the symbol and DWARF tables only;
# the Go buildinfo that scanners and `go version -m` read is kept.
RUN set -euo pipefail; \
    test "$(cat VERSION)" = "${SOURCE_VERSION#v}"; \
    tar -xzf /assets/web-ui -C web/ui; \
    test -s web/ui/static/mantine-ui/index.html; \
    ./scripts/compress_assets.sh; \
    grep -q 'static/mantine-ui/index.html.gz' web/ui/embed.go; \
    BUILD_DATE_PROMU="$(date -u -d "${SOURCE_DATE}" +%Y%m%d-%H:%M:%S)"; \
    LDFLAGS="-s -w -X github.com/prometheus/common/version.Version=${SOURCE_VERSION#v} \
      -X github.com/prometheus/common/version.Revision=${SOURCE_REF} \
      -X github.com/prometheus/common/version.Branch=HEAD \
      -X github.com/prometheus/common/version.BuildUser=infrashift@trusted-service-containers \
      -X github.com/prometheus/common/version.BuildDate=${BUILD_DATE_PROMU}"; \
    GOARCH="${TARGETARCH}" go build -trimpath -tags=netgo,builtinassets \
      -ldflags="${LDFLAGS}" -o /out/prometheus ./cmd/prometheus ; \
    GOARCH="${TARGETARCH}" go build -trimpath -tags=netgo,builtinassets \
      -ldflags="${LDFLAGS}" -o /out/promtool ./cmd/promtool ; \
    /out/prometheus --version; \
    /out/promtool --version

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
      org.opencontainers.image.title="Trusted Prometheus" \
      org.opencontainers.image.description="Prometheus monitoring server and promtool, built from source on trusted UBI9 Micro" \
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
      io.openshift.tags="prometheus,monitoring,metrics,ubi9,vetted"

USER root

COPY --from=certs /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ubi9-micro ships no /usr/share/zoneinfo; Prometheus's PromQL timezone
# functions and rule evaluation call time.LoadLocation().
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/prometheus /usr/bin/prometheus
COPY --from=builder /out/promtool /usr/bin/promtool

# Upstream's default config and the licence files, from the pinned source tree.
# The config scrapes Prometheus itself, so the image runs standalone the way
# quay.io/prometheus/prometheus does; deployments mount their own.
COPY --from=builder /src/documentation/examples/prometheus.yml /etc/prometheus/prometheus.yml
COPY --from=builder /src/LICENSE /src/NOTICE /usr/share/licenses/prometheus/

# Passwd entry appended (no shadow-utils). GID 0 plus `chmod g=u` keeps the
# image usable under OpenShift's arbitrary-UID SCC. /prometheus is the TSDB.
RUN set -euo pipefail; \
    test -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; \
    test "$(stat -c %s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)" -gt 100000; \
    printf 'prometheus:x:1001:0:Trusted Prometheus service account:/prometheus:/sbin/nologin\n' >> /etc/passwd; \
    mkdir -p /etc/pki/tls/certs /etc/ssl /prometheus /etc/prometheus; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; \
    /usr/bin/promtool check config /etc/prometheus/prometheus.yml; \
    chown -R 1001:0 /prometheus /etc/prometheus; \
    chmod -R g=u /prometheus /etc/prometheus

ENV HOME=/prometheus \
    SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    TZ=UTC

WORKDIR /prometheus

# EXPOSE is metadata only. 9090 is above 1024, so USER 1001 needs no capability.
EXPOSE 9090

# Without a persistent mount, every restart loses all history -- silently.
VOLUME /prometheus

ENTRYPOINT ["prometheus"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus"]

USER 1001
