# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Homebrew cask: `brew tap securecmd/tmux-opener https://github.com/SecureCMD/tmux-opener`
  then `brew install --cask tmux-opener`. The release workflow keeps it up to date.

## [1.0.0] - 2026-10-16

### Added

- Session list with one-click launch in iTerm (new window or tab, any profile).
- SSH sessions (user, host, port, extra options) and local sessions.
- tmux options: session name, binary path and iTerm integration (`-CC`).
- Custom command mode and a live command preview.
- Colors and SF Symbols per session; light and dark mode.
- Search, drag-to-reorder, duplicate and copy command.
- Menu bar extra and <kbd>⌘1</kbd>…<kbd>⌘9</kbd> shortcuts.
- JSON config with import/export and a `-configDirectory` override.
- English and Spanish localizations.

[1.0.0]: https://github.com/SecureCMD/tmux-opener/releases/tag/v1.0.0
