#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT_DIR"

# Resolve the Javelle CLI: explicit JAVELLE_CLI first, then PATH, then the
# usual per-user install location. Never hardcode a developer's home directory
# here -- CI runners and other machines have neither.
resolve_javelle() {
  if [ -n "${JAVELLE_CLI:-}" ]; then
    printf '%s\n' "$JAVELLE_CLI"
    return 0
  fi
  if command -v javelle >/dev/null 2>&1; then
    command -v javelle
    return 0
  fi
  if [ -x "$HOME/.local/bin/javelle" ]; then
    printf '%s\n' "$HOME/.local/bin/javelle"
    return 0
  fi
  echo "error: the Javelle CLI was not found." >&2
  echo "       Install it (see README.md, 'Run locally') or set JAVELLE_CLI to its path." >&2
  return 1
}

JAVELLE="$(resolve_javelle)"

usage() {
  cat <<'EOF'
Usage: ./add.sh [mode ...]

Enable Javelle target modes for this app.

Examples:
  ./add.sh mobile
  ./add.sh ssr pwa
  ./add.sh all

When no mode is passed, this script enables all built-in modes.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ "$#" -eq 0 ]; then
  set -- all
fi

for MODE in "$@"; do
  echo "Adding Javelle mode: $MODE"
  "$JAVELLE" mode add "$MODE"
done

echo "Enabled modes:"
"$JAVELLE" mode list
