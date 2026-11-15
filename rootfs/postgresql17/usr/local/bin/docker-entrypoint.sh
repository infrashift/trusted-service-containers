#!/usr/bin/env bash
# Entrypoint of the trusted PostgreSQL 17 image (Containerfiles/postgresql17.Containerfile).
#
# It keeps the environment contract of the Docker official and Docker Hardened
# postgres images, because HALO and Chit already use that contract with the
# DHI mirror:
#
#   POSTGRES_PASSWORD (or POSTGRES_PASSWORD_FILE)  required on an empty data
#                     directory, unless POSTGRES_HOST_AUTH_METHOD=trust
#   POSTGRES_USER     superuser that initdb creates (default: postgres)
#   POSTGRES_DB       database created after initdb (default: $POSTGRES_USER)
#   POSTGRES_INITDB_ARGS       extra initdb arguments, word-split
#   POSTGRES_HOST_AUTH_METHOD  pg_hba method for TCP clients (default: scram-sha-256)
#   PGDATA, PGPORT    honoured, as postgres and psql honour them
#   /docker-entrypoint-initdb.d/*.sh|*.sql|*.sql.gz  run once, after initdb
#
# A first argument that starts with '-' is a flag for the server, so
# `podman run IMAGE -c listen_addresses=127.0.0.1` runs `postgres -c ...`.
#
# What differs from the Docker images, deliberately:
#
#   * No root step-down. The image runs as UID 26 (the RHEL postgres user) in
#     GID 0 and never needs root. As root this script refuses to start rather
#     than initialise a data directory that UID 26 later cannot read.
#   * The initdb pass listens on NO TCP port and on a PRIVATE socket directory.
#     The Docker images serve the default socket during initdb, so a readiness
#     probe (`podman exec ... psql -U postgres -c 'SELECT 1'`, or pg_isready)
#     succeeds against the temporary server, and the client then connects over
#     TCP while that server stops. Here every probe fails until the real
#     server is up.
#   * initdb uses the PostgreSQL 17 builtin C.UTF-8 locale provider: the
#     collation does not depend on the glibc of the image, so a base re-pin
#     never changes the order of a text index.
set -Eeuo pipefail

log() { printf '%s [entrypoint] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }
die() { log "error: $*"; exit 1; }

# file_env VAR [DEFAULT]: VAR, or the content of the file that VAR_FILE names.
file_env() {
  local var="$1" fvar="${1}_FILE" def="${2:-}" val=""
  if [[ -n "${!var:-}" && -n "${!fvar:-}" ]]; then
    die "both ${var} and ${fvar} are set; set only one"
  fi
  if [[ -n "${!var:-}" ]]; then
    val="${!var}"
  elif [[ -n "${!fvar:-}" ]]; then
    val="$(< "${!fvar}")"
  else
    val="$def"
  fi
  export "$var"="$val"
  unset "$fvar"
}

# True when the server is asked only for help or a version: no setup needed.
want_help() {
  local a
  for a; do
    case "$a" in
      -'?'|--help|--describe-config|-V|--version|-C) return 0 ;;
    esac
  done
  return 1
}

