# Paste Mac clipboard images into Claude Code on the workspace

Press **Ctrl+V** in a Claude Code session on the workspace. The image on your Mac clipboard
lands in the prompt.

Cmd+V cannot do this. The terminal handles Cmd+V itself, and it can only send text down the
SSH connection. Ctrl+V reaches Claude Code as a keystroke. Claude Code then reads the
clipboard on its own, with a command that depends on the platform.

## How it works

On Linux, Claude Code reads a pasted image with two `xclip` calls:

```sh
xclip -selection clipboard -t TARGETS -o     # is there an image?
xclip -selection clipboard -t image/png -o   # dump it as PNG
```

A Coder workspace has no X display and no `xclip`, so both calls fail and nothing happens.
`bin/xclip` in this repo stands in for the real `xclip`. It is on PATH through `.zshrc`,
and it answers both calls from the Mac clipboard:

```
Ctrl+V in Claude Code ─> bin/xclip ─> 127.0.0.1:7778 ─(RemoteForward)─> clipboard-listener on the Mac
                                                                          └─> osascript reads the clipboard as PNG
```

`clipboard-listener` is a small Python script. launchd keeps it running on the Mac. For each
connection it reads one line, `png`, and replies with the PNG bytes. An empty reply means
the clipboard holds no image. The AppleScript it runs is the one Claude Code itself runs on
a Mac.

If a display is set (`DISPLAY` or `WAYLAND_DISPLAY`), `bin/xclip` hands off to the next
`xclip` on PATH instead.

## One-time Mac setup

The listener runs on `/usr/bin/python3`, which needs the Xcode Command Line Tools
(`xcode-select --install`). On the Mac, clone or pull this repo and run the installer:

```sh
git clone https://github.com/troyastorino/dotfiles ~/dotfiles  # or: cd ~/dotfiles && git pull
~/dotfiles/macos/clipboard/install.sh
```

The installer is idempotent. Re-run it after pulling updates. It:

1. Symlinks the listener to `~/.local/bin/clipboard-listener`, so `git pull` updates it.
   Re-running the installer restarts it.
2. Appends `RemoteForward 7778` to `~/.ssh/config` under `Host *.coder coder.*` if it is
   missing. This is the same host pattern the openhtml installer uses, and ssh accumulates
   forwards from every matching block.
3. Installs and starts the LaunchAgent `com.user.clipboard-listener`. Verify with
   `launchctl list | grep clipboard`.

Then **reconnect SSH**. Forwards only apply to new connections.

The workspace side needs no install step. `bin/` is already on PATH.

## Test

On the Mac, copy a screenshot to the clipboard (Cmd+Ctrl+Shift+4 copies a region), then:

```sh
printf 'png\n' | nc 127.0.0.1 7778 > /tmp/clip.png && open /tmp/clip.png
```

On the workspace, in any tmux pane, with that image still on the Mac clipboard:

```sh
xclip -selection clipboard -t TARGETS -o     # prints: image/png
```

Then press Ctrl+V in a Claude Code session.

## Troubleshooting

- **Nothing happens on Ctrl+V.** Claude Code discards `xclip`'s stderr. Run the `TARGETS`
  command above by hand in a pane. It prints a hint when it cannot reach the listener.
- **Listener log**: `~/.cache/clipboard/listener.log` on the Mac. The line
  `no image on the clipboard (... -1700)` is the normal case when the clipboard holds text.
- **Clipboard privacy prompts.** Recent macOS versions can ask before a program reads the
  clipboard. How that applies to an `osascript` that launchd started is unverified. If the
  log shows an `osascript` error other than -1700, or paste stays empty with an image on
  the clipboard, look in System Settings > Privacy & Security for a paste or clipboard
  permission and allow it.
- **Ctrl+V must arrive as a plain keystroke.** tmux binds nothing to `C-v` in this config.
  If your terminal binds Ctrl+V to paste, unbind it there.
- **Multiple SSH connections**: only the first connection wins the forward. Later ones print
  `Warning: remote port forwarding failed for listen port 7778`. Harmless, as long as one
  connection holds it.

## Limitations

- **Read-only.** The bridge reads the Mac clipboard. `xclip -i` (copy) exits 1.
- **PNG only.** Only the `TARGETS` and `image/png` targets are answered. `text/plain` and
  `image/bmp` exit 1, which Claude Code treats as "no image".
- **Two fetches per paste.** The `TARGETS` check fetches the full image to answer, and the
  `image/png` call fetches it again.
- **Port 7778**, next to openhtml's 7777. Override with `CLIPBOARD_PORT` on both sides.
