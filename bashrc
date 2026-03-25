# Switch to zsh for interactive sessions
if [[ $- == *i* ]] && command -v zsh &>/dev/null && [ -z "$ZSH_STARTED" ]; then
  export ZSH_STARTED=1
  exec zsh -l
fi
