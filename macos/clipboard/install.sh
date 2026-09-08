#!/bin/bash
# Mac-side installer for the clipboard bridge. Idempotent, so it is safe to re-run
# after pulling repo updates (restarts the listener to pick up changes).
#
# Usage (on the Mac): ~/dotfiles/macos/clipboard/install.sh
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
  echo "This installer is for the Mac side. Run it on your Mac, not the workspace." >&2
  exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
  echo "The listener runs on /usr/bin/python3, which needs the Xcode Command Line Tools." >&2
  echo "Install them first: xcode-select --install" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.user.clipboard-listener"
PORT=7778

# --- 1. Link the listener into PATH (symlink so git pull updates it) ---
mkdir -p "$HOME/.local/bin"
ln -sf "$DIR/clipboard-listener" "$HOME/.local/bin/clipboard-listener"
echo "==> Linked ~/.local/bin/clipboard-listener -> $DIR/clipboard-listener"

# --- 2. SSH RemoteForward for coder hosts ---
# Appending is safe: ssh accumulates forwarding directives from every
# matching Host block, so this works regardless of where the Coder-managed
# block or the openhtml block sits.
SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
# Both Coder alias styles: <agent>.<workspace>.<owner>.coder and coder.<ws>
HOST_PATTERN='*.coder coder.*'
if grep -q "RemoteForward $PORT " "$SSH_CONFIG"; then
  echo "==> RemoteForward $PORT already present in ~/.ssh/config"
else
  cat >>"$SSH_CONFIG" <<CONF

# clipboard bridge tunnel (added by dotfiles macos/clipboard/install.sh)
Host $HOST_PATTERN
  RemoteForward $PORT 127.0.0.1:$PORT
CONF
  chmod 600 "$SSH_CONFIG"
  echo "==> Added RemoteForward $PORT to ~/.ssh/config under 'Host $HOST_PATTERN'"
  echo "    (if your Coder SSH aliases match neither pattern, edit the Host line)"
fi

# --- 3. Install and (re)start the LaunchAgent ---
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.cache/clipboard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
sed "s|__HOME__|$HOME|g" "$DIR/$LABEL.plist" >"$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "==> Listener installed and running"

# A check right after launchctl load once reported the job missing while it
# was in fact loaded, so poll for a few seconds instead of checking once.
loaded=false
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if launchctl list | grep -q "$LABEL"; then loaded=true; break; fi
  sleep 0.5
done
if $loaded; then
  echo "==> Verified: $LABEL is loaded"
else
  echo "WARNING: $LABEL did not load. Check $HOME/.cache/clipboard/listener.log" >&2
  exit 1
fi

echo
echo "Done. Check the listener here on the Mac first (copy a screenshot, then):"
printf '%s\n' "  printf 'png\\n' | nc 127.0.0.1 $PORT > /tmp/clip.png && open /tmp/clip.png"
echo "Then reconnect SSH (forwards only apply to new connections) and press"
echo "Ctrl+V in Claude Code on the workspace."
