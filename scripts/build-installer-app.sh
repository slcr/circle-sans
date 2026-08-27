#!/bin/bash
# Wrap install-circle-sans.sh into a double-clickable "Install Circle Sans.app".
#
# The app is unsigned: signing needs a paid Apple Developer account. macOS will
# therefore refuse the first double-click on any Mac that downloaded it from a
# browser or Slack. Right-click the app and choose Open once, and macOS remembers.
# Sharing it as a zip on a drive people mount, rather than a download, avoids that.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-$HERE/../dist}"
APP="$OUT_DIR/Install Circle Sans.app"

mkdir -p "$OUT_DIR"
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
cp "$HERE/install-circle-sans.sh" "$APP/Contents/Resources/install-circle-sans.sh"
chmod +x "$APP/Contents/Resources/install-circle-sans.sh"

# Give it a name people recognise in the dock and the about box.
/usr/libexec/PlistBuddy -c "Set :CFBundleName 'Install Circle Sans'" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSHumanReadableCopyright string 'Circle Sans - SIL Open Font License 1.1'" "$APP/Contents/Info.plist" 2>/dev/null || true

# osacompile signs the bundle as it writes it, so the script and plist edits above
# leave that signature stale - macOS reads a stale signature as a damaged app and
# refuses to open it at all, which is worse than being merely unsigned. Re-sign
# ad-hoc, last, once the bundle is final.
codesign --force --sign - "$APP"
codesign --verify --strict "$APP" || {
  echo "The bundle failed signature verification - do not ship it." >&2
  exit 1
}

echo "Built: $APP"
