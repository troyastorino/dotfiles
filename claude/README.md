# Claude Code config

The repo's `install.sh` installs this directory. It uses two mechanisms, because the two
files work differently.

| What | Where it goes | How |
|---|---|---|
| `output-styles/*.md` | `~/.claude/output-styles/` | Symlink, so `git pull` updates them |
| `settings.json` | `~/.claude/settings.json` | Merge, because Claude Code writes there too |

- `output-styles/writing-rules.md` tells Claude how to write when it writes as itself. It
  pairs the structure rules of ASD-STE100 (Simplified Technical English) with Orwell's six
  rules. It does not cover ghostwriting.
- `settings.json` holds user-scope settings. It sets `outputStyle` to the style above. Its
  `permissions.allow` list is a starter set of read-only git commands. Edit the list, or
  empty it. To build a real allowlist from your own transcripts, run
  `/fewer-permission-prompts` in a session.
- `rules-body.sh` prints the style file without its YAML frontmatter. `install.sh` and
  `sync-prefs.sh` both call it, so both agree on what "the rules" are.

## Why an output style, and not `~/.claude/rules/`

This directory shipped the rules as `rules/writing.md` first. That file loaded. Claude
still wrote past it. The Claude Code docs explain why:

> CLAUDE.md content is delivered as a user message after the system prompt, not as part of
> the system prompt itself. Claude reads it and tries to follow it, but there's no
> guarantee of strict compliance, especially for vague or conflicting instructions.

Rules files take that same path. They arrive as a user message, beside every other
instruction file. In a picnic checkout the rules arrived beside these:

| File | Bytes |
|---|---|
| `picnic/AGENTS.md` | 38,712 |
| `picnic/docs/conventions/prose-conventions.md` | 24,818 |
| `~/.claude/CLAUDE.md` | 4,038 |
| the writing rules | 1,927 |

The rules held 2.8 percent of that text. `prose-conventions.md` covers the same topic at 13
times the length, and it sets no word cap and no sentence cap. The docs name that result:

> If two files give different guidance for the same behavior, Claude may pick one
> arbitrarily.

An output style avoids the fight. The docs are specific about what it does:

- It writes into the system prompt. A rules file cannot.
- It triggers reminders to follow the style during the conversation.
- `keep-coding-instructions: true` keeps Claude Code's software engineering behavior. Leave
  it set. Dropping it turns Claude into a writing assistant that no longer codes.

Two limits are worth knowing. Claude Code reads `outputStyle` once at session start, so a
change lands after `/clear` or a new session. And an output style is still context, not
enforcement. It is stronger than a rules file. It is not a guarantee.

The style file also carries one line that the rules file lacked: it states that it outranks
`prose-conventions.md`. That removes the conflict rather than shouting over it.

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

## What this repo cannot manage on a picnic workspace

A picnic checkout installs its own merge, `infra/cloud/workspace/configs/claude/hooks/sync-claude-settings.py`.
Its `SessionStart` hook runs it at every session start, after `install.sh`. It rewrites
three top-level keys from its own template, and it forces two more:

| Key | Result on a picnic workspace |
|---|---|
| `permissions.allow` entries | Kept |
| `outputStyle`, and any key picnic's template omits | Kept |
| `env` | Overwritten |
| `hooks` | Overwritten |
| `extraKnownMarketplaces` | Overwritten |
| `permissions.deny` | Overwritten |
| `permissions.defaultMode` | Forced to the template value |

So do not put a hook or an env var in `settings.json` here and expect it to survive. It
will work on the Mac and vanish on the workspace. `outputStyle` is safe, because picnic's
template never sets it.

One caveat sits outside picnic. Choosing a style through `/config` writes `outputStyle` to
the project's `.claude/settings.local.json`, and that layer outranks this one.

## Verify

```sh
~/.dotfiles/install.sh      # ~/dotfiles/install.sh on the Mac
ls -l ~/.claude/output-styles/
python3 -m json.tool ~/.claude/settings.json
```

Then start a session. Run `/config` and check **Output style**. It reads `Writing rules`.

## What reads what

| Surface | Reads `~/.claude` | Gets the rules |
|---|---|---|
| Claude Code, Mac and Coder | Yes | Yes, via this repo |
| Claude Code on the web (claude.ai/code) | Its own container | No. Add a dotfiles clone to the environment setup script |
| Claude Code subagents | Yes | No. A subagent runs its own system prompt |
| Cowork | Reads `~/.claude/skills/`. Styles unconfirmed | Test it: ask what writing rules it follows |
| Claude chat, web and Desktop in Chat mode | No | Paste only, see below |
| Claude mobile | No filesystem | Paste only, see below |

## Keep claude.ai personal preferences in sync

Claude chat and Claude mobile read no local files. They read only the personal-preferences
box in claude.ai settings. That box has no API and no config file, so you must paste by
hand. The paste stays manual, but the staleness check does not:

```sh
claude/sync-prefs.sh
```

The script copies the rules to the clipboard, without their frontmatter. It also writes
their hash to the stamp file, `claude/.prefs-synced`. Paste the rules, then commit the
stamp. On every run after that, `install.sh` compares the stamp against the current rules.
When the rules changed but the paste did not, it warns you. Commit the stamp so every
machine agrees on what the web account runs.
