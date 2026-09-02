#!/bin/bash
# Wrap "Install Circle Sans.app" - or, while it cannot be signed, the font files
# themselves - in a disk image with the brand background.
#
#   build-installer-dmg.sh (--app APP | --fonts DIR) --out FILE.dmg
#                          --background bg.png --background-2x bg@2x.png
#                          [--icon FILE.icns] [--sign IDENTITY] [--dmgbuild PATH]
#
# --fonts copies the variable .ttf files in DIR into the image under short names
# (CircleSans.ttf, CircleSans-Italic.ttf): they fit under the icons, and they keep
# the CircleSans prefix that install-circle-sans.sh looks for when it sets old
# copies aside. Pass the matching background (render-installer-art.py renders one
# per kind).
#
# The layout is written straight into the image's .DS_Store by dmgbuild
# (pip install dmgbuild), so no Finder has to be scripted - it works on a headless
# runner. The two PNGs become one multi-resolution TIFF so Retina Finders get the
# sharp one. --sign signs the finished image; notarization is the caller's job.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP=""; FONTS=""; OUT=""; BG=""; BG2X=""; ICON=""; SIGN=""; DMGBUILD="dmgbuild"
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --fonts) FONTS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --background) BG="$2"; shift 2 ;;
    --background-2x) BG2X="$2"; shift 2 ;;
    --icon) ICON="$2"; shift 2 ;;
    --sign) SIGN="$2"; shift 2 ;;
    --dmgbuild) DMGBUILD="$2"; shift 2 ;;
    *) echo "unknown option: $1 (see the comment at the top of $0)" >&2; exit 2 ;;
  esac
done
if [ -n "$APP" ]; then
  [ -d "$APP" ] || { echo "--app must point at the built .app" >&2; exit 2; }
elif [ -n "$FONTS" ]; then
  [ -d "$FONTS" ] || { echo "--fonts must point at a directory of .ttf files" >&2; exit 2; }
else
  echo "one of --app or --fonts is required" >&2; exit 2
fi
[ -n "$OUT" ] && [ -f "$BG" ] && [ -f "$BG2X" ] || { echo "--out, --background and --background-2x are required" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

tiffutil -cathidpicheck "$BG" "$BG2X" -out "$WORK/background.tiff"

DEFINES=(-D "background=$WORK/background.tiff")
if [ -n "$APP" ]; then
  DEFINES+=(-D "app=$APP")
else
  mkdir -p "$WORK/fonts"
  for f in "$FONTS"/*.ttf; do
    name="$(basename "$f")"
    cp "$f" "$WORK/fonts/${name/\[wdth,wght\]/}"  # CircleSans[wdth,wght].ttf -> CircleSans.ttf
  done
  echo "Fonts in the image: $(ls "$WORK/fonts" | tr '\n' ' ')"
  DEFINES+=(-D "fonts=$WORK/fonts")
fi
[ -n "$ICON" ] && DEFINES+=(-D "icon=$ICON")
rm -f "$OUT"
"$DMGBUILD" -s "$HERE/installer-dmg.py" "${DEFINES[@]}" "Install Circle Sans" "$OUT"

if [ -n "$SIGN" ]; then
  codesign --force --timestamp --sign "$SIGN" "$OUT"
  echo "Signed as: $SIGN"
fi
echo "Built: $OUT"
