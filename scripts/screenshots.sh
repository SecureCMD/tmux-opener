#!/bin/bash
# Regenerates the README screenshots in docs/images using demo data.
# Usage: scripts/screenshots.sh   (run scripts/build.sh first)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Tmux Opener.app"
[[ -d "$APP" ]] || { echo "Build the app first: make app" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/config" "$WORK/shots" docs/images

# Demo sessions with fresh "last connected" times.
python3 - "$WORK/config/sessions.json" <<'EOF'
import datetime, json, sys, uuid
now = datetime.datetime.now(datetime.timezone.utc)
def ago(**kw): return (now - datetime.timedelta(**kw)).strftime("%Y-%m-%dT%H:%M:%SZ")
def session(name, user, host, sess, symbol, color, last=None, cc=True, port=None, tmux="tmux", opts=""):
    d = dict(id=str(uuid.uuid4()).upper(), name=name, user=user, host=host, sessionName=sess,
             symbol=symbol, colorName=color, controlMode=cc, tmuxPath=tmux, sshOptions=opts,
             useCustomCommand=False, customCommand="")
    if port: d["port"] = port
    if last: d["lastConnected"] = last
    return d
json.dump([
    session("Mac mini", "alex", "mac-mini.local", "main", "macmini", "indigo", ago(minutes=4), tmux="/opt/homebrew/bin/tmux"),
    session("Homelab", "alex", "homelab.lan", "homelab", "server.rack", "teal", ago(hours=2)),
    session("Production API", "deploy", "api.example.com", "prod", "cloud", "orange", ago(days=1), port=2222),
    session("Raspberry Pi", "pi", "raspberrypi.local", "sensors", "cpu", "pink", ago(days=3), cc=False),
    session("Build Server", "ci", "build.example.com", "builds", "hammer", "purple", opts="-A"),
    session("This Mac", "", "", "scratch", "laptopcomputer", "green", ago(minutes=40)),
], open(sys.argv[1], "w"), indent=2)
EOF

pkill -x TmuxOpener 2>/dev/null || true
for appearance in light dark; do
    echo "▸ Capturing $appearance"
    open -W -n "$APP" --args \
        -configDirectory "$WORK/config" \
        -screenshotDir "$WORK/shots" \
        -screenshotAppearance "$appearance" \
        -AppleLanguages '(en)' -AppleLocale en_US
done

swift scripts/compose_hero.swift "$WORK/shots" >/dev/null
for f in "$WORK"/shots/*.png; do
    # Shrink to keep the repo light; images are still 2x for a ~900 pt wide README.
    sips -Z 1800 "$f" --out "docs/images/$(basename "$f")" >/dev/null
done
cp build/AppIcon.iconset/icon_256x256@2x.png docs/images/icon.png
echo "✓ Screenshots written to docs/images"
