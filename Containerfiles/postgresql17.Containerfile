# Trusted PostgreSQL 17
#
# A PACKAGE build, not a source build (ADR-009). PostgreSQL is C, and the
# build track compiles only static Go binaries. This file installs signed RPMs
# at pinned NEVRAs onto our trusted ubi9-minimal, and nothing else:
#
#   * UBI9 AppStream has no PostgreSQL 17 (no server package and no
#     `postgresql` module stream, checked 2026-11-14), so the packages come
#     from the official PGDG EL9 repository.
#   * The signing key is the copy committed under .github/pdp/keyring/, pinned
#     in versions.json by fingerprint and by file sha256. scripts/build-leg.sh
#     checks both before the build; this file checks the sha256 again and the
#     key ID of every installed package after the install.
#   * gpgcheck=1 and repo_gpgcheck=1: every RPM and the repository metadata
#     must verify against that key, and the UBI dependencies against the Red
#     Hat key the base image ships.
#   * microdnf gets exact NEVRAs. `rpm -q` then proves each one is installed
#     at exactly that NEVRA, signed by the pinned key.
#
# One stage: ubi9-minimal already carries the CA trust bundle, tzdata-free
# PostgreSQL needs no zoneinfo donor (it ships its own timezone data), and no
# compiler runs. scripts/lint-containerfiles.sh enforces the invariants.

ARG UPSTREAM_BASE
ARG UPSTREAM_DIGEST

FROM ${UPSTREAM_BASE}@${UPSTREAM_DIGEST}

# Re-declared after FROM. ARGs before the first FROM are global build args and
# are NOT in scope inside a build stage, so the LABELs below would silently
# expand to empty strings. The policy's BUILD_LABEL_EMPTY rule catches this.
ARG UPSTREAM_BASE
ARG UPSTREAM_DIGEST
ARG PACKAGE_REPO_ID
ARG PACKAGE_BASEURL
ARG PACKAGE_KEY
ARG PACKAGE_KEY_SHA256
ARG PACKAGE_KEY_ID
ARG PACKAGE_NEVRAS
ARG PACKAGE_VERSION
ARG PACKAGE_EVR
ARG BUILD_DATE
ARG TARGETARCH
ARG GIT_COMMIT

# The first five are REQUIRED by .github/pdp/policies.rego. On the package
# track, `source` is the RPM repository, `revision` is the version-release of
# the pinned RPMs and `version` is the PostgreSQL version.
LABEL org.opencontainers.image.source="${PACKAGE_BASEURL}" \
      org.opencontainers.image.revision="${PACKAGE_EVR}" \
      org.opencontainers.image.version="${PACKAGE_VERSION}" \
      io.infrashift.image.upstream.digest="${UPSTREAM_DIGEST}" \
      io.infrashift.image.upstream.source="${UPSTREAM_BASE}" \
      org.opencontainers.image.title="Trusted PostgreSQL 17" \
      org.opencontainers.image.description="PostgreSQL 17 from signed PGDG RPMs at pinned NEVRAs, on trusted UBI9 Minimal" \
      org.opencontainers.image.maintainer="Ryan Craig <ryan.craig@infrashift.io>" \
      org.opencontainers.image.vendor="Infrashift" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="PostgreSQL" \
      org.opencontainers.image.architecture="${TARGETARCH}" \
      io.infrashift.image.variant="ubi9-minimal" \
      io.infrashift.build.recipe.revision="${GIT_COMMIT}" \
      io.infrashift.build.package.repository="${PACKAGE_REPO_ID}" \
      io.infrashift.build.package.nevras="${PACKAGE_NEVRAS}" \
      io.openshift.tags="postgresql,postgresql17,database,ubi9,vetted"

USER root

COPY ${PACKAGE_KEY} /etc/pki/rpm-gpg/RPM-GPG-KEY-${PACKAGE_REPO_ID}

