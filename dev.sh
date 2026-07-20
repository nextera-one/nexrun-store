#!/usr/bin/env sh
# dev.sh - run the Javelle app in development with hot reload enabled.
#
# Thin wrapper around run.sh that flips on the dev-server hot reload, prefers
# the standalone `javelle` CLI when present, and makes sure the dev-server
# port is free before launching.
#
# Usage:
#   ./dev.sh                 # web mode on the default port, hot reload on
#   ./dev.sh web 8080        # explicit mode + port
#   ./dev.sh 8080            # a leading number is treated as the port
#
# Port handling: if the target port is busy, dev.sh shows what's holding it
# and offers to kill that process, fall back to the next free port, or quit.
# With JAVELLE_PORT_STRATEGY set the prompt is skipped.
#
# Environment (all optional):
#   JAVELLE_MODE           Mode when no positional mode is given (default: web).
#   JAVELLE_PORT           Port when none is passed (default: 8181).
#   JAVELLE_CLI            Path to the javelle CLI; auto-detected if on PATH.
#   JAVELLE_PORT_STRATEGY  Non-interactive busy-port policy: "next" or "kill".
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

MODE="${JAVELLE_MODE:-web}"
PORT=""

if [ "$#" -gt 0 ]; then
  case "$1" in
    ''|*[!0-9]*)
      MODE="$1"
      shift
      ;;
  esac
fi
if [ "$#" -gt 0 ]; then
  case "$1" in
    ''|*[!0-9]*) ;;
    *) PORT="$1"; shift ;;
  esac
fi
[ -n "$PORT" ] || PORT="${JAVELLE_PORT:-8181}"

port_in_use() {
  _p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltnH "( sport = :$_p )" 2>/dev/null | grep -q . && return 0 || return 1
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$_p" -sTCP:LISTEN -t >/dev/null 2>&1 && return 0 || return 1
  elif command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$_p" >/dev/null 2>&1 && return 0 || return 1
  fi
  return 1
}

port_holder_pids() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnpH "( sport = :$1 )" 2>/dev/null \
      | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u
  fi
}

describe_holder() {
  _pids="$(port_holder_pids "$1" || true)"
  [ -n "$_pids" ] || return 0
  for _pid in $_pids; do
    _cmd="$(ps -p "$_pid" -o args= 2>/dev/null || true)"
    printf '    pid %s: %s\n' "$_pid" "${_cmd:-?}"
  done
}

next_free_port() {
  _p="$1"
  while port_in_use "$_p"; do
    _p=$((_p + 1))
    [ "$_p" -le 65535 ] || { echo "error: no free port found." >&2; exit 1; }
  done
  echo "$_p"
}

if port_in_use "$PORT"; then
  echo "Port $PORT is already in use:" >&2
  describe_holder "$PORT" >&2

  STRATEGY="${JAVELLE_PORT_STRATEGY:-}"
  if [ -z "$STRATEGY" ]; then
    if [ -t 0 ]; then
      printf 'Choose: [k]ill the process, [n]ext free port, [q]uit? ' >&2
      read -r REPLY </dev/tty || REPLY="q"
      case "$REPLY" in
        k|K) STRATEGY="kill" ;;
        n|N) STRATEGY="next" ;;
        *)   echo "Aborted." >&2; exit 1 ;;
      esac
    else
      STRATEGY="next"
      echo "(non-interactive: falling back to the next free port)" >&2
    fi
  fi

  case "$STRATEGY" in
    kill)
      PIDS="$(port_holder_pids "$PORT" || true)"
      if [ -z "$PIDS" ]; then
        echo "error: couldn't identify the process on port $PORT (need lsof/ss with -p)." >&2
        exit 1
      fi
      echo "Killing: $PIDS" >&2
      # shellcheck disable=SC2086
      kill $PIDS 2>/dev/null || true
      _tries=0
      while port_in_use "$PORT"; do
        _tries=$((_tries + 1))
        [ "$_tries" -le 20 ] || { echo "error: port $PORT still busy after kill; trying SIGKILL." >&2; kill -9 $PIDS 2>/dev/null || true; break; }
        sleep 0.25
      done
      if port_in_use "$PORT"; then
        echo "error: port $PORT is still in use." >&2
        exit 1
      fi
      echo "Port $PORT is now free." >&2
      ;;
    next)
      NEWPORT="$(next_free_port "$PORT")"
      echo "Using next free port: $NEWPORT" >&2
      PORT="$NEWPORT"
      ;;
  esac
fi

export JAVELLE_HOT_RELOAD=1
export JAVELLE_PORT="$PORT"

if [ -z "${JAVELLE_CLI:-}" ] && command -v javelle >/dev/null 2>&1; then
  JAVELLE_CLI="$(command -v javelle)"
  export JAVELLE_CLI
fi

exec "$ROOT_DIR/run.sh" "$MODE" "$PORT" "$@"
