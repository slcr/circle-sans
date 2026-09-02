#!/bin/bash
# Wrap "Install Circle Sans.app" in a disk image with the brand background.
#
#   build-installer-dmg.sh --app APP --out FILE.dmg --background bg.png --background-2x bg@2x.png
#                          [--icon FILE.icns] [--sign IDENTITY] [--dmgbuild PATH]
#
# The layout is written straight into the image's .DS_Store by dmgbuild
# (pip install dmgbuild), so no Finder has to be scripted - it works on a headless
# runner. The two PNGs become one multi-resolution TIFF so Retina Finders get the
# sharp one. --sign signs the finished image; notarization is the caller's job.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP=""; OUT=""; BG=""; BG2X=""; ICON=""; SIGN=""; DMGBUILD="dmgbuild"
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --background) BG="$2"; shift 2 ;;
    --background-2x) BG2X="$2"; shift 2 ;;
    --icon) ICON="$2"; shift 2 ;;
    --sign) SIGN="$2"; shift 2 ;;
    --dmgbuild) DMGBUILD="$2"; shift 2 ;;
    *) echo "unknown option: $1 (see the comment at the top of $0)" >&2; exit 2 ;;
  esac
done
[ -d "$APP" ] || { echo "--app must point at the built .app" >&2; exit 2; }
[ -n "$OUT" ] && [ -f "$BG" ] && [ -f "$BG2X" ] || { echo "--out, --background and --background-2x are required" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

tiffutil -cathidpicheck "$BG" "$BG2X" -out "$WORK/background.tiff"

DEFINES=(-D "app=$APP" -D "background=$WORK/background.tiff")
[ -n "$ICON" ] && DEFINES+=(-D "icon=$ICON")
rm -f "$OUT"
"$DMGBUILD" -s "$HERE/installer-dmg.py" "${DEFINES[@]}" "Install Circle Sans" "$OUT"

if [ -n "$SIGN" ]; then
  codesign --force --timestamp --sign "$SIGN" "$OUT"
  echo "Signed as: $SIGN"
fi
echo "Built: $OUT"
