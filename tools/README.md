# Javelle Project Tools

Generated Android packaging scripts keep local helper tools in this directory.

- `bundletool.jar` is installed by `scripts/install-android-tools.sh` and used by `scripts/build-aab.sh`.
- APK signing keys are stored under `.javelle/android/debug-keystores/` unless you provide an upload keystore through environment variables.

The tool files are project-local so generated apps can build APK/AAB outputs without requiring global installs beyond Java, Maven, and the Android SDK.
