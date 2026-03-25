# Fall back to xterm-256color if terminal is unknown (e.g., xterm-ghostty on remote)
if ! infocmp "$TERM" &>/dev/null 2>&1; then
  export TERM=xterm-256color
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git tmux)

ZSH_TMUX_AUTOSTART=true
ZSH_TMUX_AUTOCONNECT=true
ZSH_TMUX_AUTOQUIT=false          # Don't close terminal when detaching
ZSH_TMUX_DEFAULT_SESSION_NAME=main

source $ZSH/oh-my-zsh.sh

# Preferred editor
export EDITOR='emacsclient -t'

# Source aliases if present
[ -f ~/.aliases ] && source ~/.aliases

# Conditionally load pyenv if installed
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init -)"
fi

# Conditionally load nvm if installed
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

export PATH="$HOME/.local/bin:$PATH"
