# Claude Code config

The repo's `install.sh` installs this directory. It uses two mechanisms, because the two
files work differently.

| What | Where it goes | How |
|---|---|---|
| `rules/*.md` | `~/.claude/rules/` | Symlink, so `git pull` updates them |
| `settings.json` | `~/.claude/settings.json` | Merge, because Claude Code writes there too |

- `rules/writing.md` tells Claude how to write when it writes as itself. It pairs the
  structure rules of ASD-STE100 (Simplified Technical English) with Orwell's six rules.
  It does not cover ghostwriting.
- `settings.json` holds user-scope settings. Its `permissions.allow` list is a starter
  set of read-only git commands. Edit the list, or empty it. To build a real allowlist
  from your own transcripts, run `/fewer-permission-prompts` in a session.

## Why install.sh merges settings.json

Claude Code writes to `~/.claude/settings.json` at runtime. It writes:

- `model`, from `/model`
- `effortLevel`, from `/effort`
- `advisorModel`, from `/advisor`
- `askUserQuestionTimeout`, `autoCompactWindow`, and the `/config` toggles

You and the app share that file. A symlink would turn every mid-session `/model` switch
into an uncommitted change in this repo. Two machines with different local choices would
overwrite each other. So `merge-settings.py` merges instead:

- Dicts recurse.
- Lists union: the merge keeps order and drops duplicates.
- The keys declared here win.
- Every key the app wrote survives.

The script also removes settings, which a plain merge cannot do. It records the previous
dotfiles settings in `~/.claude/.dotfiles-managed.json`. If you delete a key here, the
next run removes that key from `~/.claude/settings.json`. If you delete one entry from
`permissions.allow`, the next run removes only that entry. The script never touches a key
that the app or another tool added.

Claude Code unions lists across settings scopes. Entries here therefore compose with a
project's `.claude/settings.json` instead of replacing it.

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
| Cowork | Reads `~/.claude/skills/`. Rules and memory unconfirmed | Test it: ask what writing rules it follows |
| Claude chat, web and Desktop in Chat mode | No | Paste only, see below |
| Claude mobile | No filesystem | Paste only, see below |

## Keep claude.ai personal preferences in sync

Claude chat and Claude mobile read no local files. They read only the personal-preferences
box in claude.ai settings. That box has no API and no config file, so you must paste by
hand. The paste stays manual, but the staleness check does not:

```sh
claude/sync-prefs.sh
```

The script copies `rules/writing.md` to the clipboard. It also writes the file's hash to
the stamp file, `claude/.prefs-synced`. Paste the rules, then commit the stamp. On every
run after that, `install.sh` compares the stamp against the current rules. When the rules
changed but the paste did not, it warns you. Commit the stamp so every machine agrees on
what the web account runs.

## If Claude Code does not pick up the rules symlink

Fall back to a user-memory import. Create `~/.claude/CLAUDE.md` with one line:

```text
@~/.dotfiles/claude/rules/writing.md
```

Imports in user-scope memory files load without an approval dialog.
