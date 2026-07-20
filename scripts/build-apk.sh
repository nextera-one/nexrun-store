#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_TITLE="$(sed -n 's/.*"appName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT_DIR/javelle.config.json" | head -n 1)"
SOURCE_PACKAGE="$(sed -n 's/.*"sourcePackage"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$ROOT_DIR/javelle.config.json" | head -n 1)"
APP_TITLE="${APP_TITLE:-$(basename "$ROOT_DIR")}"
SOURCE_PACKAGE="${SOURCE_PACKAGE:-app}"
ANDROID_PACKAGE="${JAVELLE_ANDROID_PACKAGE:-$SOURCE_PACKAGE.android}"
OUTPUT_NAME="${JAVELLE_ANDROID_OUTPUT_NAME:-$(basename "$ROOT_DIR")}"
SKIP_AAB=0
AAB_ONLY=0
INSTALL_APK=0
PREPARE_ASSETS_ONLY=0
NATIVE_VIEW=0

usage() {
  cat <<'EOF'
Usage: scripts/build-apk.sh [options]

Build this Javelle project as a signed Android debug APK and optional AAB.

Options:
  --android-package <id> Override the generated Android package id.
  --title <name>         Override the Android app label.
  --output-name <name>   Output filename prefix.
  --native-view          Use Javelle Native Android views as the launcher.
  --prepare-assets-only  Generate target/javelle/android/android and stop.
  --skip-aab             Build only the APK.
  --aab-only             Build only the AAB output.
  --install              Install the APK with adb after building.
  -h, --help             Show this help.

Environment:
  ANDROID_SDK_ROOT or ANDROID_HOME must point to an installed Android SDK.
  BUNDLETOOL_JAR can point to bundletool.jar when bundletool is not on PATH.
  JAVELLE_ANDROID_KEYSTORE can point to an upload keystore.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --android-package) shift; [ "$#" -gt 0 ] || { echo "error: --android-package requires a value" >&2; exit 1; }; ANDROID_PACKAGE="$1" ;;
    --android-package=*) ANDROID_PACKAGE="${1#--android-package=}" ;;
    --title) shift; [ "$#" -gt 0 ] || { echo "error: --title requires a value" >&2; exit 1; }; APP_TITLE="$1" ;;
    --title=*) APP_TITLE="${1#--title=}" ;;
    --output-name) shift; [ "$#" -gt 0 ] || { echo "error: --output-name requires a value" >&2; exit 1; }; OUTPUT_NAME="$1" ;;
    --output-name=*) OUTPUT_NAME="${1#--output-name=}" ;;
    --native-view) NATIVE_VIEW=1 ;;
    --prepare-assets-only) PREPARE_ASSETS_ONLY=1 ;;
    --skip-aab) SKIP_AAB=1 ;;
    --aab-only) AAB_ONLY=1; SKIP_AAB=0 ;;
    --install) INSTALL_APK=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if [ "$PREPARE_ASSETS_ONLY" = "1" ] && [ "$INSTALL_APK" = "1" ]; then
  echo "error: --prepare-assets-only cannot be combined with --install." >&2
  exit 1
fi
if [ "$AAB_ONLY" = "1" ] && [ "$INSTALL_APK" = "1" ]; then
  echo "error: --aab-only cannot be combined with --install." >&2
  exit 1
fi
case "$ANDROID_PACKAGE" in
  ""|*[!A-Za-z0-9_.]*|.*|*.) echo "error: invalid Android package id: $ANDROID_PACKAGE" >&2; exit 1 ;;
esac

java_supports_option() {
  java "$1" -version >/dev/null 2>&1
}

java_tool_options() {
  OPTIONS=""
  if java_supports_option "--enable-native-access=ALL-UNNAMED"; then
    OPTIONS="$OPTIONS --enable-native-access=ALL-UNNAMED"
  fi
  if java_supports_option "--sun-misc-unsafe-memory-access=allow"; then
    OPTIONS="$OPTIONS --sun-misc-unsafe-memory-access=allow"
  fi
  printf '%s\n' "$OPTIONS"
}

run_apksigner() {
  APKSIGNER_JAR="$BUILD_TOOLS_DIR/lib/apksigner.jar"
  if [ -f "$APKSIGNER_JAR" ]; then
    java $(java_tool_options) -jar "$APKSIGNER_JAR" "$@"
  else
    "$APKSIGNER" "$@"
  fi
}

