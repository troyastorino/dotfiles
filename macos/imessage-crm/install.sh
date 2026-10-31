#!/bin/bash
# Mac-side installer for the lab CRM's texts sync. Idempotent: safe to re-run after pulling
# repo updates. Usage (on the Mac): ~/dotfiles/macos/imessage-crm/install.sh
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
  echo "This installer is for the Mac side. Run it on your Mac, not the workspace." >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.user.imessage-crm-sync"

# --- 1. Link the script into PATH (symlink, so git pull updates it) ---
mkdir -p "$HOME/.local/bin"
ln -sf "$DIR/imessage-crm-sync" "$HOME/.local/bin/imessage-crm-sync"
echo "==> Linked ~/.local/bin/imessage-crm-sync -> $DIR/imessage-crm-sync"

# --- 2. Install and (re)start the LaunchAgent, which runs the script every hour ---
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$HOME/.cache/imessage-crm"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
sed "s|__HOME__|$HOME|g" "$DIR/$LABEL.plist" >"$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "==> LaunchAgent $LABEL loaded. Log: ~/Library/Logs/imessage-crm-sync.log"

# Stamp for the startup check in zsh-functions (dotfiles-mac-check): files in this
# directory newer than the stamp mean the install is stale.
touch "$HOME/.cache/imessage-crm/installed"

# --- 3. What only you can do: Full Disk Access ---
APP="$(/usr/bin/python3 -c 'import os, sys; print(os.path.join(sys.base_prefix, "Resources", "Python.app"))')"
HOST="$(cat "$HOME/.config/imessage-crm/host" 2>/dev/null || echo coder.troy-workspace)"
cat <<MSG

Give Full Disk Access to these two, once, so the job can read Messages and Contacts:
  /usr/bin/python3
  $APP
System Settings > Privacy & Security > Full Disk Access > +, then Cmd+Shift+G and paste each path.

Then run the job and read its log:
  launchctl kickstart -k gui/\$(id -u)/$LABEL; sleep 20; tail ~/Library/Logs/imessage-crm-sync.log

It connects to $HOST. To use another SSH host, write its name to ~/.config/imessage-crm/host.
MSG
