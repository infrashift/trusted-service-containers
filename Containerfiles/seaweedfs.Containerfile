# Trusted SeaweedFS
#
# Three stages, and every one of them exists for a verified reason:
#
#   builder — compiles `weed` from the pinned source COMMIT with upstream's
#             release ldflags (binaries_release0.yml at 4.48). Only the Go
#             binary: upstream's image also carries an optional Rust volume
#             server and maintenance worker, which `weed` does not need.
#
#   certs   — CA trust donor. ubi9-micro ships NO /etc/pki/ca-trust of any kind.
#             The filer makes outbound TLS calls to remote storage backends and
#             replication sinks.
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
ARG TARGETARCH

WORKDIR /src
# Placed in the build context by scripts/fetch-source.sh (pinned COMMIT, tag
# asserted to resolve to it).
COPY src/seaweedfs/ /src/

# GOTOOLCHAIN=local: go.mod asks for go 1.26.6, exactly the patch the pinned
# toolchain image carries. `local` makes a future go.mod that wants more fail
# the build instead of silently downloading an unpinned compiler.
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOTOOLCHAIN=local

# The version NUMBER is compiled in from weed/util/version/constants.go (MAJOR,
# MINOR), not stamped; only COMMIT is an ldflag. Upstream's release tarballs
# stamp the full SHA, its container images git's dynamic short form; we stamp
# the pinned shortCommit, as the cross-check image does (`weed version` there:
# "version 30GB 4.48 530be3e37 linux amd64").
#
# -trimpath is ours. -s -w and -extldflags -static are upstream's. No build tags:
# the standard build (30GB volume size limit), not 5BytesOffset/large_disk, whose
# volumes are not readable by a standard build.
#
# The version check is the guard for the two failures that matter: an ldflags
# path that no longer matches weed/util/version (the binary reports no commit),
# and a ref whose source constants say a different version than the tag. The
# output is CAPTURED, not piped into `grep -q`: `weed version` prints an
# advertisement after the version line, and grep exiting on the first match
# kills it with SIGPIPE -- exit 141 under pipefail, a failed build that looks
# like a bad binary. POSIX only: this stage's /bin/sh is dash.
RUN set -euo pipefail; \
    GOARCH="${TARGETARCH}" go build -trimpath \
      -ldflags="-s -w -extldflags -static -X github.com/seaweedfs/seaweedfs/weed/util/version.COMMIT=${SOURCE_SHORT_REF}" \
      -o /out/weed ./weed ; \
    /out/weed version > /tmp/weed-version; \
    read -r v < /tmp/weed-version; \
    test "$v" = "version 30GB ${SOURCE_VERSION} ${SOURCE_SHORT_REF} linux ${TARGETARCH}"

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
      org.opencontainers.image.title="Trusted SeaweedFS" \
      org.opencontainers.image.description="SeaweedFS (master, volume, filer and S3 gateway in one weed binary), built from source on trusted UBI9 Micro" \
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
      io.openshift.tags="seaweedfs,s3,object-storage,filer,ubi9,vetted"

USER root

COPY --from=certs /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ubi9-micro ships no /usr/share/zoneinfo; filer TTLs and S3 lifecycle dates
# call time.LoadLocation().
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/weed /usr/bin/weed

COPY --from=builder /src/LICENSE /usr/share/licenses/seaweedfs/

# Passwd entry appended (no shadow-utils). GID 0 plus `chmod g=u` keeps the
# image usable under OpenShift's arbitrary-UID SCC. /data holds the volume
# files (.dat/.idx), the master's metadata and the filer's leveldb2 store.
#
# The smoke check runs the binary for real: `weed scaffold` renders a config
# template, which exercises flag parsing and the embedded templates without
# opening a port.
RUN set -euo pipefail; \
    test -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; \
    test "$(stat -c %s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)" -gt 100000; \
    printf 'seaweedfs:x:1001:0:Trusted SeaweedFS service account:/data:/sbin/nologin\n' >> /etc/passwd; \
    mkdir -p /etc/pki/tls/certs /etc/ssl /data; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; \
    /usr/bin/weed version; \
    scaffold="$(/usr/bin/weed scaffold -config=filer)"; \
    case "${scaffold}" in *'[leveldb2]'*) ;; *) echo "weed scaffold rendered no [leveldb2] section" >&2; exit 1 ;; esac; \
    chown -R 1001:0 /data; \
    chmod -R g=u /data

ENV HOME=/data \
    SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    TZ=UTC

WORKDIR /data

# EXPOSE is metadata only, and lists what CMD below opens: S3 8333, filer 8888
# (+10000 gRPC), master 9333 (+10000), volume 8080 (+10000). All above 1024, so
# USER 1001 needs no capability.
EXPOSE 8333 8888 18888 9333 19333 8080 18080

# Without a persistent mount, every restart loses every object -- silently.
VOLUME /data

# A single-node all-in-one store with an S3 gateway, so the image runs
# standalone. Real deployments pass their own flags, an -s3.config identity file
# above all: with none, the S3 gateway allows anonymous access. The Iceberg and
# Lance REST endpoints, which -s3 otherwise opens on 8181 and 9101, are off.
ENTRYPOINT ["weed"]
CMD ["server", "-dir=/data", "-s3", "-s3.port.iceberg=0", "-s3.port.lance=0"]

USER 1001
