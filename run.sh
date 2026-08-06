#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT_DIR"

MODE="${JAVELLE_MODE:-web}"
if [ "$#" -gt 0 ]; then
  MODE="$1"
  shift
fi
if [ "$MODE" = "spa" ]; then
  MODE="web"
fi
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

run_native_source() {
  NATIVE_MODE="$1"
  NATIVE_SOURCE="$2"
  shift 2
  if [ -x "./add.sh" ]; then
    ./add.sh "$NATIVE_MODE"
  fi

  compile_jvl

  echo "Building Javelle $NATIVE_MODE native source..."
  "$JAVELLE" native build "$NATIVE_MODE" --skip-maven "$@"

  SOURCE="$ROOT_DIR/$NATIVE_SOURCE"
  if [ ! -f "$SOURCE" ]; then
    echo "error: native source was not generated at $SOURCE" >&2
    exit 1
  fi
  echo "Generated native source: $SOURCE"
}

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

if [ "$MODE" = "android" ]; then
  run_native_source android "target/javelle/android/android/src/main/java/$(sed -n 's/.*"sourcePackage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT_DIR/javelle.config.json" | head -n 1 | tr '.' '/')/NativeMainActivity.java" "$@"
  exit 0
fi
if [ "$MODE" = "ios" ]; then
  run_native_source ios "target/javelle/ios/ios/JavelleNativeScreen.swift" "$@"
  exit 0
fi
if [ "$MODE" = "desktop" ]; then
  run_native_source desktop "target/javelle/desktop/desktop/JavelleNativeScreen.java" "$@"
  exit 0
fi
if [ "$MODE" = "ubuntu-touch" ]; then
  run_native_source ubuntu-touch "target/javelle/ubuntu-touch/ubuntu-touch/JavelleNativeScreen.qml" "$@"
  exit 0
fi
if [ "$MODE" = "windows-mobile" ]; then
  run_native_source windows-mobile "target/javelle/windows-mobile/windows-mobile/JavelleNativeScreen.xaml" "$@"
  exit 0
fi

PORT="${1:-${JAVELLE_PORT:-8080}}"

if [ "$MODE" != "web" ] && [ -x "./add.sh" ]; then
  ./add.sh "$MODE"
fi

compile_jvl

echo "Packaging Javelle app..."
mvn package

echo "Starting Javelle dev server: mode=$MODE port=$PORT"
exec "$JAVELLE" dev --mode "$MODE" --port "$PORT"