resolve_android_sdk() {
  ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [ -z "$ANDROID_SDK" ] || [ ! -d "$ANDROID_SDK/platforms" ]; then
    echo "error: Android SDK was not found. Set ANDROID_SDK_ROOT or ANDROID_HOME." >&2
    exit 1
  fi
  LATEST_PLATFORM="$(find "$ANDROID_SDK/platforms" -maxdepth 1 -type d -name 'android-*' | sed 's/^.*android-//' | sort -n | tail -n 1)"
  if [ -z "$LATEST_PLATFORM" ]; then
    echo "error: no Android platform was found under $ANDROID_SDK/platforms." >&2
    exit 1
  fi
  BUILD_TOOLS_DIR="$(find "$ANDROID_SDK/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
  if [ -z "$BUILD_TOOLS_DIR" ]; then
    echo "error: no Android build-tools installation was found." >&2
    exit 1
  fi
  ANDROID_JAR="$ANDROID_SDK/platforms/android-$LATEST_PLATFORM/android.jar"
  AAPT2="$BUILD_TOOLS_DIR/aapt2"
  D8="$BUILD_TOOLS_DIR/d8"
  ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
  APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
  for TOOL in "$ANDROID_JAR" "$AAPT2" "$D8" "$ZIPALIGN" "$APKSIGNER"; do
    if [ ! -e "$TOOL" ]; then
      echo "error: required Android build file is missing: $TOOL" >&2
      exit 1
    fi
  done
  for TOOL in zip keytool javac; do
    if ! command -v "$TOOL" >/dev/null 2>&1; then
      echo "error: $TOOL was not found on PATH." >&2
      exit 1
    fi
  done
}

default_debug_keystore() {
  KEYSTORE_NAME="$(printf '%s' "$ANDROID_PACKAGE" | tr -c 'A-Za-z0-9._-' '_')"
  printf '%s/.javelle/android/debug-keystores/%s.keystore\n' "$ROOT_DIR" "$KEYSTORE_NAME"
}

configure_signing() {
  DEBUG_KEYSTORE="${JAVELLE_ANDROID_DEBUG_KEYSTORE:-$(default_debug_keystore)}"
  JAVELLE_APK_KEYSTORE="${JAVELLE_ANDROID_KEYSTORE:-${ANDROID_KEYSTORE:-$DEBUG_KEYSTORE}}"
  JAVELLE_APK_KEY_ALIAS="${JAVELLE_ANDROID_KEY_ALIAS:-${ANDROID_KEY_ALIAS:-androiddebugkey}}"
  JAVELLE_APK_KEYSTORE_PASS="${JAVELLE_ANDROID_KEYSTORE_PASS:-${ANDROID_KEYSTORE_PASS:-android}}"
  JAVELLE_APK_KEY_PASS="${JAVELLE_ANDROID_KEY_PASS:-${ANDROID_KEY_PASS:-$JAVELLE_APK_KEYSTORE_PASS}}"
  if [ "$JAVELLE_APK_KEYSTORE" = "$DEBUG_KEYSTORE" ] && [ ! -f "$JAVELLE_APK_KEYSTORE" ]; then
    mkdir -p "$(dirname "$JAVELLE_APK_KEYSTORE")"
    keytool -genkeypair -keystore "$JAVELLE_APK_KEYSTORE" -storepass "$JAVELLE_APK_KEYSTORE_PASS" -keypass "$JAVELLE_APK_KEY_PASS" -alias "$JAVELLE_APK_KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null
  fi
  if [ ! -f "$JAVELLE_APK_KEYSTORE" ]; then
    echo "error: APK signing keystore was not found: $JAVELLE_APK_KEYSTORE" >&2
    exit 1
  fi
  if [ "$JAVELLE_APK_KEYSTORE" = "$DEBUG_KEYSTORE" ]; then
    SIGNING_LABEL="debug"
  else
    SIGNING_LABEL="upload"
  fi
}

run_bundletool() {
  if command -v bundletool >/dev/null 2>&1; then
    bundletool "$@"
    return
  fi
  BUNDLETOOL="${JAVELLE_BUNDLETOOL_JAR:-${BUNDLETOOL_JAR:-}}"
  if [ -z "$BUNDLETOOL" ]; then
    for CANDIDATE in "$ROOT_DIR/bundletool.jar" "$ROOT_DIR/tools/bundletool.jar"; do
      if [ -f "$CANDIDATE" ]; then
        BUNDLETOOL="$CANDIDATE"
        break
      fi
    done
  fi
  if [ -z "$BUNDLETOOL" ] || [ ! -f "$BUNDLETOOL" ]; then
    if [ -x "$ROOT_DIR/scripts/install-android-tools.sh" ]; then
      echo "==> bundletool not found; installing a project-local copy"
      "$ROOT_DIR/scripts/install-android-tools.sh" --bundletool-only
      BUNDLETOOL="$ROOT_DIR/tools/bundletool.jar"
    fi
  fi
  if [ -z "$BUNDLETOOL" ] || [ ! -f "$BUNDLETOOL" ]; then
    echo "error: bundletool was not found. Run scripts/install-android-tools.sh or set BUNDLETOOL_JAR=/path/to/bundletool.jar." >&2
    exit 1
  fi
  java $(java_tool_options) -jar "$BUNDLETOOL" "$@"
}

