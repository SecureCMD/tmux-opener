cask "tmux-opener" do
  version "1.0.0"
  sha256 "5c8c8e036b0eb1391bbcadf511c9d85520538bababd61ff2a023fb7a8a3daf62"

  url "https://github.com/SecureCMD/tmux-opener/releases/download/v#{version}/TmuxOpener-#{version}.zip"
  name "Tmux Opener"
  desc "Open tmux sessions, local or over SSH, in iTerm with one click"
  homepage "https://github.com/SecureCMD/tmux-opener"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Tmux Opener.app"

  # The app is ad-hoc signed but not notarized; drop the quarantine flag so
  # Gatekeeper doesn't block the first launch.
  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Tmux Opener.app"],
        writable_paths: ["Tmux Opener.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.securecmd.tmuxopener"

  zap trash: [
    "~/Library/Application Support/TmuxOpener",
    "~/Library/Preferences/com.securecmd.tmuxopener.plist",
  ]

  caveats <<~EOS
    Tmux Opener opens sessions in iTerm2. If you don't have it yet:
      brew install --cask iterm2
  EOS
end
