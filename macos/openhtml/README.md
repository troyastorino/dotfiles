# Open workspace HTML files in your Mac browser

Two commands, runnable from any tmux pane on the workspace:

- **`openhtml <file.html>`** — sends the file's bytes to your Mac over a
  reverse SSH tunnel; a small listener saves it under `~/.cache/openhtml/`
  and opens it with `open`. Best for self-contained files.
- **`servehtml [-p PORT] <file.html>`** — starts `python3 -m http.server` on
  the workspace (port 23180 by default) serving the file's *directory*, then
  auto-opens `http://localhost:<port>/<file>` on the Mac (the URL works there
  thanks to a `LocalForward`). Use this when the page references local
  CSS/JS/images. Pass `-p` with another port from 23180-23189 to serve a
  second directory alongside the first.

```
openhtml:  file bytes ─> 127.0.0.1:7777 ─(RemoteForward)─> Mac listener ─> open(1)
servehtml: http.server on workspace:23180-23189 <─(LocalForward)─ Mac browser
           (auto-open: redirect page sent through the same 7777 listener)
```

## One-time Mac setup

On the Mac, clone (or pull) this repo and run the installer:

```sh
git clone https://github.com/troyastorino/dotfiles ~/dotfiles  # or: cd ~/dotfiles && git pull
~/dotfiles/macos/openhtml/install.sh
```

The installer is idempotent. You rarely need to run it by hand: on the Mac, every new
interactive shell runs `dotfiles-mac-check` (in `zsh-functions`), which runs the installer
when something is missing or a file in this directory changed since the last install. It:

1. Symlinks the listener to `~/.local/bin/openhtml-listener` (symlink, so
   `git pull` updates it; re-running the installer restarts it)
2. Writes its block of SSH forwards to `~/.ssh/config`:
   `Host *.coder coder.*` (both Coder alias styles, e.g.
   `main.troy-workspace.troy.coder`) with `RemoteForward 7777` and a
   `LocalForward` for each port 23180-23189. The installer regenerates the
   block whenever the forwards change, so an older block gets migrated
   (appending a block is safe — ssh accumulates forwards from all matching
   blocks)
3. Installs and starts the LaunchAgent (`com.user.openhtml-listener`) so the
   listener is always running. Verify with `launchctl list | grep openhtml`.

Then **reconnect SSH** — forwards only apply to new connections.

### Test

From any tmux pane in the workspace (after reconnecting SSH):

```sh
echo '<h1>it works</h1>' > /tmp/test.html
openhtml /tmp/test.html     # browser tab opens on the Mac
servehtml /tmp/test.html    # browser tab opens on http://localhost:23180/test.html
```

## Choosing the browser

The listener uses your default browser. To force one, set `OPENHTML_APP` for
the listener — e.g. edit the plist's `ProgramArguments` to
`/bin/bash -c 'OPENHTML_APP="Google Chrome" exec ~/.local/bin/openhtml-listener'`,
or export it before running the listener manually. `"Safari"` works too.

## Notes and limitations

- **`openhtml` sends a single self-contained file** — relative references to
  CSS/JS/images on the workspace will 404. Use `servehtml` for those.
- **`servehtml` runs one server per port.** The default port is 23180
  (`SERVEHTML_PORT` changes it). `-p 23181` starts a second server for another
  directory, and so on through 23189. Re-running on a port with a file from a
  different directory restarts that port's server there, so earlier tabs on
  that port stop resolving. Server log: `/tmp/servehtml-<port>.log`. A port
  outside 23180-23189 starts fine, but the Mac can't reach it without a
  `LocalForward` of your own.
- **Why 23180-23189**: the range sits inside an unassigned IANA block
  (23054-23271), away from common dev-server defaults (3000, 5173, 8000,
  8080, 8888) and below the Linux (32768+) and IANA dynamic (49152+)
  ephemeral ranges, so a stray local process is unlikely to hold one of them.
- **`servehtml` auto-open reuses the 7777 listener** by sending a tiny
  meta-refresh redirect page. If the listener or tunnel is down it prints the
  URL instead — still openable on the Mac via the `LocalForward`.
- **Multiple SSH connections**: only the first connection wins each forward;
  later ones print `Warning: remote port forwarding failed for listen port
  7777` and an `Address already in use` line per `LocalForward`. Harmless —
  everything works as long as any one connection holds them.
- Received `openhtml` files are kept in `~/.cache/openhtml/` (most recent 50)
  so the browser tab keeps working after you re-run the command.