init_database() {
  file_env POSTGRES_PASSWORD
  file_env POSTGRES_USER postgres
  file_env POSTGRES_DB "$POSTGRES_USER"
  file_env POSTGRES_INITDB_ARGS
  local auth="${POSTGRES_HOST_AUTH_METHOD:-scram-sha-256}"

  if [[ -z "$POSTGRES_PASSWORD" && "$auth" != trust ]]; then
    die "the data directory ${PGDATA} is empty and POSTGRES_PASSWORD is not set. Set POSTGRES_PASSWORD (or POSTGRES_PASSWORD_FILE). POSTGRES_HOST_AUTH_METHOD=trust disables the password check for TCP clients; do not use it outside a test."
  fi
  [[ "$auth" == trust ]] && log "warning: POSTGRES_HOST_AUTH_METHOD=trust accepts every TCP client without a password"

  log "initialising ${PGDATA} (superuser ${POSTGRES_USER}, database ${POSTGRES_DB})"
  local -a extra=()
  # shellcheck disable=SC2206 # POSTGRES_INITDB_ARGS is word-split by contract.
  [[ -n "$POSTGRES_INITDB_ARGS" ]] && extra=($POSTGRES_INITDB_ARGS)
  # The password goes to initdb through a pipe, never through argv or SQL text.
  initdb --pgdata="$PGDATA" --username="$POSTGRES_USER" \
    --pwfile=<(printf '%s\n' "$POSTGRES_PASSWORD") \
    --encoding=UTF8 --locale-provider=builtin --builtin-locale=C.UTF-8 --locale=C.UTF-8 \
    --auth-local=trust --auth-host="$auth" \
    "${extra[@]}" >&2

  # TCP for every address, with the requested method. Local socket: trust,
  # because only a process inside the container can reach it.
  {
    printf '\n# Added by docker-entrypoint.sh\n'
    printf 'host all all all %s\n' "$auth"
  } >> "${PGDATA}/pg_hba.conf"
  # PGDG's sample configuration turns the logging collector on, which writes
  # the server log into files under PGDATA. A container logs to stderr.
  printf "\n# Added by docker-entrypoint.sh\nlisten_addresses = '*'\nlogging_collector = off\nlog_destination = 'stderr'\n" \
    >> "${PGDATA}/postgresql.conf"

  # The initdb pass: no TCP, and a socket directory nobody else knows.
  local sockdir
  sockdir="$(mktemp -d /tmp/pg-initdb.XXXXXX)"
  pg_ctl --pgdata="$PGDATA" --wait --silent \
    -o "-c listen_addresses='' -c unix_socket_directories='${sockdir}'" start >&2
  export PGHOST="$sockdir"

  local -a psql=(psql -v ON_ERROR_STOP=1 --no-psqlrc --username "$POSTGRES_USER" --no-password)
  if [[ "$POSTGRES_DB" != postgres ]]; then
    # psql variables quote the name; the value never becomes SQL text.
    "${psql[@]}" --dbname postgres -v db="$POSTGRES_DB" >&2 <<'SQL'
SELECT format('CREATE DATABASE %I', :'db')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db')
\gexec
SQL
  fi

  local f
  for f in /docker-entrypoint-initdb.d/*; do
    [[ -e "$f" ]] || continue
    case "$f" in
      *.sh)
        if [[ -x "$f" ]]; then log "running $f"; "$f"
        else log "sourcing $f"; # shellcheck disable=SC1090
          . "$f"; fi ;;
      *.sql)    log "running $f"; "${psql[@]}" --dbname "$POSTGRES_DB" -f "$f" >&2 ;;
      *.sql.gz) log "running $f"; gzip -dc "$f" | "${psql[@]}" --dbname "$POSTGRES_DB" >&2 ;;
      *)        log "ignoring $f" ;;
    esac
  done

  pg_ctl --pgdata="$PGDATA" --wait --silent -m fast stop >&2
  unset PGHOST
  rmdir "$sockdir" 2>/dev/null || true
  log "initialisation complete"
}

if [[ $# -eq 0 || "${1:0:1}" == '-' ]]; then
  set -- postgres "$@"
fi

if [[ "$1" == postgres ]] && ! want_help "$@"; then
  [[ "$(id -u)" != 0 ]] || die "refusing to run as root. The image runs as UID 26 in GID 0; remove --user 0 (or runAsUser: 0)."
  : "${PGDATA:?PGDATA is not set}"

  # The volume is mounted at the parent of PGDATA (as in the Red Hat images),
  # so a fresh volume holds no data directory yet. initdb and the server both
  # require mode 0700 or 0750, owned by the server user.
  mkdir -p "$PGDATA"
  if [[ -O "$PGDATA" ]]; then
    chmod 0700 "$PGDATA"
  else
    die "${PGDATA} is owned by UID $(stat -c %u "$PGDATA"), not by UID $(id -u). A data directory from another image (the DHI image runs as UID 70) cannot be used here: dump it and restore it into a new volume."
  fi

  if [[ ! -s "${PGDATA}/PG_VERSION" ]]; then
    init_database
  else
    log "${PGDATA} holds a PostgreSQL $(< "${PGDATA}/PG_VERSION") cluster; skipping initialisation"
  fi
  unset POSTGRES_PASSWORD
fi

exec "$@"
