#!/bin/bash
# Build "Install Circle Sans.app": a small native window around install-circle-sans.sh.
#
#   build-installer-app.sh [--out DIR] [--fonts DIR] [--version vX.Y] [--icon FILE.icns] [--sign IDENTITY]
#
#   --out      Where to put the app. Default: dist/ next to the repo.
#   --fonts    Copy these .ttf files into the app, so it installs them offline instead
#              of downloading the newest release when run. CI passes the variable fonts
#              it just built, which makes the app a self-contained copy of that release.
#              The app also uses them for its own window, so it is set in Circle Sans.
#   --version  Stamped into the bundle and shown in the "installed" message.
#   --icon     An .icns for the app (see render-installer-art.py).
#   --sign     A "Developer ID Application: ..." identity. With it the app is signed with
#              the hardened runtime and a secure timestamp, which is what notarization
#              requires; the release workflow does that and staples the ticket. Without
#              it the app is signed ad hoc: it runs on the Mac that built it, but macOS
#              refuses the first double-click on any Mac that downloaded it - fine for a
#              local test, not for shipping.
#
# The app is a single Swift file (installer-app/main.swift) compiled for both Apple
# silicon and Intel; it needs Xcode or the command line tools. It replaced an
# AppleScript applet whose blocked event loop showed a spinning cursor the whole time.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$HERE/../dist"
FONTS=""
VERSION="dev"
ICON=""
SIGN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2 ;;
    --fonts) FONTS="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --icon) ICON="$2"; shift 2 ;;
    --sign) SIGN="$2"; shift 2 ;;
    *) echo "unknown option: $1 (see the comment at the top of $0)" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR"
APP="$OUT_DIR/Install Circle Sans.app"
rm -rf "$APP"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
mkdir -p "$MACOS" "$RES"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# One binary for both architectures. macOS 11 is the floor: it is the first release
# with the Swift runtime built in, so nothing has to be bundled.
SRC="$HERE/installer-app/main.swift"
for arch in arm64 x86_64; do
  xcrun swiftc -O -swift-version 5 -target "${arch}-apple-macos11.0" -o "$WORK/$arch" "$SRC"
done
lipo -create -output "$MACOS/Install Circle Sans" "$WORK/arm64" "$WORK/x86_64"

sed "s/__VERSION__/${VERSION#v}/g" "$HERE/installer-app/Info.plist" > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

cp "$HERE/install-circle-sans.sh" "$RES/install-circle-sans.sh"
chmod +x "$RES/install-circle-sans.sh"

# The fonts ride inside the app; install-circle-sans.sh looks for exactly this pair.
if [ -n "$FONTS" ]; then
  mkdir -p "$RES/fonts"
  cp "$FONTS"/*.ttf "$RES/fonts/"
  printf '%s\n' "$VERSION" > "$RES/VERSION"
  echo "Bundled $(ls "$RES/fonts" | wc -l | tr -d ' ') font file(s) as $VERSION"
fi

if [ -n "$ICON" ]; then
  cp "$ICON" "$RES/AppIcon.icns"
fi

if [ -n "$SIGN" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGN" "$APP"
  echo "Signed as: $SIGN"
else
  codesign --force --sign - "$APP"
  echo "Signed ad hoc (not for distribution)"
fi
codesign --verify --strict --verbose=1 "$APP" || {
  echo "The bundle failed signature verification - do not ship it." >&2
  exit 1
}

echo "Built: $APP"