build_aab() {
  for TOOL in java jarsigner unzip zip; do
    if ! command -v "$TOOL" >/dev/null 2>&1; then
      echo "error: $TOOL was not found on PATH." >&2
      exit 1
    fi
  done
  AAB_WORK_DIR="$BUILD_DIR/aab"
  RAW_MODULE="$AAB_WORK_DIR/base-raw.zip"
  MODULE_DIR="$AAB_WORK_DIR/base"
  MODULE_ZIP="$AAB_WORK_DIR/base.zip"
  UNSIGNED_AAB="$AAB_WORK_DIR/unsigned.aab"
  rm -rf "$AAB_WORK_DIR"
  mkdir -p "$AAB_WORK_DIR/generated" "$MODULE_DIR" "$BUNDLE_DIR"
  "$AAPT2" link --proto-format -I "$ANDROID_JAR" --manifest "$ANDROID_DIR/AndroidManifest.xml" -A "$ANDROID_DIR/src/main/assets" -R "$BUILD_DIR/compiled/resources.zip" --auto-add-overlay --java "$AAB_WORK_DIR/generated" --min-sdk-version 23 --target-sdk-version "$LATEST_PLATFORM" --version-code 1 --version-name 1.0 -o "$RAW_MODULE"
  unzip -q "$RAW_MODULE" -d "$MODULE_DIR"
  if [ ! -f "$MODULE_DIR/AndroidManifest.xml" ]; then
    echo "error: aapt2 did not produce an AndroidManifest.xml for the AAB base module." >&2
    exit 1
  fi
  mkdir -p "$MODULE_DIR/manifest" "$MODULE_DIR/dex"
  mv "$MODULE_DIR/AndroidManifest.xml" "$MODULE_DIR/manifest/AndroidManifest.xml"
  cp "$BUILD_DIR/dex/classes.dex" "$MODULE_DIR/dex/classes.dex"
  (cd "$MODULE_DIR" && zip -qr "$MODULE_ZIP" .)
  run_bundletool build-bundle --modules="$MODULE_ZIP" --output="$UNSIGNED_AAB" --overwrite
  rm -f "$FINAL_AAB"
  jarsigner -keystore "$JAVELLE_APK_KEYSTORE" -storepass "$JAVELLE_APK_KEYSTORE_PASS" -keypass "$JAVELLE_APK_KEY_PASS" -signedjar "$FINAL_AAB" "$UNSIGNED_AAB" "$JAVELLE_APK_KEY_ALIAS" >/dev/null
  run_bundletool validate --bundle="$FINAL_AAB" >/dev/null
  jarsigner -verify "$FINAL_AAB" >/dev/null
}

echo "==> Preparing Android target through Javelle CLI"
if [ "$NATIVE_VIEW" = "1" ]; then
  JAVELLE_ANDROID_NATIVE_VIEW=1 "$ROOT_DIR/build.sh" android
else
  "$ROOT_DIR/build.sh" android
fi

BUILD_OUTPUT="$ROOT_DIR/target/javelle/android"
ANDROID_DIR="$BUILD_OUTPUT/android"
ASSET_SRC="$BUILD_OUTPUT/www"
if [ ! -d "$ANDROID_DIR" ]; then
  echo "error: Android target was not generated correctly under $BUILD_OUTPUT." >&2
  exit 1
fi
rm -rf "$ANDROID_DIR/src/main/assets/www"
mkdir -p "$ANDROID_DIR/src/main/assets"
if [ "$NATIVE_VIEW" = "1" ]; then
  echo "==> Skipping packaged web assets for native-view APK"
else
  if [ ! -d "$ASSET_SRC" ]; then
    echo "error: Android web assets were not generated correctly under $ASSET_SRC." >&2
    exit 1
  fi
  cp -R "$ASSET_SRC" "$ANDROID_DIR/src/main/assets/www"
fi

if [ "$PREPARE_ASSETS_ONLY" = "1" ]; then
  echo "==> Android project ready:"
  echo "    $ANDROID_DIR"
  exit 0
fi

resolve_android_sdk
configure_signing

