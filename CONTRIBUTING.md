# Contributing

Thanks for wanting to help! Tmux Opener is meant to stay small and simple, so the best
contributions are focused ones.

## Getting started

```sh
git clone https://github.com/SecureCMD/tmux-opener.git
cd tmux-opener
make run
```

You only need the Xcode Command Line Tools. You can also open `Package.swift` in Xcode.

## Guidelines

- **Keep it native.** SwiftUI and AppKit only — no third-party dependencies.
- **Localize strings.** Write UI text in English; SwiftUI picks string literals up as keys.
  Add the Spanish translation to `Resources/es.lproj/Localizable.strings`. For strings
  outside views, use `String(localized:)`.
- **Config compatibility.** New fields in `TmuxSession` must be optional when decoding
  (see `init(from:)`) so existing `sessions.json` files keep working.
- **Screenshots.** If you change the UI noticeably, run `scripts/screenshots.sh` and commit the
  updated images in `docs/images`.

## Releasing

1. Update `CHANGELOG.md`.
2. Tag and push: `git tag v1.2.0 && git push origin v1.2.0`.

GitHub Actions builds a universal app, signs and notarizes it (when the secrets below are set),
publishes the release with the zip attached and updates the version and checksum in
`Casks/tmux-opener.rb`, so `brew upgrade` picks it up.

## Code signing and notarization

Release builds are signed with a **Developer ID Application** certificate, use the hardened
runtime (with the Apple Events entitlement in `Resources/TmuxOpener.entitlements`), and are
notarized and stapled so Gatekeeper opens them without warnings. Without the secrets, CI falls
back to an ad-hoc signature.

### GitHub secrets

| Secret | What it is |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Developer ID Application certificate + private key, exported as `.p12`, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `NOTARY_KEY_P8` | App Store Connect API key (`AuthKey_XXXX.p8`), base64-encoded |
| `NOTARY_KEY_ID` | The API key's Key ID |
| `NOTARY_ISSUER_ID` | The Issuer ID shown on the App Store Connect API keys page |

To check them without publishing a release, run the **Build** workflow manually
(Actions → Build → Run workflow) with **Sign and notarize** ticked.

### Signing locally

```sh
# Once: store notary credentials in the keychain
xcrun notarytool store-credentials tmux-opener \
  --key AuthKey_XXXX.p8 --key-id <KEY_ID> --issuer <ISSUER_ID>

SIGN_IDENTITY="Developer ID Application: <Name> (<TEAM_ID>)" \
NOTARY_PROFILE=tmux-opener \
make release
```
