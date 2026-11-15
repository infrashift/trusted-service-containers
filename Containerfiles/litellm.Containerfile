# Trusted LiteLLM proxy
#
# A NATIVE build (ADR-010), language python. The owner decided on 2026-11-15
# to build LiteLLM here instead of mirroring the DHI image. This file installs
# a hash-locked wheel set onto the Python 3.12 of UBI, and nothing else:
#
#   * Python 3.12 and pip come from the Red Hat signed UBI repositories, with
#     the gpgcheck that the base image configures. pip stays in the builder.
#   * The lock is locks/litellm/requirements.txt, pinned in versions.json by
#     sha256 (LOCK_SHA256, checked again here). pip installs it with
#     --require-hashes --no-deps --only-binary=:all:: every file must match a
#     hash in the lock, nothing outside the lock is resolved, and no package
#     builds from source.
#   * The venv is created --without-pip, so it holds exactly the lock. The
#     review compares the Python distributions in the image with the lock.
#   * No Node.js and no Prisma. The admin UI is static files in the wheel.
#   * The entrypoint (rootfs/litellm/usr/local/bin/litellm-entrypoint.sh)
#     refuses to start without LITELLM_MASTER_KEY: without a master key the
#     proxy accepts every request without authentication.
#
# scripts/lint-containerfiles.sh enforces the shape.

ARG BUILDER_BASE
ARG BUILDER_DIGEST
ARG UPSTREAM_BASE
ARG UPSTREAM_DIGEST

# ---------------------------------------------------------------------------
# Stage 1: install the lock into a venv.
# ---------------------------------------------------------------------------
FROM ${BUILDER_BASE}@${BUILDER_DIGEST} AS builder

ARG BUILD_PACKAGES
ARG LOCK_SHA256
ARG VENV

USER root

# Signed UBI packages only. The base image's own repository files keep
# gpgcheck=1 and the Red Hat key; nothing here touches them.
RUN set -euo pipefail; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 install ${BUILD_PACKAGES}; \
    microdnf clean all

COPY locks/litellm/requirements.txt /tmp/requirements.txt

RUN set -euo pipefail; \
    printf '%s  %s\n' "${LOCK_SHA256}" /tmp/requirements.txt | sha256sum --check --strict; \
    python3.12 -m venv --without-pip "${VENV}"; \
    python3.12 -m pip --python "${VENV}/bin/python" install --no-cache-dir --disable-pip-version-check --progress-bar off --retries 10 --timeout 60 \
      --require-hashes --no-deps --only-binary=:all: -r /tmp/requirements.txt; \
    python3.12 -m pip --python "${VENV}/bin/python" check; \
    install -m 0644 /tmp/requirements.txt "${VENV}/requirements.txt"; \
    "${VENV}/bin/litellm" --version

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
ARG RUNTIME_PACKAGES
ARG BUILD_DATE
ARG TARGETARCH
ARG GIT_COMMIT

# The first five are REQUIRED by .github/pdp/policies.rego. On the python
# language, `source` is the PyPI project, `revision` is the sha256 of the lock
# and `version` is the LiteLLM release.
LABEL org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.revision="${SOURCE_REF}" \
      org.opencontainers.image.version="${SOURCE_VERSION}" \
      io.infrashift.image.upstream.digest="${UPSTREAM_DIGEST}" \
      io.infrashift.image.upstream.source="${UPSTREAM_BASE}" \
      org.opencontainers.image.title="Trusted LiteLLM proxy" \
      org.opencontainers.image.description="The LiteLLM proxy from a hash-locked wheel set on the Python 3.12 of trusted UBI9 Minimal" \
      org.opencontainers.image.maintainer="Ryan Craig <ryan.craig@infrashift.io>" \
      org.opencontainers.image.vendor="Infrashift" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.architecture="${TARGETARCH}" \
      io.infrashift.image.variant="ubi9-minimal" \
      io.infrashift.build.recipe.revision="${GIT_COMMIT}" \
      io.infrashift.build.native.builder="${BUILDER_BASE}@${BUILDER_DIGEST}" \
      io.openshift.tags="litellm,llm,gateway,python,ubi9,vetted"

USER root

# Upgrade the base, then install the interpreter, from the Red Hat signed UBI
# repositories. No pip and no compiler in the runtime stage.
RUN set -euo pipefail; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 upgrade; \
    microdnf -y --nodocs --setopt=install_weak_deps=0 install ${RUNTIME_PACKAGES}; \
    microdnf clean all

