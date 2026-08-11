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

# --- Symlink Claude Code user-level rules ---
# ~/.claude/rules/*.md load in every project on this machine. Symlinked, not
# copied, so `git pull` updates them.
if [ -d "$DOTFILES_DIR/claude/rules" ]; then
  echo "==> Linking Claude Code rules..."
  mkdir -p "$HOME/.claude/rules"
  for rule in "$DOTFILES_DIR"/claude/rules/*.md; do
    [ -f "$rule" ] || continue
    target="$HOME/.claude/rules/$(basename "$rule")"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      echo "    Backing up $target -> ${target}.backup"
      mv "$target" "${target}.backup"
    fi
    ln -sf "$rule" "$target"
    echo "    Linked $target -> $rule"
  done
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
if [ -f "$DOTFILES_DIR/claude/rules/writing.md" ] && command -v python3 &>/dev/null; then
  rules_hash="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' \
    "$DOTFILES_DIR/claude/rules/writing.md")"
  synced_hash=""
  [ -f "$DOTFILES_DIR/claude/.prefs-synced" ] && synced_hash="$(cat "$DOTFILES_DIR/claude/.prefs-synced")"
  if [ "$rules_hash" != "$synced_hash" ]; then
    echo "==> Heads up: rules/writing.md differs from what was last pasted into"
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

echo "==> Dotfiles setup complete!"
