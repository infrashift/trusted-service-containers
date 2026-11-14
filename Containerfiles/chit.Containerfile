# Trusted Chit
#
# Chit is infrashift's own chat service (Channels, Messages, slash commands).
# FIRST-PARTY (versions.json `firstParty`, ADR-008): no vendor image exists,
# so this file declares no crosscheck ARGs or label.
#
# One image, two binaries, one set of CUE files:
#
#   chitd           the server (the primary binary, port 8065).
#   chit-reconcile  the one-shot job that pushes the auth/*.cue grants into
#                   Keto. It ships beside chitd, as in chit's own
#                   deploy/Containerfile, so the job and the server always
#                   read the SAME CUE from the SAME commit.
#   /etc/chit/auth  the CUE that both read (CHIT_COMMANDS_CUE_DIR).
#   /usr/share/chit/migrations
#                   the SQL migrations of the pinned commit, for a golang-migrate
#                   job to mount or copy. Chit has no migrate binary of its own,
#                   and none ships here.
#
# chit-mcp and chit-claude are client tools, not server components, and are
# not built.
#
# Three stages, and every one of them exists for a verified reason:
#
#   builder — compiles from the pinned source COMMIT. CGO_ENABLED=0 as in chit's
#             deploy/Containerfile; GOWORK=off as in chit's Makefile, so the
#             server module resolves from its own go.mod and not through the
#             go.work that also names clients/chit-tui. -trimpath keeps the
#             build path out of the binary. Chit has no version variable, so
#             no -X stamp is possible (versions.json `noVersionSymbol`); the
#             module version and vcs.revision are in the Go build info.
#
#   certs   — CA trust donor. ubi9-micro ships NO /etc/pki/ca-trust.
#
#   runtime — our trusted ubi9-micro. bash and coreutils, no package manager.
#
# scripts/lint-containerfiles.sh enforces the shape invariants.

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
# pinned COMMIT and KEEPS .git, so `go version -m` carries vcs.revision and
# the module version. Chit has no release tag yet (see versions.json).
COPY src/chit/ /src/

# GOTOOLCHAIN=local: build with the pinned toolchain image's compiler, never a
# downloaded one. Chit's go.mod asks for go 1.25.14; the pinned 1.26 compiler
# satisfies it.
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOWORK=off \
    GOTOOLCHAIN=local
# Smoke tests. Neither binary has a --version flag, so each one is run to the
# first point where it proves that it works:
#   chitd refuses to start without CHIT_DATABASE_URL -- it ran its config load.
#   chit-reconcile loads and unifies the CUE, then fails to reach Keto on a
#   closed port -- the CUE in this commit compiles with this binary.
# Output is captured, not piped into grep -q (SIGPIPE under pipefail).
RUN set -euo pipefail; \
    GOARCH="${TARGETARCH}" go build -trimpath -ldflags="-s -w" -o /out/chitd ./cmd/chitd; \
    GOARCH="${TARGETARCH}" go build -trimpath -ldflags="-s -w" -o /out/chit-reconcile ./cmd/chit-reconcile; \
    if out="$(/out/chitd 2>&1)"; then echo "chitd started without a database URL" >&2; exit 1; fi; \
    printf '%s\n' "$out"; \
    case "$out" in *"CHIT_DATABASE_URL is required"*) ;; *) echo "chitd did not reach its config check" >&2; exit 1 ;; esac; \
    if out="$(CHIT_COMMANDS_CUE_DIR=/src/auth CHIT_KETO_READ_URL=http://127.0.0.1:9 CHIT_KETO_WRITE_URL=http://127.0.0.1:9 /out/chit-reconcile 2>&1)"; then \
      echo "chit-reconcile reported success against a closed port" >&2; exit 1; fi; \
    printf '%s\n' "$out"; \
    case "$out" in *'"msg":"CUE loaded"'*) ;; *) echo "chit-reconcile did not load the CUE in /src/auth" >&2; exit 1 ;; esac

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
      org.opencontainers.image.title="Trusted Chit" \
      org.opencontainers.image.description="Chit chat server (chitd) and its Keto grant reconciler, built from source on trusted UBI9 Micro" \
      org.opencontainers.image.maintainer="Ryan Craig <ryan.craig@infrashift.io>" \
      org.opencontainers.image.vendor="Infrashift" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.architecture="${TARGETARCH}" \
      io.infrashift.image.variant="ubi9-micro" \
      io.infrashift.build.recipe.revision="${GIT_COMMIT}" \
      io.infrashift.build.toolchain="${TOOLCHAIN_BASE}@${TOOLCHAIN_DIGEST}" \
      io.infrashift.build.ca.source="${CA_BASE}@${CA_DIGEST}" \
      io.infrashift.build.provenance-mode="first-party" \
      io.openshift.tags="chit,chat,ubi9,vetted"

USER root

# Go's crypto/x509 probes a fixed path list. The bundle plus the two
# conventional symlinks covers Go, OpenSSL consumers and SSL_CERT_FILE.
COPY --from=certs /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
                  /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ubi9-micro ships no /usr/share/zoneinfo. Without it time.LoadLocation()
# fails for anything but UTC.
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /out/chitd /usr/bin/chitd
COPY --from=builder /out/chit-reconcile /usr/bin/chit-reconcile
# Read-only runtime data from the pinned commit.
COPY --from=builder /src/auth /etc/chit/auth
COPY --from=builder /src/migrations /usr/share/chit/migrations

# ubi9-micro has no shadow-utils, so the passwd entry is appended by hand.
# GID 0 plus `chmod g=u` keeps the image usable under OpenShift's arbitrary-UID
# SCC. /var/log/chit is the default audit log directory (CHIT_AUDIT_LOG_PATH);
# without write access chitd falls back to stderr.
RUN set -euo pipefail; \
    test -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem; \
    test "$(stat -c %s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)" -gt 100000; \
    test -n "$(ls /etc/chit/auth)"; \
    test -n "$(ls /usr/share/chit/migrations/*.up.sql)"; \
    printf 'chit:x:1001:0:Trusted Chit service account:/home/chit:/sbin/nologin\n' >> /etc/passwd; \
    mkdir -p /etc/pki/tls/certs /etc/ssl /home/chit /var/log/chit; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/certs/ca-bundle.crt; \
    ln -sf /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/cert.pem; \
    chown -R 1001:0 /home/chit /var/log/chit; \
    chmod -R g=u /home/chit /var/log/chit

ENV HOME=/home/chit \
    SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    CHIT_COMMANDS_CUE_DIR=/etc/chit/auth \
    TZ=UTC

WORKDIR /home/chit

# EXPOSE is metadata only. 8065 is above 1024, so USER 1001 needs no
# capability to bind it.
EXPOSE 8065

ENTRYPOINT ["chitd"]

USER 1001
