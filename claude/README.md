# Claude Code config

Installed by the repo's `install.sh`. Two mechanisms, because the two files work
differently.

| What | Where it goes | How |
|---|---|---|
| `rules/*.md` | `~/.claude/rules/` | Symlink, so `git pull` updates them |
| `settings.json` | `~/.claude/settings.json` | Merge, because Claude Code writes there too |

- `rules/writing.md`: how Claude writes when it writes as itself. STE structure plus
  Orwell's six rules. Does not cover ghostwriting.
- `settings.json`: user-scope settings. The `permissions.allow` list here is a starter set
  of read-only git commands. Edit or empty it. Run `/fewer-permission-prompts` in a session
  to generate a real allowlist from your own transcripts.

## Why settings.json is merged and not symlinked

Claude Code writes to `~/.claude/settings.json` at runtime: `model` from `/model`,
`effortLevel` from `/effort`, `advisorModel` from `/advisor`, plus
`askUserQuestionTimeout`, `autoCompactWindow`, and `/config` toggles. You and the app share
that layer.

A symlink would put every mid-session `/model` switch into this repo as an uncommitted
change, and two machines with different local choices would overwrite each other.
`merge-settings.py` merges instead: dicts recurse, lists union, and the keys declared here
win. Everything the app wrote survives.

Removals work in both directions, which a plain merge cannot do. The script records the
previous dotfiles settings in `~/.claude/.dotfiles-managed.json`. Delete a key here and the
next run removes it from `~/.claude/settings.json`. Delete one entry from
`permissions.allow` and the next run removes only that entry. Anything the app or another
tool added is never touched.

Arrays merge across settings scopes, so entries here compose with a project's
`.claude/settings.json` rather than replacing it.

## Verify

```sh
~/.dotfiles/install.sh      # ~/dotfiles/install.sh on the Mac
ls -l ~/.claude/rules/
python3 -c 'import json;print(json.load(open("$HOME/.claude/settings.json")))'
```

Then start a session and run `/context`. `writing.md` appears under **Memory files**.

## What reads what

| Surface | Reads `~/.claude` | Gets the rules |
|---|---|---|
| Claude Code, Mac and Coder | Yes | Yes, via this repo |
| Claude Code on the web (claude.ai/code) | Its own container | No. Add a dotfiles clone to the environment setup script |
| Cowork | Reads `~/.claude/skills/`. Rules and memory unconfirmed | Test it: ask what writing rules it is following |
| Claude chat, web and Desktop in Chat mode | No | Paste only, see below |
| Claude mobile | No filesystem | Paste only, see below |

## Keeping claude.ai personal preferences in sync

Chat and mobile read no local files. Their only lever is the personal-preferences box in
claude.ai settings, which has no API and no config file, so the paste is manual. What is
not manual is knowing when it went stale:

```sh
claude/sync-prefs.sh
```

That copies `rules/writing.md` to the clipboard and writes its hash to
`claude/.prefs-synced`. Paste, then commit the stamp. From then on `install.sh` compares the
hash on every run and tells you when the rules changed but the paste did not. Committing the
stamp means every machine agrees on what the web account is running.

## If the rules symlink is not picked up

Fall back to a user-memory import. Create `~/.claude/CLAUDE.md` with one line:

```text
@~/.dotfiles/claude/rules/writing.md
```

Imports in user-scope memory files load without an approval dialog.
