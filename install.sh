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
