#!/bin/bash
# Install the latest released Circle Sans into ~/Library/Fonts.
#
# Fonts in ~/Library/Fonts are active the moment they land there - macOS needs no
# separate activation step. What does need care is what was already installed: an
# older Circle Sans left in place gives macOS two families of the same name, and
# apps then pick whichever they like. So every Circle Sans file is set aside first
# and the release is installed on its own.
#
# Progress goes to stderr, the summary to stdout, so the .app wrapper can show the
# summary in a dialog.

set -euo pipefail

REPO="slcr/circle-sans"
FONT_DIR="$HOME/Library/Fonts"
BACKUP_ROOT="$HOME/Library/Application Support/Circle Sans"

say() { printf '%s\n' "$1" >&2; }
die() { printf '%s\n' "$1" >&2; exit 1; }

command -v curl  >/dev/null || die "curl is missing - it ships with macOS, so this Mac is unusual. Install the font by hand from https://github.com/$REPO/releases/latest"
command -v unzip >/dev/null || die "unzip is missing - it ships with macOS, so this Mac is unusual. Install the font by hand from https://github.com/$REPO/releases/latest"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

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

# Only install what we can see is there: never clear the old fonts on a bad download.
NEW_FONTS=()
while IFS= read -r f; do NEW_FONTS+=("$f"); done < <(find "$WORK/unpacked" -name '*.ttf' -type f | sort)
[ "${#NEW_FONTS[@]}" -gt 0 ] || die "The download contained no fonts. Tell the design team - release $TAG looks broken."

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

printf 'Circle Sans %s is installed.\n\nQuit and reopen Figma (and any other app you want it in) so it picks up the new version.' "$TAG"
if [ -n "$BACKUP" ]; then
  printf '\n\nThe version you had before was moved to:\n%s' "$BACKUP"
fi
printf '\n'