# 0. The base: upgrade it from the Red Hat signed UBI repositories BEFORE the
#    third-party repository exists, so that no PGDG package can replace a base
#    package. The pinned base can be older than its own UBI content: on
#    2026-11-14 it carried krb5-libs 1.21.1-10.el9_8 with 14 fixable Highs
#    that 1.21.1-10.el9_9.2 in ubi-9-baseos clears.
# 1. The key: the committed file, byte for byte, then imported into the rpm
#    database so that gpgcheck has exactly one third-party key to trust.
# 2. The repository: gpgcheck and repo_gpgcheck both on.
# 3. The install: exact NEVRAs, no weak dependencies, no documentation.
# 4. The proof: each NEVRA is installed exactly, and its header signature
#    names the pinned key. A package signed by any other key fails the build,
#    and so does any package with the pinned key that is not pinned.
RUN set -euo pipefail; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 upgrade; \
    key="/etc/pki/rpm-gpg/RPM-GPG-KEY-${PACKAGE_REPO_ID}"; \
    printf '%s  %s\n' "${PACKAGE_KEY_SHA256}" "$key" | sha256sum --check --strict; \
    rpm --import "$key"; \
    printf '[%s]\nname=%s (pinned by trusted-service-containers)\nbaseurl=%s\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=file://%s\n' \
      "${PACKAGE_REPO_ID}" "${PACKAGE_REPO_ID}" "${PACKAGE_BASEURL}" "$key" \
      > "/etc/yum.repos.d/tsc-${PACKAGE_REPO_ID}.repo"; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 install ${PACKAGE_NEVRAS}; \
    microdnf clean all; \
    for nevra in ${PACKAGE_NEVRAS}; do \
      got="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$nevra")"; \
      test "$got" = "$nevra" || { echo "rpm -q: ${nevra} is installed as ${got}" >&2; exit 1; }; \
      sig="$(rpm -q --qf '%{RSAHEADER:pgpsig}\n' "$nevra")"; \
      case "$sig" in *"Key ID ${PACKAGE_KEY_ID}") ;; \
        *) echo "rpm -q: ${nevra} is not signed by key ${PACKAGE_KEY_ID}: ${sig}" >&2; exit 1 ;; esac; \
    done; \
    rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH} %{RSAHEADER:pgpsig}\n' \
      | while read -r nevra rest; do \
          case "$rest" in *"Key ID ${PACKAGE_KEY_ID}") \
            case " ${PACKAGE_NEVRAS} " in *" ${nevra} "*) ;; \
              *) echo "rpm -q: ${nevra} comes from ${PACKAGE_REPO_ID} but is not pinned" >&2; exit 1 ;; esac ;; \
          esac; \
        done; \
    /usr/pgsql-17/bin/postgres --version; \
    /usr/pgsql-17/bin/psql --version

COPY rootfs/postgresql17/ /

# The RHEL postgres user (UID 26) keeps its UID and gets GID 0 as its primary
# group, as UID 1001 has in the Go images: with `chmod g=u` the writable paths
# also work under OpenShift's arbitrary-UID SCC. The volume is mounted at
# /var/lib/pgsql/data and the cluster lives one level down, in userdata/, as
# in the Red Hat images: the entrypoint creates it with mode 0700 on a fresh
# volume. The PGDG .bash_profile points PGDATA at /var/lib/pgsql/17/data, so
# it is removed.
RUN set -euo pipefail; \
    usermod -g 0 -G postgres postgres; \
    test "$(id -u postgres):$(id -g postgres)" = "26:0"; \
    rm -f /var/lib/pgsql/.bash_profile; \
    mkdir -p /var/lib/pgsql/data /run/postgresql /docker-entrypoint-initdb.d; \
    chown -R 26:0 /var/lib/pgsql /run/postgresql /docker-entrypoint-initdb.d; \
    chmod -R g=u /var/lib/pgsql /run/postgresql /docker-entrypoint-initdb.d; \
    chmod 0755 /usr/local/bin/docker-entrypoint.sh

ENV HOME=/var/lib/pgsql \
    PGDATA=/var/lib/pgsql/data/userdata \
    PATH=/usr/pgsql-17/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    TZ=UTC

WORKDIR /var/lib/pgsql

# EXPOSE is metadata only. 5432 is above 1024, so UID 26 needs no capability.
EXPOSE 5432

VOLUME /var/lib/pgsql/data

# SIGINT is PostgreSQL's "fast shutdown": it ends sessions and checkpoints.
# The default SIGTERM is "smart shutdown", which waits for every client.
STOPSIGNAL SIGINT

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]

USER 26
