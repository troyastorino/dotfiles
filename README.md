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

On Coder, `install.sh` also writes `/usr/local/bin/tmux`, a wrapper around the Homebrew
tmux. Codex looks for tmux only in system directories, and without it Codex cannot copy a
mouse selection or read Shift+Enter.

## tmux on Coder

`zshrc` starts tmux in every interactive shell, through the Oh My Zsh `tmux` plugin. The
plugin attaches to the session `main`, and creates it when it does not exist.

A workspace restart kills tmux and every Claude Code and Codex session in it. Coder runs
`install.sh` on every workspace start, including a restart of the container inside a
running pod. So on Coder, `install.sh` rebuilds the saved panes with
`~/picnic/bin/tmux-agent-panes restore --continue-busy`, even when nobody connects. A session
that was busy at the last snapshot resumes with a message that tells it to check the current
state and continue. The other sessions resume and wait for you.

The startup restore runs only when all of these hold:

- `$CODER` is set.
- No tmux server is running.
- `~/picnic/bin/tmux-agent-panes` and `~/.claude/tmux-snapshots/state.json` exist.

It runs in a login bash started from `$HOME`. That gives the tmux server the environment an
SSH login gets: `/etc/profile.d` sources `~/.picnicrc`, which loads the secrets and unsets
`CODEX_API_KEY`. The panes inherit the server's environment. Coder blocks logins until
`install.sh` finishes, so the first connection waits for the restore.

The first interactive shell restores the panes instead when the startup restore did not
run, or when the tmux server died later. That restore sends no continue message. It runs only
when all of these hold:

- `$CODER` is set.
- No tmux server is running. A second terminal attaches to the running server as before.
- `~/picnic/bin/tmux-agent-panes` and `~/.claude/tmux-snapshots/state.json` exist.
- The shell is interactive, outside tmux, and outside Emacs.

The plugin then attaches to the restored panes. If the snapshot has no `main` session, the
shell attaches to the first restored session instead. In every other case the shell starts
tmux as before. The picnic repo documents the snapshot tool in `docs/eng-tools/tmux.md`.
