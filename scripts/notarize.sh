#!/bin/bash
# Send a zip or disk image to Apple's notary service, wait for the verdict, and
# staple the ticket to a target.
#
#   NOTARY_KEY=AuthKey.p8 NOTARY_KEY_ID=... NOTARY_ISSUER_ID=... \
#     notarize.sh FILE [--staple TARGET]
#
# FILE is what Apple scans: a zip of the app, or the finished .dmg. TARGET is what
# gets the ticket stapled on: the .app itself (the zip cannot carry a ticket) or
# the .dmg. On a rejection the notary log is printed, since it names the reason.
set -euo pipefail

FILE="${1:?usage: notarize.sh FILE [--staple TARGET]}"; shift
STAPLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --staple) STAPLE="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
: "${NOTARY_KEY:?set NOTARY_KEY to the .p8 file}" "${NOTARY_KEY_ID:?}" "${NOTARY_ISSUER_ID:?}"
AUTH=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")

echo "Notarizing $(basename "$FILE")…"
RESULT="$(xcrun notarytool submit "$FILE" "${AUTH[@]}" --wait --timeout 30m --output-format json)"
echo "$RESULT"
ID="$(jq -r .id <<<"$RESULT")"
STATUS="$(jq -r .status <<<"$RESULT")"
if [ "$STATUS" != "Accepted" ]; then
  xcrun notarytool log "$ID" "${AUTH[@]}" || true
  echo "Notarization of $(basename "$FILE") ended with status $STATUS - the log above says why" >&2
  exit 1
fi
if [ -n "$STAPLE" ]; then
  xcrun stapler staple "$STAPLE"
fi
