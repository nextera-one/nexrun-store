#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/tools"
BUNDLETOOL_JAR="$TOOLS_DIR/bundletool.jar"
FORCE=0

usage() {
  cat <<'EOF'
Usage: scripts/install-android-tools.sh [options]

Install local Android packaging tools used by generated Javelle scripts.

Options:
  --bundletool-only  Install only bundletool. This is the default today.
  --force            Re-download tools even when they already exist.
  -h, --help         Show this help.

Files:
  tools/bundletool.jar is used by scripts/build-aab.sh.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bundletool-only) ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

fetch() {
  URL="$1"
  OUTPUT="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL "$URL" -o "$OUTPUT"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -O "$OUTPUT" "$URL"
    return
  fi
  echo "error: curl or wget is required to download Android tools." >&2
  exit 1
}

fetch_text() {
  URL="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$URL"
    return
  fi
  echo "error: curl or wget is required to resolve Android tools." >&2
  exit 1
}

resolve_bundletool_url() {
  fetch_text "https://api.github.com/repos/google/bundletool/releases/latest"     | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*bundletool-all[^"]*\.jar\)".*/\1/p'     | head -n 1
}

if [ "$FORCE" = "0" ] && [ -f "$BUNDLETOOL_JAR" ]; then
  echo "bundletool already installed: $BUNDLETOOL_JAR"
  exit 0
fi

URL="$(resolve_bundletool_url)"
if [ -z "$URL" ]; then
  echo "error: could not resolve the latest bundletool download URL from GitHub." >&2
  exit 1
fi

mkdir -p "$TOOLS_DIR"
TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/javelle-bundletool-XXXXXX.jar")"
trap 'rm -f "$TMP_FILE"' EXIT HUP INT TERM

echo "Downloading bundletool:"
echo "  $URL"
fetch "$URL" "$TMP_FILE"

if command -v jar >/dev/null 2>&1; then
  jar tf "$TMP_FILE" >/dev/null
elif command -v unzip >/dev/null 2>&1; then
  unzip -tq "$TMP_FILE" >/dev/null
fi

mv "$TMP_FILE" "$BUNDLETOOL_JAR"
trap - EXIT HUP INT TERM
echo "Installed bundletool:"
echo "  $BUNDLETOOL_JAR"
