#!/usr/bin/env python3
"""Merge dotfiles-managed Claude Code settings into ~/.claude/settings.json.

Claude Code writes to that same file at runtime: `model` (/model), `effortLevel`
(/effort), `advisorModel` (/advisor), `askUserQuestionTimeout`,
`autoCompactWindow`, and assorted /config toggles. You and the app share the
layer, so this merges rather than symlinking. App-written keys survive; the keys
declared in dotfiles win.

Merge rules:
  - dicts recurse
  - lists union, preserving order and dropping duplicates (matches how Claude
    Code merges permissions.allow / deny across settings scopes)
  - scalars: dotfiles wins

Removals work in both directions, which a plain merge cannot do. The previous
dotfiles settings are recorded in ~/.claude/.dotfiles-managed.json, so deleting a
key removes it from the target, and deleting one element of a managed list (a
single permissions.allow entry, say) removes just that element. Anything the app
added on its own is never touched.

Usage: merge-settings.py <dotfiles-settings.json> [target-settings.json]
"""

import json
import os
import sys
import tempfile


def merge(base, overlay):
    """Overlay wins. Dicts recurse, lists union, scalars replace."""
    if isinstance(base, dict) and isinstance(overlay, dict):
        out = dict(base)
        for key, value in overlay.items():
            out[key] = merge(base.get(key), value) if key in base else value
        return out
    if isinstance(base, list) and isinstance(overlay, list):
        out = list(base)
        for item in overlay:
            if item not in out:
                out.append(item)
        return out
    return overlay


def key_paths(node, prefix=()):
    """Every non-dict leaf path in a nested dict, as tuples. Lists are leaves."""
    if isinstance(node, dict) and node:
        for key, value in node.items():
            yield from key_paths(value, prefix + (key,))
    else:
        yield prefix


def value_at(node, path):
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return None
        node = node[key]
    return node


def drop_path(node, path):
    """Remove one leaf path, pruning any dict left empty."""
    if not path or not isinstance(node, dict) or path[0] not in node:
        return
    if len(path) == 1:
        del node[path[0]]
        return
    drop_path(node[path[0]], path[1:])
    if node[path[0]] == {}:
        del node[path[0]]


def drop_items(node, path, unwanted):
    """Remove specific elements from the list at path. Returns what it removed."""
    current = value_at(node, path)
    if not isinstance(current, list):
        return []
    kept = [item for item in current if item not in unwanted]
    if kept == current:
        return []
    parent = node
    for key in path[:-1]:
        parent = parent[key]
    parent[path[-1]] = kept
    return [item for item in current if item in unwanted]


def load(path, default):
    try:
        with open(path) as handle:
            return json.load(handle)
    except FileNotFoundError:
        return default
    except json.JSONDecodeError as exc:
        sys.exit(f"    {path} is not valid JSON ({exc}). Fix or move it, then re-run.")


def write_json(path, data, **kwargs):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    handle = tempfile.NamedTemporaryFile(
        "w", dir=os.path.dirname(path) or ".", delete=False
    )
    with handle:
        json.dump(data, handle, indent=2, **kwargs)
        handle.write("\n")
    os.replace(handle.name, path)


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: merge-settings.py <dotfiles-settings.json> [target]")

    source_path = sys.argv[1]
    target_path = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser(
        "~/.claude/settings.json"
    )
    state_path = os.path.join(os.path.dirname(target_path), ".dotfiles-managed.json")

    source = load(source_path, {})
    if not isinstance(source, dict):
        sys.exit(f"    {source_path} must contain a JSON object.")
    target = load(target_path, {})
    previous = load(state_path, {}).get("source", {})

    # An empty dict yields the root path; it names no setting, so drop it.
    current_paths = [list(path) for path in key_paths(source) if path]
    previous_paths = [list(path) for path in key_paths(previous) if path]

    result = json.loads(json.dumps(target))
    removals = []

    # Keys dropped from dotfiles since the last run.
    for path in previous_paths:
        if path not in current_paths and value_at(result, path) is not None:
            drop_path(result, tuple(path))
            removals.append(".".join(path))

    # Elements dropped from a managed list since the last run.
    for path in current_paths:
        was, now = value_at(previous, path), value_at(source, path)
        if isinstance(was, list) and isinstance(now, list):
            gone = [item for item in was if item not in now]
            for item in drop_items(result, path, gone):
                removals.append(f"{'.'.join(path)}[{item!r}]")

    result = merge(result, source)

    changed = result != target
    if changed:
        write_json(target_path, result, sort_keys=True)
    write_json(state_path, {"source": source})

    if changed:
        print(f"    Merged {len(current_paths)} managed key(s) into {target_path}")
        for item in removals:
            print(f"    Removed {item} (no longer in dotfiles)")
    else:
        print(f"    {target_path} already up to date")


if __name__ == "__main__":
    main()
