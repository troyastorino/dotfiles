#!/usr/bin/env bash
# Push the writing rules to the surfaces that read no local files.
#
# Claude chat, mobile, and Claude Desktop in Chat mode never read ~/.claude.
# Their only lever is the personal-preferences box in claude.ai settings, which
# has no API and no config file. So the paste stays manual, but it does not have
# to be a memory exercise: this copies the canonical text to the clipboard and
# records its hash, so install.sh can tell you when what you pasted went stale.
#
# Usage: claude/sync-prefs.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
STAMP="$DIR/.prefs-synced"

# The output style carries YAML frontmatter. claude.ai wants the rules alone, so
# both the paste and the hash use the body.
RULES="$(mktemp)"
trap 'rm -f "$RULES"' EXIT
"$DIR/rules-body.sh" >"$RULES"

# sha256sum on Linux, shasum on the Mac. Must match the sha256 in install.sh,
# which compares this stamp against the current rules.
if command -v sha256sum >/dev/null 2>&1; then
  hash="$(sha256sum <"$RULES" | cut -d' ' -f1)"
else
  hash="$(shasum -a 256 <"$RULES" | cut -d' ' -f1)"
fi

if command -v pbcopy >/dev/null 2>&1; then
  pbcopy <"$RULES"; copied="clipboard (pbcopy)"
elif command -v wl-copy >/dev/null 2>&1; then
  wl-copy <"$RULES"; copied="clipboard (wl-copy)"
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard <"$RULES"; copied="clipboard (xclip)"
else
  copied=""
fi

if [ -n "$copied" ]; then
  echo "==> Copied the writing rules to your $copied"
else
  echo "==> No clipboard tool found. The text to paste:"
  echo
  cat "$RULES"
  echo
fi

cat <<'EOF'
Paste it into claude.ai -> Settings -> personal preferences, replacing what is
there. That covers Claude chat on web, mobile, and Desktop in Chat mode.
EOF

printf '%s\n' "$hash" >"$STAMP"
echo "==> Stamped $STAMP. Commit it so every machine agrees on what was pasted."
