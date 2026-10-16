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

GitHub Actions builds a universal app, publishes the release with the zip attached and updates
the version and checksum in `Casks/tmux-opener.rb`, so `brew upgrade` picks it up.
