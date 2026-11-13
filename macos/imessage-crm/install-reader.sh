#!/bin/bash
# Installs the texts reader, the one part of the lab CRM's texts sync with Full Disk Access.
# Copies imessage-crm-sync into a root-owned folder, builds and signs the launcher from launcher.c
# when it changed, then runs install.sh to load both LaunchAgents. Asks for your password to copy.
# Run it by hand on the Mac; install.sh says when the reader's copy is out of date.
#
# Usage: ~/dotfiles/macos/imessage-crm/install-reader.sh
set -euo pipefail

for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

if [ "$(uname)" != "Darwin" ]; then
  echo "This installer is for the Mac side. Run it on your Mac, not the workspace." >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
LIBEXEC=/usr/local/libexec/imessage-crm
LAUNCHER="$LIBEXEC/imessage-crm-read"
LABEL=com.user.imessage-crm-read

# --- 1. Check the folders ---
# Code running as you can rename a folder inside any folder you can write to, and so swap the
# reader out. So every folder from / down to the reader's must belong to root and be writable
# by no one else. The launcher checks this again at each run.
for d in / /usr /usr/local /usr/local/libexec "$LIBEXEC"; do
  [ -e "$d" ] || continue  # install -d below creates a missing folder as root
  owner="$(stat -f %Su "$d")"
  mode="$(stat -f %Lp "$d")"
  if [ "$owner" != root ] || (( 8#$mode & 8#022 )); then
    echo "$d belongs to $owner with mode $mode. The reader's folders must belong to root and be writable only by root. Nothing was installed." >&2
    exit 1
  fi
done

# --- 2. Build and sign the launcher, only when launcher.c changed ---
# A new build has a new signature, and macOS then no longer gives it the old build's Full Disk Access.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
build=0
if [ ! -x "$LAUNCHER" ] || ! cmp -s "$DIR/launcher.c" "$LIBEXEC/launcher.c"; then
  build=1
  echo "==> Building the launcher"
  cc -O2 -Wall -Wextra -Werror -o "$tmp/imessage-crm-read" "$DIR/launcher.c"
  # Hardened runtime: macOS then ignores DYLD_ variables for the launcher and loads only libraries
  # Apple signed, so no other code can run inside it.
  codesign --force --sign - --options runtime --identifier "$LABEL" "$tmp/imessage-crm-read"
fi

# --- 3. Copy into place, as root ---
echo "==> Installing into $LIBEXEC. sudo asks for your password."
sudo install -d -o root -g wheel -m 755 "$LIBEXEC"
sudo install -o root -g wheel -m 644 "$DIR/imessage-crm-sync" "$LIBEXEC/imessage-crm-sync.py"
if [ "$build" = 1 ]; then
  sudo install -o root -g wheel -m 755 "$tmp/imessage-crm-read" "$LAUNCHER"
  sudo install -o root -g wheel -m 644 "$DIR/launcher.c" "$LIBEXEC/launcher.c"
fi

# --- 4. Load both LaunchAgents ---
"$DIR/install.sh"

# --- 5. What only you can do: Full Disk Access ---
if [ "$build" = 0 ]; then
  echo "==> The launcher didn't change, so it keeps its Full Disk Access. The reader runs the new script at its next run."
  exit 0
fi
APP="$(/usr/bin/python3 -c 'import os, sys; print(os.path.join(sys.base_prefix, "Resources", "Python.app"))')"
cat <<MSG

The launcher is new, so it needs Full Disk Access. Until it has it, the reader's runs fail with
"Can't read ... Full Disk Access" in the log. In System Settings > Privacy & Security > Full Disk Access:
  1. If imessage-crm-read is in the list already, select it and press - (its old build no longer matches).
  2. Press +, then Cmd+Shift+G, paste this path and add it:
       $LAUNCHER
  3. Select each of these and press -, so Python no longer has Full Disk Access:
       python3 (/usr/bin/python3)
       Python ($APP)

Then run the reader. The transfer job sends its export as soon as it appears:
  launchctl kickstart -k gui/\$(id -u)/$LABEL; sleep 30; tail -30 ~/Library/Logs/imessage-crm-sync.log
MSG
