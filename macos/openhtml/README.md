# Open workspace HTML files in your Mac browser

Two commands, runnable from any tmux pane on the workspace:

- **`openhtml <file.html>`** — sends the file's bytes to your Mac over a
  reverse SSH tunnel; a small listener saves it under `~/.cache/openhtml/`
  and opens it with `open`. Best for self-contained files.
- **`servehtml <file.html>`** — starts `python3 -m http.server 8080` serving
  the file's *directory* on the workspace, then auto-opens
  `http://localhost:8080/<file>` on the Mac (the URL works there thanks to a
  `LocalForward`). Use this when the page references local CSS/JS/images.

```
openhtml:  file bytes ─> 127.0.0.1:7777 ─(RemoteForward)─> Mac listener ─> open(1)
servehtml: http.server on workspace:8080 <─(LocalForward)─ Mac browser
           (auto-open: redirect page sent through the same 7777 listener)
```

## One-time Mac setup

On the Mac, clone (or pull) this repo and run the installer:

```sh
git clone https://github.com/troyastorino/dotfiles ~/dotfiles  # or: cd ~/dotfiles && git pull
~/dotfiles/macos/openhtml/install.sh
```

The installer is idempotent — re-run it after pulling updates. It:

1. Symlinks the listener to `~/.local/bin/openhtml-listener` (symlink, so
   `git pull` updates it; re-running the installer restarts it)
2. Appends the SSH forwards to `~/.ssh/config` if missing:
   `Host *.coder coder.*` (both Coder alias styles, e.g.
   `main.troy-workspace.troy.coder`) with `RemoteForward 7777` +
   `LocalForward 8080` (appending is safe — ssh accumulates forwards from
   all matching blocks)
3. Installs and starts the LaunchAgent (`com.user.openhtml-listener`) so the
   listener is always running. Verify with `launchctl list | grep openhtml`.

Then **reconnect SSH** — forwards only apply to new connections.

### Test

From any tmux pane in the workspace (after reconnecting SSH):

```sh
echo '<h1>it works</h1>' > /tmp/test.html
openhtml /tmp/test.html     # browser tab opens on the Mac
servehtml /tmp/test.html    # browser tab opens on http://localhost:8080/test.html
```

## Choosing the browser

The listener uses your default browser. To force one, set `OPENHTML_APP` for
the listener — e.g. edit the plist's `ProgramArguments` to
`/bin/bash -c 'OPENHTML_APP="Google Chrome" exec ~/.local/bin/openhtml-listener'`,
or export it before running the listener manually. `"Safari"` works too.

## Notes and limitations

- **`openhtml` sends a single self-contained file** — relative references to
  CSS/JS/images on the workspace will 404. Use `servehtml` for those.
- **`servehtml` runs one server at a time** (port 8080, configurable via
  `SERVEHTML_PORT`). Re-running it on a file in a different directory restarts
  the server there; earlier tabs pointing at the old directory stop resolving.
  Server log: `/tmp/servehtml-8080.log`.
- **`servehtml` auto-open reuses the 7777 listener** by sending a tiny
  meta-refresh redirect page. If the listener or tunnel is down it prints the
  URL instead — still openable on the Mac via the `LocalForward`.
- **Multiple SSH connections**: only the first connection wins each forward;
  later ones print `Warning: remote port forwarding failed for listen port
  7777`. Harmless — everything works as long as any one connection holds it.
- Received `openhtml` files are kept in `~/.cache/openhtml/` (most recent 50)
  so the browser tab keeps working after you re-run the command.
