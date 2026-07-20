#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT_DIR"

JAVELLE_DEFAULT='/home/mohammed/.local/bin/javelle'
JAVELLE="${JAVELLE_CLI:-$JAVELLE_DEFAULT}"

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
