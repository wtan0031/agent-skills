#!/usr/bin/env python3
"""Store access for the `todo` skill.

Owns every read/write of ~/.claude/todo so the model never has to load whole
files to answer "what's outstanding". Subcommands:

  init                    create the store with locked-down permissions
  key [path]              print the repo key for a path (default: cwd)
  path <key>              print the list file path for a key
  profile-path <key>      print the profile file path for a key
  stats [key]             counts for one repo (default: current repo)
  show [key]              print one repo's list verbatim
  done <id> [key]         tick an item off and stamp it
  reopen <id> [key]       untick an item
  index                   rebuild _index.md from every stored list
  repos                   list known repo keys, one per line

The store lives at an absolute path under $HOME, never inside the repo being
analysed -- the skill is invoked from arbitrary repos and must not scatter
state into them.
"""

import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path.home() / ".claude" / "todo"
LISTS = ROOT / "repos"
PROFILES = ROOT / "profiles"

# "### [ ] B1 — title" / "### [x] A2 — title"
# `[ \t]*$`, never `\s*$` -- with re.M, `\s` matches newlines and a greedy run
# would swallow the blank line after the heading on every done/reopen round-trip.
ITEM_RE = re.compile(r"^### \[( |x)\] ([AB]\d+) — (.+?)[ \t]*$", re.M)


def init():
    for d in (ROOT, LISTS, PROFILES):
        d.mkdir(parents=True, exist_ok=True)
        d.chmod(0o700)
    return ROOT


def _secure(p: Path):
    """Lists and profiles hold env URLs and account identifiers -- owner-only."""
    if p.exists():
        p.chmod(0o600)


def repo_key(start: str | None = None) -> str:
    """Key a repo by its git remote if it has one, else its directory name.

    Deliberately keyed off the *current* repo, unlike most skills in this repo:
    analysing wherever the user invoked from is the entire point. Only the
    store path is fixed to $HOME.
    """
    cwd = Path(start or os.getcwd()).resolve()
    try:
        top = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=10,
        )
        if top.returncode == 0:
            cwd = Path(top.stdout.strip())
        remote = subprocess.run(
            ["git", "-C", str(cwd), "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=10,
        )
        if remote.returncode == 0 and remote.stdout.strip():
            url = remote.stdout.strip()
            url = re.sub(r"\.git$", "", url)
            parts = re.split(r"[:/]", url)
            if len(parts) >= 2:
                return _slug(f"{parts[-2]}-{parts[-1]}")
    except (OSError, subprocess.SubprocessError):
        pass
    return _slug(cwd.name)


def _slug(s: str) -> str:
    s = re.sub(r"[^A-Za-z0-9._-]+", "-", s).strip("-")
    return (s or "unknown")[:80]


def list_path(key: str) -> Path:
    return LISTS / f"{_slug(key)}.md"


def profile_path(key: str) -> Path:
    return PROFILES / f"{_slug(key)}.json"


def _read(key: str) -> str:
    p = list_path(key)
    if not p.exists():
        sys.exit(f"No list for '{key}' yet. Run /todo in that repo first.")
    return p.read_text()


def stats(key: str) -> dict:
    p = list_path(key)
    if not p.exists():
        return {"key": key, "exists": False, "blocked_open": 0, "agent_open": 0,
                "blocked_done": 0, "agent_done": 0, "updated": None}
    text = p.read_text()
    out = {"key": key, "exists": True, "blocked_open": 0, "agent_open": 0,
           "blocked_done": 0, "agent_done": 0}
    for mark, ident, _title in ITEM_RE.findall(text):
        kind = "blocked" if ident.startswith("B") else "agent"
        out[f"{kind}_{'done' if mark == 'x' else 'open'}"] += 1
    m = re.search(r"^_Updated ([0-9]{4}-[0-9]{2}-[0-9]{2})", text, re.M)
    out["updated"] = m.group(1) if m else None
    return out


def set_done(key: str, ident: str, done: bool):
    p = list_path(key)
    text = _read(key)
    ident = ident.upper()
    hits = [m for m in ITEM_RE.finditer(text) if m.group(2) == ident]
    if not hits:
        sys.exit(f"No item '{ident}' in {p}")
    m = hits[0]
    mark = "x" if done else " "
    title = re.sub(r"\s*_\(done [0-9-]+\)_$", "", m.group(3))
    if done:
        title += f" _(done {date.today().isoformat()})_"
    text = text[:m.start()] + f"### [{mark}] {ident} — {title}" + text[m.end():]
    p.write_text(text)
    _secure(p)
    print(f"{ident} -> {'done' if done else 'reopened'} in {p.name}")


def known_repos() -> list[str]:
    if not LISTS.exists():
        return []
    return sorted(p.stem for p in LISTS.glob("*.md"))


def build_index() -> Path:
    init()
    rows = [stats(k) for k in known_repos()]
    rows.sort(key=lambda r: (-r["blocked_open"], -r["agent_open"], r["key"]))
    total_b = sum(r["blocked_open"] for r in rows)
    total_a = sum(r["agent_open"] for r in rows)
    lines = [
        "# Todo index",
        "",
        f"_Rebuilt {date.today().isoformat()} · "
        f"{total_b} blocked on you · {total_a} agent-ready · {len(rows)} repos_",
        "",
        "| Repo | Blocked on you | Agent-ready | Done | Updated |",
        "| --- | --- | --- | --- | --- |",
    ]
    for r in rows:
        lines.append(
            f"| [{r['key']}](repos/{r['key']}.md) | {r['blocked_open']} | "
            f"{r['agent_open']} | {r['blocked_done'] + r['agent_done']} | "
            f"{r['updated'] or '—'} |"
        )
    if not rows:
        lines.append("| _(none yet)_ | | | | |")
    p = ROOT / "_index.md"
    p.write_text("\n".join(lines) + "\n")
    _secure(p)
    return p


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "stats"
    rest = args[1:]

    if cmd == "init":
        print(init())
    elif cmd == "key":
        print(repo_key(rest[0] if rest else None))
    elif cmd == "path":
        print(list_path(rest[0] if rest else repo_key()))
    elif cmd == "profile-path":
        print(profile_path(rest[0] if rest else repo_key()))
    elif cmd == "stats":
        print(json.dumps(stats(rest[0] if rest else repo_key()), indent=2))
    elif cmd == "show":
        print(_read(rest[0] if rest else repo_key()), end="")
    elif cmd in ("done", "reopen"):
        if not rest:
            sys.exit(f"usage: todo.py {cmd} <id> [key]")
        set_done(rest[1] if len(rest) > 1 else repo_key(), rest[0], cmd == "done")
    elif cmd == "index":
        print(build_index())
    elif cmd == "repos":
        print("\n".join(known_repos()))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
