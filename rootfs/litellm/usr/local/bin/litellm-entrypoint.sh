#!/bin/sh
# Entrypoint of the trusted LiteLLM proxy image (Containerfiles/litellm.Containerfile).
#
# The proxy accepts every request without authentication when it has no
# master key. The owner decided on 2026-11-15 that this image refuses to
# start instead: LITELLM_MASTER_KEY must be set and not empty. It does not
# check the key; LiteLLM does. Every argument goes to `litellm` unchanged.
set -eu

if [ -z "${LITELLM_MASTER_KEY:-}" ]; then
	echo "litellm-entrypoint: error: LITELLM_MASTER_KEY is unset or empty; refusing to start a proxy that accepts every request without authentication. Set LITELLM_MASTER_KEY to the master key (for example from a secret)." >&2
	exit 1
fi

exec litellm "$@"
