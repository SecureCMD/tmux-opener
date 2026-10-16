#!/bin/bash
# CI helper: imports the Developer ID certificate and the notary API key from
# base64-encoded secrets, and exports SIGN_IDENTITY / NOTARY_KEY_PATH to later steps.
#
# Env: MACOS_CERTIFICATE_P12, MACOS_CERTIFICATE_PASSWORD, NOTARY_KEY_P8, RUNNER_TEMP, GITHUB_ENV
set -euo pipefail

KEYCHAIN="$RUNNER_TEMP/signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
CERT="$RUNNER_TEMP/certificate.p12"

echo "$MACOS_CERTIFICATE_P12" | base64 --decode > "$CERT"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERT" -P "$MACOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
# shellcheck disable=SC2046
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
rm -f "$CERT"

IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')"
if [[ -z "$IDENTITY" ]]; then
    echo "error: no 'Developer ID Application' identity in the certificate" >&2
    exit 1
fi
echo "Signing identity: $IDENTITY"
echo "SIGN_IDENTITY=$IDENTITY" >> "$GITHUB_ENV"

echo "$NOTARY_KEY_P8" | base64 --decode > "$RUNNER_TEMP/notary_key.p8"
echo "NOTARY_KEY_PATH=$RUNNER_TEMP/notary_key.p8" >> "$GITHUB_ENV"
