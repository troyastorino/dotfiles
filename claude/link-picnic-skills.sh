#!/usr/bin/env bash
# Link the picnic repo's skills into ~/.claude/skills so Claude Code on the Mac
# sees the same set as a Coder workspace. Mac only: Coder workspaces link them
# through picnic's own setup (link_repo_skills in
# picnic/infra/cloud/workspace/lib/agent-setup.sh).
#
# The set comes from picnic's own filter, skills/scripts/list-coder-skills.py
# (`plugin: engineering`, or `metadata.install-in-coder: true`), so it tracks
# any change picnic makes to that rule. The filter needs PyYAML, which the Mac
# python lacks, so it runs from a private venv in ~/.cache/picnic-skills.
#
# Each selected skill gets one directory symlink, ~/.claude/skills/<name> ->
# ~/picnic/skills/<name>. A file added to a skill later is visible at once. A
# skill added, removed, or newly selected needs a re-run, which
# dotfiles-picnic-skills-check in zsh-functions does at shell start when
# ~/picnic/skills or a SKILL.md is newer than the stamp this script leaves.
#
# It links from the primary checkout, as picnic's bin/sync-claude-skills does,
# so the skills follow whatever branch ~/picnic has checked out.
#
# Idempotent. Leaves alone any entry it did not create: a real directory or
# file, or a symlink that points somewhere else, wins over the picnic skill.
#
# Usage: link-picnic-skills.sh [-q]    -q prints only changes and warnings
set -euo pipefail

quiet=0
[ "${1:-}" = "-q" ] && quiet=1

if [ "$(uname)" != "Darwin" ]; then
  echo "link-picnic-skills: Mac only; Coder links picnic skills itself." >&2
  exit 0
fi

SRC="${PICNIC_SKILLS_DIR:-$HOME/picnic/skills}"
DEST="$HOME/.claude/skills"
CACHE="$HOME/.cache/picnic-skills"
VENV="$CACHE/venv"
FILTER="$SRC/scripts/list-coder-skills.py"

if [ ! -d "$SRC" ]; then
  [ "$quiet" = 1 ] || echo "link-picnic-skills: $SRC not found, so there is nothing to link."
  exit 0
fi
if [ ! -f "$FILTER" ]; then
  echo "link-picnic-skills: $FILTER not found, so the Coder skill set is unknown. Links left as they are." >&2
  exit 1
fi

# (Re)build the venv when it is missing or broken, as after a pyenv upgrade
# removes the python it was made from.
if ! "$VENV/bin/python" -c 'import yaml' 2>/dev/null; then
  echo "    Building $VENV for PyYAML"
  rm -rf "$VENV"
  mkdir -p "$CACHE"
  if ! { python3 -m venv "$VENV" && "$VENV/bin/pip" install -q pyyaml; }; then
    echo "link-picnic-skills: could not build $VENV. Links left as they are." >&2
    exit 1
  fi
fi

# The filter skips malformed skills silently and prints nothing on failure, so
# an empty list means something broke. Keep the current links then, rather
# than remove them all.
if ! selected="$("$VENV/bin/python" "$FILTER" --skills-dir "$SRC")" || [ -z "$selected" ]; then
  echo "link-picnic-skills: $FILTER selected no skills. Links left as they are." >&2
  exit 1
fi
mkdir -p "$DEST"

# Drop links this script made whose skill is gone (deleted, renamed, not on
# the current branch) or no longer in the Coder set.
removed=0
for link in "$DEST"/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$SRC"/*) ;;
    *) continue ;;
  esac
  if [ ! -f "$link/SKILL.md" ] || ! grep -qxF -- "${link##*/}" <<<"$selected"; then
    rm "$link"
    echo "    Removed $link (no longer in the Coder skill set)"
    removed=$((removed + 1))
  fi
done

added=0 present=0 skipped=0
while IFS= read -r name; do
  src_dir="$SRC/$name"
  target="$DEST/$name"
  [ -f "$src_dir/SKILL.md" ] || continue
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src_dir" ]; then
    present=$((present + 1))
  elif [ -e "$target" ] || [ -L "$target" ]; then
    echo "    Skipped $name: $target already exists and is not a link to $src_dir"
    skipped=$((skipped + 1))
  else
    ln -s "$src_dir" "$target"
    added=$((added + 1))
  fi
done <<<"$selected"

if [ "$quiet" = 0 ] || [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  echo "    Picnic skills in $DEST: $added added, $removed removed, $present already linked, $skipped skipped"
fi

# Stamp for dotfiles-picnic-skills-check in zsh-functions.
touch "$CACHE/linked"
