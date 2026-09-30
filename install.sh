#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Setting up dotfiles from $DOTFILES_DIR"

# --- Install Oh My Zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "==> Oh My Zsh already installed"
fi

# --- Install Spacemacs ---
if [ ! -d "$HOME/.emacs.d" ] || [ ! -f "$HOME/.emacs.d/spacemacs.mk" ]; then
  echo "==> Installing Spacemacs..."
  if [ -d "$HOME/.emacs.d" ]; then
    mv "$HOME/.emacs.d" "$HOME/.emacs.d.backup.$(date +%s)"
  fi
  git clone https://github.com/syl20bnr/spacemacs "$HOME/.emacs.d"
else
  echo "==> Spacemacs already installed"
fi

# --- Symlink dotfiles ---
FILES="zshrc bashrc tmux.conf spacemacs aliases gitconfig"

for file in $FILES; do
  target="$HOME/.$file"
  source="$DOTFILES_DIR/$file"

  if [ ! -f "$source" ]; then
    echo "    Skipping $file (not found in dotfiles)"
    continue
  fi

  # Back up existing file (if it's a real file, not already a symlink)
  if [ -f "$target" ] && [ ! -L "$target" ]; then
    echo "    Backing up $target -> ${target}.backup"
    mv "$target" "${target}.backup"
  fi

  # Remove existing symlink if it points somewhere else
  if [ -L "$target" ]; then
    rm "$target"
  fi

  ln -s "$source" "$target"
  echo "    Linked $target -> $source"
done

