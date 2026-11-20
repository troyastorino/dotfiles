#!/bin/bash
# Mac-side installer for the lab CRM's texts sync: the part that needs no password. Idempotent:
# safe to re-run after pulling repo updates. Usage (on the Mac): ~/dotfiles/macos/imessage-crm/install.sh
#
# The sync is two LaunchAgents (README.md):
#   com.user.imessage-crm-read  reads Messages, Contacts and WhatsApp with Full Disk Access. Its code
#                               is a root-owned copy that install-reader.sh installs, not this folder.
#   com.user.imessage-crm-sync  sends the reader's export to the workspace and copies the text list
#                               back, over ssh, without Full Disk Access. It runs this folder's script.
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
  echo "This installer is for the Mac side. Run it on your Mac, not the workspace." >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
LIBEXEC=/usr/local/libexec/imessage-crm

# --- 1. Link the script into PATH (symlink, so git pull updates the transfer job) ---
mkdir -p "$HOME/.local/bin"
ln -sf "$DIR/imessage-crm-sync" "$HOME/.local/bin/imessage-crm-sync"
echo "==> Linked ~/.local/bin/imessage-crm-sync -> $DIR/imessage-crm-sync"

# --- 2. Install and (re)start the LaunchAgents ---
# The transfer job watches ~/.cache/imessage-crm/out, so the folder must exist first.
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$HOME/.cache/imessage-crm/out"
load() {
  local plist="$HOME/Library/LaunchAgents/$1.plist"
  sed "s|__HOME__|$HOME|g" "$DIR/$1.plist" >"$plist"
  launchctl unload "$plist" 2>/dev/null || true
  launchctl load "$plist"
  echo "==> LaunchAgent $1 loaded. Log: ~/Library/Logs/imessage-crm-sync.log"
}
load com.user.imessage-crm-sync
# The reader only once install-reader.sh has put its code in place. Until then no texts leave the Mac.
if [ -x "$LIBEXEC/imessage-crm-read" ]; then
  load com.user.imessage-crm-read
  if ! cmp -s "$DIR/imessage-crm-sync" "$LIBEXEC/imessage-crm-sync.py" || ! cmp -s "$DIR/launcher.c" "$LIBEXEC/launcher.c"; then
    echo "dotfiles: the texts reader runs an older copy of imessage-crm-sync or launcher.c. Run $DIR/install-reader.sh to update it." >&2
  fi
else
  echo "dotfiles: the texts reader isn't installed, so no texts leave the Mac. Run $DIR/install-reader.sh." >&2
fi

# Stamp for the startup check in zsh-functions (dotfiles-mac-check): files in this
# directory newer than the stamp mean the install is stale.
touch "$HOME/.cache/imessage-crm/installed"

HOST="$(cat "$HOME/.config/imessage-crm/host" 2>/dev/null || echo coder.troy-workspace)"
echo "==> The transfer job connects to $HOST. To use another SSH host, write its name to ~/.config/imessage-crm/host."
