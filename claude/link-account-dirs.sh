#!/usr/bin/env bash
# Share one set of Claude Code practices across the per-account config
# directories, so every Claude account on this box works the same way.
#
# The team account keeps the default directory, ~/.claude. Each other account
# has its own directory (bin/claude-personal, bin/claude-research), because a
# login belongs to a directory. This script makes those directories read the
# team directory's files:
#
#   - CLAUDE.md, rules, agents, commands, hooks, output-styles, settings.json
#     and keybindings.json become links. The safety hooks in settings.json
#     then apply to every account.
#   - projects becomes a link, so transcripts and auto memory are shared. A
#     conversation one account started can be resumed by another, by id.
#   - Each skill in ~/.claude/skills gets a link. The account's own
#     skills/synced folder stays, because Claude Code fills it per account.
#   - .claude.json stays separate, because it holds the login. The script
#     copies in the MCP servers the account lacks and marks onboarding done.
#
# It never replaces a file it did not make, and it does nothing to a directory
# that a running session uses. Run it again after you add a skill.
#
# Usage: link-account-dirs.sh [account directory ...]
#   With no arguments it handles ~/.claude-personal and ~/.claude-research.

set -euo pipefail

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

TEAM="$HOME/.claude"
SHARED=(CLAUDE.md rules agents commands hooks output-styles settings.json keybindings.json)

if [ "$#" -gt 0 ]; then
  ACCOUNTS=("$@")
else
  ACCOUNTS=("$HOME/.claude-personal" "$HOME/.claude-research")
fi

# Whether a running Claude Code process uses this config directory.
dir_in_use() {
  local dir="${1%/}" envfile val
  for envfile in /proc/[0-9]*/environ; do
    # Another user's process refuses the read. The braces hide that message.
    val="$({ tr '\0' '\n' <"$envfile" | sed -n 's/^CLAUDE_CONFIG_DIR=//p' | head -1; } 2>/dev/null || true)"
    [ -n "$val" ] && [ "${val%/}" = "$dir" ] && return 0
  done
  return 1
}

link_one() {
  local src="$1" dst="$2"
  [ -e "$src" ] || return 0
  if [ -L "$dst" ]; then
    [ "$(readlink "$dst")" = "$src" ] || echo "  skipped $dst: it links somewhere else"
    return 0
  fi
  if [ -e "$dst" ]; then
    echo "  skipped $dst: it exists and this script did not make it"
    return 0
  fi
  ln -s "$src" "$dst"
  echo "  linked $dst"
}

# Move the account's own transcripts into the team directory, then link.
share_projects() {
  local dir="$1" rel target
  if [ -L "$dir/projects" ]; then
    [ "$(readlink "$dir/projects")" = "$TEAM/projects" ] || echo "  skipped $dir/projects: it links somewhere else"
    return 0
  fi
  if [ -d "$dir/projects" ]; then
    # Move each file to the same path in the team directory. A file the team
    # directory already holds is never overwritten: it stays where it is.
    while IFS= read -r -d '' rel; do
      target="$TEAM/projects/$rel"
      mkdir -p "$(dirname "$target")"
      [ -e "$target" ] || mv "$dir/projects/$rel" "$target"
    done < <(cd "$dir/projects" && find . -type f -print0)
    find "$dir/projects" -depth -type d -empty -delete
    if [ -d "$dir/projects" ]; then
      echo "  skipped $dir/projects: the team directory holds files of the same name"
      return 0
    fi
  fi
  ln -s "$TEAM/projects" "$dir/projects"
  echo "  linked $dir/projects"
}

share_skills() {
  local dir="$1" skill name made=0 removed=0 link
  mkdir -p "$dir/skills"
  for skill in "$TEAM/skills"/*; do
    name="$(basename "$skill")"
    [ "$name" = synced ] && continue
    if [ ! -e "$dir/skills/$name" ] && [ ! -L "$dir/skills/$name" ]; then
      ln -s "$skill" "$dir/skills/$name"
      made=$((made + 1))
    fi
  done
  # Drop links this script made whose skill left the team directory.
  for link in "$dir/skills"/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in
      "$TEAM/skills/"*) [ -e "$link" ] || { rm "$link"; removed=$((removed + 1)); } ;;
    esac
  done
  echo "  skills: $made linked, $removed stale links removed"
}

share_mcp_servers() {
  python3 -I - "$TEAM/../.claude.json" "$1/.claude.json" <<'PY'
import json, os, sys, tempfile

team_path, account_path = sys.argv[1], sys.argv[2]
team = json.load(open(team_path))
if not os.path.exists(account_path):
    print("  skipped MCP servers: the account has no .claude.json yet (sign in first)")
    sys.exit(0)
account = json.load(open(account_path))
servers = account.setdefault("mcpServers", {})
added = [name for name in team.get("mcpServers", {}) if name not in servers]
for name in added:
    servers[name] = team["mcpServers"][name]
changed = bool(added)
if not account.get("hasCompletedOnboarding"):
    account["hasCompletedOnboarding"] = True
    changed = True
if changed:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(account_path))
    with os.fdopen(fd, "w") as handle:
        json.dump(account, handle, indent=2)
    os.chmod(tmp, 0o600)
    os.replace(tmp, account_path)
print(f"  MCP servers: {len(added)} added ({', '.join(added) or 'none'})")
PY
}

for dir in "${ACCOUNTS[@]}"; do
  dir="${dir%/}"
  echo "$dir"
  if [ "$dir" = "$TEAM" ]; then
    echo "  skipped: this is the team directory"
    continue
  fi
  if [ ! -d "$dir" ]; then
    echo "  skipped: no such directory (sign in to the account first)"
    continue
  fi
  if dir_in_use "$dir"; then
    echo "  skipped: a running session uses it. Exit that session, then run this again."
    continue
  fi
  for name in "${SHARED[@]}"; do
    link_one "$TEAM/$name" "$dir/$name"
  done
  share_projects "$dir"
  share_skills "$dir"
  share_mcp_servers "$dir"
done
