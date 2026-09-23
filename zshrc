# Fall back to xterm-256color if terminal is unknown (e.g., xterm-ghostty on remote)
if ! infocmp "$TERM" &>/dev/null 2>&1; then
  export TERM=xterm-256color
fi

# Where this repo lives. ~/.zshrc is a symlink into it, so resolve that rather
# than assume a path (it is ~/dotfiles on the Mac and ~/.dotfiles on Coder).
DOTFILES_DIR="${${(%):-%N}:A:h}"
[ -f "$DOTFILES_DIR/zsh-functions" ] || DOTFILES_DIR="$HOME/.dotfiles"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git tmux)

ZSH_TMUX_AUTOSTART=true
ZSH_TMUX_AUTOCONNECT=true
ZSH_TMUX_AUTOQUIT=false          # Don't close terminal when detaching
ZSH_TMUX_DEFAULT_SESSION_NAME=main

# On Coder, the first shell after a workspace restart finds no tmux server, and
# the tmux plugin would open one empty session. Rebuild the saved Claude Code
# and Codex panes first, so the plugin attaches to them instead. The pipe to
# cat stops restore from attaching by itself: it would exec tmux, and detaching
# would then close the terminal, which ZSH_TMUX_AUTOQUIT=false exists to avoid.
if [[ -n "$CODER" && -z "$TMUX" && -z "$INSIDE_EMACS" && -o interactive \
      && -x "$HOME/picnic/bin/tmux-agent-panes" \
      && -f "$HOME/.claude/tmux-snapshots/state.json" ]] \
    && ! command tmux has-session 2>/dev/null; then
  "$HOME/picnic/bin/tmux-agent-panes" restore | cat
  # The plugin attaches to the session named "main". When the snapshot has no
  # such session, point it at a restored one rather than a new empty "main".
  if ! command tmux has-session -t '=main' 2>/dev/null; then
    ZSH_TMUX_DEFAULT_SESSION_NAME="$(command tmux list-sessions -F '#S' 2>/dev/null | head -n 1)"
    : "${ZSH_TMUX_DEFAULT_SESSION_NAME:=main}"
  fi
fi

source $ZSH/oh-my-zsh.sh

# Preferred editor
export EDITOR='emacsclient -t'

# Source aliases if present
[ -f ~/.aliases ] && source ~/.aliases

# Source zsh functions from the dotfiles repo
[ -f "$DOTFILES_DIR/zsh-functions" ] && source "$DOTFILES_DIR/zsh-functions"

# Conditionally load pyenv if installed
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init -)"
fi

# Conditionally load nvm if installed
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

export PATH="$HOME/.local/bin:$DOTFILES_DIR/bin:$PATH"

# On the Mac, keep the Coder bridges (macos/*) installed and current. Runs an
# installer only when something is missing or stale, so it is silent otherwise.
if [[ "$OSTYPE" == darwin* && -o interactive ]] && (( $+functions[dotfiles-mac-check] )); then
  dotfiles-mac-check
fi

# On the Mac, link ~/picnic/skills into ~/.claude/skills, and relink when
# picnic adds or drops a skill. Silent when the links are current.
if [[ "$OSTYPE" == darwin* && -o interactive ]] && (( $+functions[dotfiles-picnic-skills-check] )); then
  dotfiles-picnic-skills-check
fi
