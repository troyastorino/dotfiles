# dotfiles

Shell, tmux, Emacs, git, and Claude Code config for the Mac and for Coder workspaces. The
repo lives at `~/dotfiles` on the Mac. On Coder it lives at `~/.config/coderv2/dotfiles`, and
`~/.dotfiles` links to it.

## Install

```sh
./install.sh
```

`install.sh` installs Oh My Zsh and Spacemacs when they are missing. It symlinks `zshrc`,
`bashrc`, `tmux.conf`, `spacemacs`, `aliases`, and `gitconfig` to the matching `~/.<name>`,
and backs up a real file it would replace. It also installs the Claude Code config;
[claude/README.md](claude/README.md) describes that part.

## tmux on Coder

`zshrc` starts tmux in every interactive shell, through the Oh My Zsh `tmux` plugin. The
plugin attaches to the session `main`, and creates it when it does not exist.

After a workspace restart, the first shell finds no tmux server. On Coder, that shell first
runs `~/picnic/bin/tmux-agent-panes restore`. The restore rebuilds the saved Claude Code and
Codex panes, and the plugin then attaches to them. If the snapshot has no `main` session,
the shell attaches to the first restored session instead.

The restore runs only when all of these hold:

- `$CODER` is set.
- No tmux server is running. A second terminal attaches to the running server as before.
- `~/picnic/bin/tmux-agent-panes` and `~/.claude/tmux-snapshots/state.json` exist.
- The shell is interactive, outside tmux, and outside Emacs.

In every other case the shell starts tmux as before. The picnic repo documents the snapshot
tool in `docs/eng-tools/tmux.md`.
