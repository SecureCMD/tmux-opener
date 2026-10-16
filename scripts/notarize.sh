#!/bin/bash
# Notarizes an app bundle with Apple and staples the ticket to it.
#
# Usage: scripts/notarize.sh "build/Tmux Opener.app"
#
# Credentials (one of):
#   NOTARY_PROFILE=<name>     keychain profile saved with
#                             `xcrun notarytool store-credentials <name>`
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID
#                             App Store Connect API key (.p8), used in CI
set -euo pipefail

APP="${1:?usage: scripts/notarize.sh <app>}"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    AUTH=(--keychain-profile "$NOTARY_PROFILE")
elif [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
    AUTH=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER_ID:?}")
else
    echo "error: set NOTARY_PROFILE, or NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_ISSUER_ID" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ditto -c -k --keepParent "$APP" "$TMP/upload.zip"

echo "▸ Submitting to the Apple notary service (usually takes a few minutes)…"
OUT="$(xcrun notarytool submit "$TMP/upload.zip" "${AUTH[@]}" --wait --output-format json || true)"
field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2], ""))' "$OUT" "$1" 2>/dev/null || true; }
STATUS="$(field status)"
ID="$(field id)"

if [[ "$STATUS" != "Accepted" ]]; then
    echo "error: notarization failed (status: ${STATUS:-unknown})" >&2
    echo "$OUT" >&2
    [[ -n "$ID" ]] && xcrun notarytool log "$ID" "${AUTH[@]}" >&2 || true
    exit 1
fi

echo "▸ Notarized ($ID), stapling ticket"
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"
