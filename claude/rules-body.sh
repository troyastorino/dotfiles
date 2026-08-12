#!/usr/bin/env bash
# Print the writing rules without their YAML frontmatter.
#
# install.sh hashes this text. sync-prefs.sh pastes and hashes it. The two must
# agree on what "the rules" are, and the frontmatter is not part of them: it
# configures the output style, and claude.ai personal preferences has no use for
# it. That agreement lives here so neither caller reimplements it.
#
# Usage: claude/rules-body.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
STYLE="$DIR/output-styles/writing-rules.md"

[ -f "$STYLE" ] || { echo "rules-body: missing $STYLE" >&2; exit 1; }

awk '
  NR == 1 && /^---$/ { fm = 1; next }   # opening fence
  fm && /^---$/      { fm = 0; next }   # closing fence
  fm                 { next }           # frontmatter body
  !body && NF == 0   { next }           # blank lines before the first real line
                     { body = 1; print }
' "$STYLE"
