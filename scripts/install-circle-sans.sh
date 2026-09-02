#!/bin/bash
# Install Circle Sans into ~/Library/Fonts.
#
# The fonts come from one of two places:
#   * Bundled: a fonts/ folder and a VERSION file beside this script. That is how the
#     "Install Circle Sans.app" from build-installer-app.sh ships - the release travels
#     inside the app, so installing needs no network and cannot end up with a different
#     version than the one that was downloaded.
#   * Downloaded: otherwise the newest GitHub release is fetched. That is the path when
#     this script is run on its own.
#
# Fonts in ~/Library/Fonts are active the moment they land there - macOS needs no
# separate activation step. What does need care is what was already installed: an
# older Circle Sans left in place gives macOS two families of the same name, and
# apps then pick whichever they like. So every Circle Sans file is set aside first
# and the release is installed on its own. A copy in /Library/Fonts (installed for
# all users) cannot be moved without an admin password, so that one is reported.
#
# Progress goes to stderr, the summary to stdout, so the .app wrapper can show the
# summary in a dialog.

set -euo pipefail

REPO="slcr/circle-sans"
FONT_DIR="$HOME/Library/Fonts"
SYSTEM_FONT_DIR="/Library/Fonts"
BACKUP_ROOT="$HOME/Library/Application Support/Circle Sans"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

say() { printf '%s\n' "$1" >&2; }
die() { printf '%s\n' "$1" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ -f "$HERE/VERSION" ] && [ -d "$HERE/fonts" ]; then
  TAG="$(tr -d '[:space:]' < "$HERE/VERSION")"
  SRC="$HERE/fonts"
  say "Installing the bundled Circle Sans $TAG…"
else
  command -v curl  >/dev/null || die "curl is missing - it ships with macOS, so this Mac is unusual. Install the font by hand from https://github.com/$REPO/releases/latest"
  command -v unzip >/dev/null || die "unzip is missing - it ships with macOS, so this Mac is unusual. Install the font by hand from https://github.com/$REPO/releases/latest"

  say "Looking up the latest release…"
  API="https://api.github.com/repos/$REPO/releases/latest"
  if ! curl -fsSL --max-time 30 "$API" -o "$WORK/release.json"; then
    die "Could not reach GitHub. Check the network and try again; if it keeps failing, download the font from https://github.com/$REPO/releases/latest"
  fi

  # Pull the tag and the variable-fonts asset URL without needing jq.
  TAG="$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WORK/release.json" | head -1)"
  URL="$(sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*variable\.zip\)".*/\1/p' "$WORK/release.json" | head -1)"
  [ -n "$TAG" ] || die "GitHub's answer didn't contain a release tag. It may be rate-limiting this network; wait a few minutes and try again."
  [ -n "$URL" ] || die "Release $TAG has no variable-font download. Tell the design team - the release is probably incomplete."

  say "Downloading Circle Sans $TAG…"
  curl -fsSL --max-time 120 "$URL" -o "$WORK/fonts.zip" || die "The download failed. Check the network and try again."
  unzip -q -o "$WORK/fonts.zip" -d "$WORK/unpacked" || die "The download arrived damaged. Try again."
  SRC="$WORK/unpacked"
fi

# Only install what we can see is there: never clear the old fonts for nothing.
NEW_FONTS=()
while IFS= read -r f; do NEW_FONTS+=("$f"); done < <(find "$SRC" -name '*.ttf' -type f | sort)
[ "${#NEW_FONTS[@]}" -gt 0 ] || die "There are no fonts to install. Tell the design team - release $TAG looks broken."

mkdir -p "$FONT_DIR"

# Set aside every Circle Sans already installed - statics from an old zip included,
# since a leftover static family competes with the variable one.
OLD=()
while IFS= read -r f; do OLD+=("$f"); done < <(find "$FONT_DIR" -maxdepth 1 \( -name 'CircleSans*.ttf' -o -name 'CircleSans*.otf' \) -type f | sort)
BACKUP=""
if [ "${#OLD[@]}" -gt 0 ]; then
  BACKUP="$BACKUP_ROOT/replaced-$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$BACKUP"
  say "Setting aside ${#OLD[@]} font file(s) already installed…"
  for f in "${OLD[@]}"; do mv "$f" "$BACKUP/"; done
fi

say "Installing ${#NEW_FONTS[@]} font file(s)…"
for f in "${NEW_FONTS[@]}"; do
  if ! cp "$f" "$FONT_DIR/"; then
    # Put the old fonts back rather than leaving the Mac with none.
    [ -n "$BACKUP" ] && cp "$BACKUP"/* "$FONT_DIR/" 2>/dev/null || true
    die "Could not write to $FONT_DIR. The previous fonts have been put back."
  fi
done

# A copy installed for all users would shadow the one just installed. Only report it:
# moving it needs an admin password, and a dialog is no place to ask for one.
SYSTEM_OLD=()
while IFS= read -r f; do SYSTEM_OLD+=("$f"); done < <(find "$SYSTEM_FONT_DIR" -maxdepth 1 \( -name 'CircleSans*.ttf' -o -name 'CircleSans*.otf' \) -type f 2>/dev/null | sort)

printf 'Circle Sans %s is installed.\n' "$TAG"
printf '\nApps only pick up new fonts when they start. Quit and reopen the ones you want to use it in - Figma, Illustrator, Keynote, your browser. Closing a window is not enough: quit the app properly, then open it again.\n'
if [ "${#SYSTEM_OLD[@]}" -gt 0 ]; then
  printf '\nThere is also a Circle Sans installed for all users in %s, and it can hide this version:\n' "$SYSTEM_FONT_DIR"
  for f in "${SYSTEM_OLD[@]}"; do printf '  %s\n' "$(basename "$f")"; done
  printf 'Remove it with an admin password, or ask IT to.\n'
fi
if [ -n "$BACKUP" ]; then
  printf '\nThe version you had before was moved to:\n%s\n' "$BACKUP"
fi
