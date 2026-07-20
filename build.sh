#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT_DIR"

JAVELLE_DEFAULT='/home/mohammed/.local/bin/javelle'
JAVELLE="${JAVELLE_CLI:-$JAVELLE_DEFAULT}"
MAVEN_WARNING_OPTION="--sun-misc-unsafe-memory-access=allow"
MAVEN_WARNING_JAVA="java"
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  MAVEN_WARNING_JAVA="$JAVA_HOME/bin/java"
elif [ -x "$HOME/.sdkman/candidates/java/current/bin/java" ]; then
  MAVEN_WARNING_JAVA="$HOME/.sdkman/candidates/java/current/bin/java"
fi

compile_jvl() {
  SOURCE_PACKAGE="app"
  if [ -f "$ROOT_DIR/javelle.config.json" ]; then
    SOURCE_PACKAGE="$(sed -n 's/.*"sourcePackage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT_DIR/javelle.config.json" | head -n 1)"
  fi
  SOURCE_PACKAGE="${SOURCE_PACKAGE:-app}"
  RESOURCE_ROOT="$ROOT_DIR/src/main/resources/$(printf '%s' "$SOURCE_PACKAGE" | tr '.' '/')"
  JVL_SOURCE=""
  if [ -d "$RESOURCE_ROOT" ]; then
    JVL_SOURCE="$(find "$RESOURCE_ROOT" -type f -name '*.jvl' | sed -n '1p')"
  fi
  if [ -n "$JVL_SOURCE" ]; then
    echo "Compiling Javelle .jvl templates..."
    "$JAVELLE" jvl "$RESOURCE_ROOT"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./build.sh [mode ...]

Build one or more Javelle target modes.

Examples:
  ./build.sh
  ./build.sh spa
  ./build.sh ssr pwa
  ./build.sh android ios desktop
  ./build.sh all

Notes:
  - spa is an alias for web.
  - non-web modes are added automatically before build.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ -z "${JAVELLE_DISABLE_MAVEN_WARNING_FLAGS:-}" ]; then
  if "$MAVEN_WARNING_JAVA" "$MAVEN_WARNING_OPTION" -version >/dev/null 2>&1; then
    case " ${MAVEN_OPTS:-} " in
      *" $MAVEN_WARNING_OPTION "*) ;;
      *)
        MAVEN_OPTS="${MAVEN_OPTS:+$MAVEN_OPTS }$MAVEN_WARNING_OPTION"
        export MAVEN_OPTS
        ;;
    esac
  fi
fi

if [ "$#" -eq 0 ]; then
  set -- "${JAVELLE_MODE:-web}"
fi

compile_jvl

for MODE in "$@"; do
  if [ "$MODE" = "spa" ]; then
    MODE="web"
  fi
  if [ "$MODE" = "all" ]; then
    if [ -x "./add.sh" ]; then
      ./add.sh all
    fi
    echo "Building Javelle app in all enabled modes..."
    "$JAVELLE" build --mode all
    continue
  fi
  if [ "$MODE" != "web" ] && [ -x "./add.sh" ]; then
    ./add.sh "$MODE"
  fi
  echo "Building Javelle app in $MODE mode..."
  "$JAVELLE" build --mode "$MODE"
done
