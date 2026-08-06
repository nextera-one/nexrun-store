#!/usr/bin/env sh
# fetch-web-fonts.sh - download every web font this site uses and generate the
# self-hosted @font-face sheet.
#
# The Store's whole subject is verifiable trust, so the page must not reach out
# to fonts.googleapis.com at runtime: an external request leaks every viewer's
# IP to a third party and breaks the site on air-gapped hosts. All fonts are
# committed to the repository and served from the same origin as the app.
#
# Re-run this only to refresh or extend the fonts. It rewrites:
#   src/main/resources/fonts/**                        (text faces)
#   src/main/resources/icons/material-symbols/**       (icon face)
#   src/main/resources/styles/fonts-self-hosted.css    (generated @font-face)
#
# The icon font is subset to exactly the icons referenced by the templates, so
# the committed file stays ~10 KB instead of the 5.3 MB full variable font.
# OfflineAssetsTest fails the build if a template uses an icon outside that set.
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
RESOURCES="$ROOT_DIR/src/main/resources"
FONT_DIR="$RESOURCES/fonts"
ICON_DIR="$RESOURCES/icons/material-symbols"
SHEET="$RESOURCES/styles/fonts-self-hosted.css"

# The css2 endpoint returns woff2 only for browsers it recognises.
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

TEXT_URL='https://fonts.googleapis.com/css2?family=Inter:wght@400..800&family=JetBrains+Mono:wght@400..700&display=swap'
ICON_AXES='opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200'

command -v curl >/dev/null 2>&1 || { echo "error: curl is required." >&2; exit 1; }
command -v awk >/dev/null 2>&1 || { echo "error: awk is required." >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$FONT_DIR" "$ICON_DIR" "$(dirname "$SHEET")"

# ---------------------------------------------------------------------------
# 1. Text faces: Inter and JetBrains Mono, latin + latin-ext only.
# ---------------------------------------------------------------------------
echo "Fetching text font stylesheet..."
curl -fsS -A "$UA" "$TEXT_URL" -o "$WORK/text.css"

# Keep the latin and latin-ext blocks, rewrite each remote src to a local path,
# and record the download list. unicode-range is preserved from the response.
awk -v work="$WORK" '
  /^\/\* .* \*\/$/ { subset = $2; next }
  /@font-face/     { inblock = 1; buf = $0 "\n"; next }
  inblock {
    if ($0 ~ /font-family:/) {
      family = $0
      sub(/.*font-family: *./, "", family)
      sub(/.;.*/, "", family)
      slug = tolower(family)
      gsub(/ /, "-", slug)
    }
    if ($0 ~ /src: url\(/) {
      url = $0
      sub(/.*src: url\(/, "", url)
      sub(/\).*/, "", url)
      path = "/fonts/" slug "/" slug "-" subset ".woff2"
      print url "\t" path >> (work "/downloads.tsv")
      buf = buf "  src: url(\"" path "\") format(\"woff2\");\n"
      next
    }
    if ($0 ~ /^\}/) {
      inblock = 0
      if (subset == "latin" || subset == "latin-ext") { printf "%s}\n\n", buf }
      next
    }
    buf = buf $0 "\n"
  }
' "$WORK/text.css" > "$WORK/text-faces.css"

sort -u "$WORK/downloads.tsv" > "$WORK/downloads.uniq"
while IFS='	' read -r url path; do
  case "$path" in
    /fonts/*-latin.woff2|/fonts/*-latin-ext.woff2) ;;
    *) continue ;;
  esac
  target="$RESOURCES$path"
  mkdir -p "$(dirname "$target")"
  echo "  -> $path"
  curl -fsS -A "$UA" "$url" -o "$target"
done < "$WORK/downloads.uniq"

# ---------------------------------------------------------------------------
# 2. Icon face: Material Symbols Rounded, subset to the icons actually used.
# ---------------------------------------------------------------------------
echo "Collecting icon names from templates..."
# Match name= anywhere inside the tag: <j-icon class="x" name="y"> is as common
# as <j-icon name="y">, and missing one silently ships a blank glyph.
ICON_NAMES="$(grep -roh '<j-icon[^>]*>' "$RESOURCES" \
  | grep -o 'name="[a-z_0-9]*"' | sed 's/name="//; s/"//' | sort -u | paste -sd, -)"
[ -n "$ICON_NAMES" ] || { echo "error: no j-icon names found." >&2; exit 1; }
echo "  $(printf '%s' "$ICON_NAMES" | tr ',' '\n' | grep -c .) icons"

echo "Fetching subset icon font..."
curl -fsS -A "$UA" -G \
  --data-urlencode "family=Material Symbols Rounded:$ICON_AXES" \
  --data-urlencode "icon_names=$ICON_NAMES" \
  "https://fonts.googleapis.com/css2" -o "$WORK/icons.css"

ICON_URL="$(grep -o 'https://fonts.gstatic.com[^)]*' "$WORK/icons.css" | head -n 1)"
[ -n "$ICON_URL" ] || { echo "error: no icon font URL in the response." >&2; exit 1; }
curl -fsS -A "$UA" "$ICON_URL" -o "$ICON_DIR/material-symbols-rounded.woff2"
echo "  -> /icons/material-symbols/material-symbols-rounded.woff2"

# Record exactly which glyphs the subset contains. OfflineAssetsTest compares
# this list against the templates, so a newly referenced icon fails the build
# instead of silently rendering as a blank box.
{
  echo "# Icons contained in material-symbols-rounded.woff2 — GENERATED."
  echo "# Regenerate with ./tools/fetch-web-fonts.sh after adding a <j-icon>."
  printf '%s\n' "$ICON_NAMES" | tr ',' '\n'
} > "$ICON_DIR/subset-icons.txt"
echo "  -> /icons/material-symbols/subset-icons.txt"

# ---------------------------------------------------------------------------
# 3. Generate the stylesheet.
# ---------------------------------------------------------------------------
{
  cat <<'EOF'
/* =============================================================================
   Self-hosted web fonts — GENERATED, do not edit by hand.
   -----------------------------------------------------------------------------
   Regenerate with ./tools/fetch-web-fonts.sh

   Every face below is served from this origin. The Store must work on an
   air-gapped host and must not disclose a viewer's IP address to a third
   party, so no rule here may become a remote @import again. OfflineAssetsTest
   fails the build if one does.

   The Material Symbols face is subset to the icons the templates reference.
   Adding a new <j-icon name="..."> means re-running the fetch script;
   OfflineAssetsTest fails the build if you forget.
   ========================================================================== */

EOF
  cat "$WORK/text-faces.css"
  cat <<'EOF'
@font-face {
  font-family: "Material Symbols Rounded";
  font-style: normal;
  font-weight: 100 700;
  font-display: block;
  src: url("/icons/material-symbols/material-symbols-rounded.woff2") format("woff2");
}
EOF
} > "$SHEET"

echo "Wrote $SHEET"
echo
echo "Self-hosted assets:"
find "$FONT_DIR" "$ICON_DIR" -name '*.woff2' -exec ls -l {} \; | awk '{printf "  %8d  %s\n", $5, $9}'