# --- Symlink Claude Code output styles ---
# ~/.claude/output-styles/*.md reach the system prompt. A rules file reaches a
# user message instead, which loses to the larger repo instructions alongside
# it. claude/README.md explains the difference. Symlinked, not copied, so
# `git pull` updates them.
if [ -d "$DOTFILES_DIR/claude/output-styles" ]; then
  echo "==> Linking Claude Code output styles..."
  mkdir -p "$HOME/.claude/output-styles"
  for style in "$DOTFILES_DIR"/claude/output-styles/*.md; do
    [ -f "$style" ] || continue
    target="$HOME/.claude/output-styles/$(basename "$style")"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      echo "    Backing up $target -> ${target}.backup"
      mv "$target" "${target}.backup"
    fi
    ln -sf "$style" "$target"
    echo "    Linked $target -> $style"
  done
fi

# --- Link picnic skills (Mac only) ---
# Coder workspaces link ~/picnic/skills through picnic's own setup. The Mac has
# no such step, so link each skill into ~/.claude/skills here. zshrc re-runs
# this when picnic adds or drops a skill.
if [ "$(uname)" = "Darwin" ] && [ -d "$HOME/picnic/skills" ]; then
  echo "==> Linking picnic skills..."
  "$DOTFILES_DIR/claude/link-picnic-skills.sh"
fi

# --- Drop the rules symlink earlier versions installed ---
# The writing rules moved to claude/output-styles/. A machine that ran the old
# install.sh still holds a symlink to the file that moved, and it now resolves
# to nothing.
if [ -L "$HOME/.claude/rules/writing.md" ] && [ ! -e "$HOME/.claude/rules/writing.md" ]; then
  rm "$HOME/.claude/rules/writing.md"
  echo "==> Removed the stale ~/.claude/rules/writing.md symlink"
fi

# --- Merge Claude Code user settings ---
# Not a symlink: Claude Code writes /model, /effort, /advisor and /config
# choices into ~/.claude/settings.json too. Merging keeps those and still
# applies the keys declared in claude/settings.json.
if [ -f "$DOTFILES_DIR/claude/settings.json" ]; then
  echo "==> Merging Claude Code settings..."
  if command -v python3 &>/dev/null; then
    python3 "$DOTFILES_DIR/claude/merge-settings.py" \
      "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
  else
    echo "    Skipping (needs python3)"
  fi
fi

# --- Warn when claude.ai personal preferences are stale ---
# Chat, mobile, and Desktop-in-Chat read no local files, so the writing rules
# reach them only by paste. Compare hashes and say so when they drift.
# sha256sum on Linux, shasum on the Mac.
sha256() {
  if command -v sha256sum &>/dev/null; then sha256sum; else shasum -a 256; fi | cut -d' ' -f1
}
if [ -x "$DOTFILES_DIR/claude/rules-body.sh" ]; then
  rules_hash="$("$DOTFILES_DIR/claude/rules-body.sh" | sha256)"
  synced_hash=""
  [ -f "$DOTFILES_DIR/claude/.prefs-synced" ] && synced_hash="$(cat "$DOTFILES_DIR/claude/.prefs-synced")"
  if [ "$rules_hash" != "$synced_hash" ]; then
    echo "==> Heads up: the writing rules differ from what was last pasted into"
    echo "    claude.ai personal preferences. Run: $DOTFILES_DIR/claude/sync-prefs.sh"
  fi
fi

# --- Start emacs daemon ---
if command -v emacs &>/dev/null; then
  if ! emacsclient -e '(+ 1 1)' &>/dev/null 2>&1; then
    echo "==> Starting emacs daemon..."
    emacs --daemon &>/dev/null &
  else
    echo "==> Emacs daemon already running"
  fi
fi

# --- Set login shell to zsh ---
if command -v zsh &>/dev/null; then
  CURRENT_SHELL="$(basename "$SHELL")"
  if [ "$CURRENT_SHELL" != "zsh" ]; then
    ZSH_PATH="$(command -v zsh)"
    if ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "==> Adding $ZSH_PATH to /etc/shells..."
      if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
      else
        echo "    (no passwordless sudo — skipping /etc/shells update and chsh)"
      fi
    fi
    if grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "==> Setting login shell to zsh..."
      chsh -s "$ZSH_PATH" 2>/dev/null || echo "    (chsh failed — you may need to set shell manually)"
    fi
  else
    echo "==> Shell already set to zsh"
  fi
fi

# --- Put tmux where Codex can find it (Coder only) ---
# Codex looks for tmux only in system directories such as /usr/local/bin, never
# on PATH. Homebrew keeps tmux under /home/linuxbrew, so Codex finds none. It
# then cannot copy a mouse selection through tmux, and it does not turn on the
# key mode that makes Shift+Enter insert a newline. A symlink does not help:
# Codex resolves it and rejects a target outside those directories. So write a
# wrapper script. The root filesystem resets on every workspace restart, so
# write it on each start, before the restore below starts Codex.
brew_tmux=/home/linuxbrew/.linuxbrew/bin/tmux
if [ -n "${CODER:-}" ] && [ -x "$brew_tmux" ] && [ ! -e /usr/local/bin/tmux ]; then
  if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
    echo "==> Adding a /usr/local/bin/tmux wrapper for Codex..."
    printf '#!/bin/sh\nexec %s "$@"\n' "$brew_tmux" | sudo tee /usr/local/bin/tmux >/dev/null
    sudo chmod 755 /usr/local/bin/tmux
  else
    echo "    (no passwordless sudo — skipping the tmux wrapper for Codex)"
  fi
fi

# --- Restore saved Claude Code and Codex panes (Coder only) ---
# Coder runs this script on every workspace start, including a restart of the
# container inside a running pod. That kills tmux and every agent in it, and
# nothing else brings the panes back while nobody is connected. So rebuild them
# here, and prompt each session that was busy at the last snapshot to continue.
#
# Coder blocks logins until this script ends. The first shell therefore finds
# the tmux server already up and skips its own restore in zshrc. Two restores at
# once would resume every session twice.
#
# `bash -lc` from $HOME gives the tmux server the environment an SSH login gets.
# /etc/profile.d sources ~/.picnicrc, which loads the secrets through picnic-env
# and unsets CODEX_API_KEY. picnic-env finds the repo from the current
# directory, so the `cd` matters. The panes inherit the server's environment.
panes_tool="$HOME/picnic/bin/tmux-agent-panes"
if [ -n "${CODER:-}" ] && [ -x "$panes_tool" ] \
    && [ -f "$HOME/.claude/tmux-snapshots/state.json" ] \
    && command -v tmux &>/dev/null && ! tmux has-session 2>/dev/null; then
  echo "==> Restoring saved agent panes..."
  (cd "$HOME" && bash -lc '"$1" restore --continue-busy' _ "$panes_tool") \
    || echo "    (restore reported a problem — see the lines above)"
fi

echo "==> Dotfiles setup complete!"