ANDROID_SRC_DIR="$ANDROID_DIR/src/main/java/$(printf '%s' "$ANDROID_PACKAGE" | tr '.' '/')"
GENERATED_ACTIVITY="$ANDROID_DIR/src/main/java/$(printf '%s' "$SOURCE_PACKAGE.android" | tr '.' '/')/MainActivity.java"
if [ "$ANDROID_PACKAGE" != "$SOURCE_PACKAGE.android" ] && [ -f "$GENERATED_ACTIVITY" ]; then
  mkdir -p "$ANDROID_SRC_DIR"
  sed "s/^package .*/package $ANDROID_PACKAGE;/" "$GENERATED_ACTIVITY" > "$ANDROID_SRC_DIR/MainActivity.java"
  sed "s/package=\"[^\"]*\"/package=\"$ANDROID_PACKAGE\"/" "$ANDROID_DIR/AndroidManifest.xml" > "$ANDROID_DIR/AndroidManifest.xml.tmp"
  mv "$ANDROID_DIR/AndroidManifest.xml.tmp" "$ANDROID_DIR/AndroidManifest.xml"
fi

BUILD_DIR="$ANDROID_DIR/build"
APK_DIR="$BUILD_DIR/outputs/apk/debug"
BUNDLE_DIR="$BUILD_DIR/outputs/bundle/debug"
UNSIGNED_APK="$BUILD_DIR/$OUTPUT_NAME-unsigned.apk"
ALIGNED_APK="$BUILD_DIR/$OUTPUT_NAME-aligned.apk"
FINAL_APK="$APK_DIR/$OUTPUT_NAME-debug.apk"
FINAL_AAB="$BUNDLE_DIR/$OUTPUT_NAME-debug.aab"

echo "==> Building Android package with SDK android-$LATEST_PLATFORM"
rm -rf "$BUILD_DIR/compiled" "$BUILD_DIR/generated" "$BUILD_DIR/classes" "$BUILD_DIR/dex"
mkdir -p "$BUILD_DIR/compiled" "$BUILD_DIR/generated" "$BUILD_DIR/classes" "$BUILD_DIR/dex" "$APK_DIR" "$BUNDLE_DIR"

"$AAPT2" compile --dir "$ANDROID_DIR/res" -o "$BUILD_DIR/compiled/resources.zip"
"$AAPT2" link -I "$ANDROID_JAR" --manifest "$ANDROID_DIR/AndroidManifest.xml" -A "$ANDROID_DIR/src/main/assets" -R "$BUILD_DIR/compiled/resources.zip" --auto-add-overlay --java "$BUILD_DIR/generated" --min-sdk-version 23 --target-sdk-version "$LATEST_PLATFORM" --version-code 1 --version-name 1.0 -o "$UNSIGNED_APK"
find "$BUILD_DIR/generated" "$ANDROID_DIR/src/main/java" -name '*.java' > "$BUILD_DIR/java-sources.txt"
javac --release 8 -Xlint:-options -Xlint:-deprecation -classpath "$ANDROID_JAR" -d "$BUILD_DIR/classes" @"$BUILD_DIR/java-sources.txt"
CLASS_FILES="$(find "$BUILD_DIR/classes" -name '*.class')"
if [ -z "$CLASS_FILES" ]; then
  echo "error: no compiled Android classes were produced." >&2
  exit 1
fi
"$D8" --lib "$ANDROID_JAR" --output "$BUILD_DIR/dex" $CLASS_FILES
(cd "$BUILD_DIR/dex" && zip -q -u "$UNSIGNED_APK" classes.dex)

if [ "$AAB_ONLY" = "0" ]; then
  "$ZIPALIGN" -f -p 4 "$UNSIGNED_APK" "$ALIGNED_APK"
  run_apksigner sign --ks "$JAVELLE_APK_KEYSTORE" --ks-key-alias "$JAVELLE_APK_KEY_ALIAS" --ks-pass "pass:$JAVELLE_APK_KEYSTORE_PASS" --key-pass "pass:$JAVELLE_APK_KEY_PASS" --out "$FINAL_APK" "$ALIGNED_APK"
  run_apksigner verify --print-certs "$FINAL_APK" >/dev/null
fi

if [ "$SKIP_AAB" = "0" ]; then
  echo "==> Building Android App Bundle"
  build_aab
fi

if [ "$INSTALL_APK" = "1" ]; then
  if ! command -v adb >/dev/null 2>&1; then
    echo "error: adb was not found on PATH." >&2
    exit 1
  fi
  echo "==> Installing APK to connected Android device"
  adb install -r "$FINAL_APK"
fi

if [ "$AAB_ONLY" = "0" ]; then
  echo "==> APK ready:"
  echo "    $FINAL_APK"
  echo "==> APK signed with $SIGNING_LABEL keystore:"
  echo "    $JAVELLE_APK_KEYSTORE"
fi
if [ "$SKIP_AAB" = "0" ]; then
  echo "==> AAB ready:"
  echo "    $FINAL_AAB"
fi
