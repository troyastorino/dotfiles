#!/bin/bash
# Mac-side installer for openhtml/servehtml. Idempotent — safe to re-run
# after pulling repo updates (restarts the listener to pick up changes).
#
# Usage (on the Mac): ~/dotfiles/macos/openhtml/install.sh
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
  echo "This installer is for the Mac side — run it on your Mac, not the workspace." >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.user.openhtml-listener"

# --- 1. Link the listener into PATH (symlink so git pull updates it) ---
mkdir -p "$HOME/.local/bin"
ln -sf "$DIR/openhtml-listener" "$HOME/.local/bin/openhtml-listener"
echo "==> Linked ~/.local/bin/openhtml-listener -> $DIR/openhtml-listener"

# --- 2. SSH forwards for coder.* hosts ---
# Appending is safe: ssh accumulates forwarding directives from every
# matching Host block, so this works regardless of where the Coder-managed
# block sits.
SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
# Both Coder alias styles: <agent>.<workspace>.<owner>.coder and coder.<ws>
HOST_PATTERN='*.coder coder.*'
MARKER='added by dotfiles macos/openhtml/install.sh'
if grep -q "RemoteForward 7777" "$SSH_CONFIG"; then
  # Check the Host line of OUR block (the line right after the marker
  # comment) — the Coder-managed block elsewhere in the file may also start
  # with 'Host *.coder', so a whole-file grep would false-positive.
  if grep -A1 "$MARKER" "$SSH_CONFIG" | grep -q '^Host \*\.coder'; then
    echo "==> SSH forwards already present in ~/.ssh/config"
  elif grep -q "$MARKER" "$SSH_CONFIG"; then
    # Migrate a block written by an older install.sh whose Host pattern
    # (coder.*) missed <agent>.<ws>.<owner>.coder style aliases.
    sed -i '' \
      -e "/$(printf '%s' "$MARKER" | sed 's|/|\\/|g')/{" \
      -e 'n' \
      -e "s/^Host .*/Host $HOST_PATTERN/" \
      -e '}' \
      "$SSH_CONFIG"
    echo "==> Updated SSH config Host pattern to '$HOST_PATTERN'"
  else
    echo "==> RemoteForward 7777 exists in ~/.ssh/config but wasn't added by"
    echo "    this installer — make sure its Host pattern covers: $HOST_PATTERN"
  fi
else
  cat >>"$SSH_CONFIG" <<EOF

# openhtml/servehtml tunnels (added by dotfiles macos/openhtml/install.sh)
Host $HOST_PATTERN
  RemoteForward 7777 127.0.0.1:7777
  LocalForward 8080 127.0.0.1:8080
EOF
  chmod 600 "$SSH_CONFIG"
  echo "==> Added forwards to ~/.ssh/config under 'Host $HOST_PATTERN'"
  echo "    (if your Coder SSH aliases match neither pattern, edit the Host line)"
fi

# --- 3. Install and (re)start the LaunchAgent ---
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.cache/openhtml"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
sed "s|__HOME__|$HOME|g" "$DIR/$LABEL.plist" >"$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "==> Listener installed and running"

if launchctl list | grep -q "$LABEL"; then
  echo "==> Verified: $LABEL is loaded"
else
  echo "WARNING: $LABEL did not load — check $HOME/.cache/openhtml/listener.log" >&2
  exit 1
fi

echo
echo "Done. Reconnect SSH (forwards only apply to new connections), then test"
echo "from a workspace tmux pane:"
echo "  echo '<h1>hi</h1>' > /tmp/t.html && openhtml /tmp/t.html"
