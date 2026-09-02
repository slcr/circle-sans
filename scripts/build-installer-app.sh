#!/bin/bash
# Wrap install-circle-sans.sh into a double-clickable "Install Circle Sans.app".
#
#   build-installer-app.sh [--out DIR] [--fonts DIR] [--version vX.Y] [--icon FILE.icns] [--sign IDENTITY]
#
#   --out      Where to put the app. Default: dist/ next to the repo.
#   --fonts    Copy these .ttf files into the app, so it installs them offline instead
#              of downloading the newest release when run. CI passes the variable fonts
#              it just built, which makes the app a self-contained copy of that release.
#   --version  Stamped into the bundle and shown in the "installed" message.
#   --icon     An .icns to replace the generic script icon (see render-installer-icon.py).
#   --sign     A "Developer ID Application: ..." identity. With it the app is signed with
#              the hardened runtime and a secure timestamp, which is what notarization
#              requires; the release workflow does that and staples the ticket. Without
#              it the app is signed ad hoc: it runs on the Mac that built it, but macOS
#              refuses the first double-click on any Mac that downloaded it - fine for a
#              local test, not for shipping.
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

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
cat > "$SRC/main.applescript" <<'APPLESCRIPT'
on run
	set installer to POSIX path of (path to resource "install-circle-sans.sh")
	try
		set summary to do shell script "/bin/bash " & quoted form of installer
		display dialog summary with title "Circle Sans" buttons {"Done"} default button "Done"
	on error message number code
		-- -128 is the user pressing Cancel on an authentication prompt; not an error worth reporting.
		if code is not -128 then
			display dialog message with title "Circle Sans" buttons {"OK"} default button "OK" with icon stop
		end if
	end try
end run
APPLESCRIPT

osacompile -o "$APP" "$SRC/main.applescript"
RES="$APP/Contents/Resources"
PLIST="$APP/Contents/Info.plist"

cp "$HERE/install-circle-sans.sh" "$RES/install-circle-sans.sh"
chmod +x "$RES/install-circle-sans.sh"

# The fonts ride inside the app; install-circle-sans.sh looks for exactly this pair.
if [ -n "$FONTS" ]; then
  mkdir -p "$RES/fonts"
  cp "$FONTS"/*.ttf "$RES/fonts/"
  printf '%s\n' "$VERSION" > "$RES/VERSION"
  echo "Bundled $(ls "$RES/fonts" | wc -l | tr -d ' ') font file(s) as $VERSION"
fi

# osacompile names its icon applet.icns; replacing the file is enough.
if [ -n "$ICON" ]; then
  cp "$ICON" "$RES/applet.icns"
fi

# Set a key, adding it if the applet template did not have it.
plist_set() {
  /usr/libexec/PlistBuddy -c "Set :$1 '$2'" "$PLIST" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :$1 string '$2'" "$PLIST"
}
plist_set CFBundleName "Install Circle Sans"
plist_set CFBundleDisplayName "Install Circle Sans"
plist_set CFBundleIdentifier "com.coffeecircle.circle-sans.installer"
plist_set CFBundleShortVersionString "${VERSION#v}"
plist_set CFBundleVersion "${VERSION#v}"
plist_set CFBundleIconFile "applet"
plist_set NSHumanReadableCopyright "Circle Sans - SIL Open Font License 1.1"

# osacompile signs the bundle as it writes it, so every edit above leaves that
# signature stale - macOS reads a stale signature as a damaged app and refuses to
# open it at all, which is worse than being merely unsigned. Sign last, once the
# bundle is final.
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