COPY --from=builder /opt/litellm /opt/litellm
COPY rootfs/litellm/ /

ENV PATH=/opt/litellm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HOME=/var/lib/litellm \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LITELLM_LOCAL_MODEL_COST_MAP=True \
    LANG=C.UTF-8 \
    TZ=UTC

# UID 1001 with primary GID 0, as in the Go images. ubi9-minimal has no
# useradd, so the entry is appended. The code under /opt/litellm stays owned
# by root; only HOME is writable.
#
# Then the runtime smoke tests. The entrypoint refuses to start with no key
# and with an empty key. With the key from the environment, the proxy starts
# through the entrypoint with a throwaway config, answers /health/liveliness
# without a key, refuses /v1/models without the key (401) and lists the model
# with the key.
RUN set -euo pipefail; \
    echo "litellm:x:1001:0:LiteLLM:/var/lib/litellm:/sbin/nologin" >> /etc/passwd; \
    mkdir -p /var/lib/litellm; \
    chown -R 1001:0 /var/lib/litellm /etc/litellm; \
    chmod -R g=u /var/lib/litellm /etc/litellm; \
    chmod 0755 /usr/local/bin/litellm-entrypoint.sh; \
    test "$(readlink -f /opt/litellm/bin/python)" = /usr/bin/python3.12; \
    litellm --version; \
    for k in unset empty; do \
      if [ "$k" = unset ]; then env -u LITELLM_MASTER_KEY litellm-entrypoint.sh --version > /tmp/refuse.log 2>&1 && rc=0 || rc=$?; \
      else LITELLM_MASTER_KEY= litellm-entrypoint.sh --version > /tmp/refuse.log 2>&1 && rc=0 || rc=$?; fi; \
      test "$rc" -ne 0 || { echo "the entrypoint started with the master key $k" >&2; exit 1; }; \
      grep -q 'LITELLM_MASTER_KEY is unset or empty' /tmp/refuse.log || { cat /tmp/refuse.log >&2; exit 1; }; \
    done; \
    printf 'model_list:\n  - model_name: smoke\n    litellm_params:\n      model: openai/smoke\n      api_base: http://127.0.0.1:9/v1\n      api_key: none\ngeneral_settings:\n  master_key: os.environ/LITELLM_MASTER_KEY\n' > /tmp/smoke.yaml; \
    LITELLM_MASTER_KEY=sk-smoke litellm-entrypoint.sh --config /tmp/smoke.yaml --host 127.0.0.1 --port 4000 > /tmp/smoke.log 2>&1 & pid=$!; \
    printf '%s\n' \
      'import json, sys, time, urllib.request as u' \
      'for _ in range(240):' \
      '    try:' \
      '        r = u.urlopen("http://127.0.0.1:4000/health/liveliness", timeout=2); break' \
      '    except Exception:' \
      '        time.sleep(0.5)' \
      'else:' \
      '    sys.exit("no answer on /health/liveliness")' \
      'assert r.status == 200, r.status' \
      'try:' \
      '    u.urlopen("http://127.0.0.1:4000/v1/models", timeout=10); sys.exit("/v1/models answered without the key")' \
      'except u.HTTPError as e:' \
      '    assert e.code == 401, e.code' \
      'q = u.Request("http://127.0.0.1:4000/v1/models", headers={"Authorization": "Bearer sk-smoke"})' \
      'ids = [m["id"] for m in json.load(u.urlopen(q, timeout=10))["data"]]' \
      'assert ids == ["smoke"], ids' \
      'print("liveliness 200, /v1/models 401 without the key and", ids, "with it")' > /tmp/smoke.py; \
    /opt/litellm/bin/python /tmp/smoke.py \
      || { kill "$pid" 2>/dev/null; cat /tmp/smoke.log >&2; exit 1; }; \
    kill "$pid"; wait "$pid" 2>/dev/null || true; \
    rm -rf /tmp/smoke.py /tmp/smoke.yaml /tmp/smoke.log /tmp/refuse.log /var/lib/litellm/* /var/lib/litellm/.[!.]*; \
    echo "runtime smoke test: OK"

WORKDIR /var/lib/litellm

# EXPOSE is metadata only. 4000 is above 1024, so UID 1001 needs no capability.
EXPOSE 4000

ENTRYPOINT ["litellm-entrypoint.sh"]
CMD ["--config", "/etc/litellm/config.yaml", "--host", "0.0.0.0", "--port", "4000"]

USER 1001
