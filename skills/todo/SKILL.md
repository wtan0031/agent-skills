---
name: todo
description: "Reads a repo's state and writes two ranked worklists — items blocked on the user (why, exact test steps, accounts) and items the agent can do alone. Use when asked what's left or what's blocked."
argument-hint: "[list | all | done <id> | reopen <id> | profile]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
metadata:
  category: dev
  cadence: weekly
  when-to-use: "returning to a repo after time away, or when you want to know exactly what needs you versus what the agent can pick up alone"
---

# Todo — what needs you, and what the agent can take

$ARGUMENTS

---

Analyses the repo you're in and maintains two ranked lists: **blocked on you**
(specific reason plus click-by-click test recipe) and **agent can do unattended**
(plain-language work the agent can take later). Lists live outside the repo, in
`~/.claude/todo/`, so nothing leaks into project git history. This skill reports
and plans; it does not implement the agent items.

## Dispatch

Read `$ARGUMENTS` and take exactly one path:

| Args | Do |
| --- | --- |
| _(empty)_ | Full refresh of the current repo — Steps 1–5 |
| `list` | Step 0, then `todo.py show`; print it. No analysis, no writes |
| `all` | For every repo in `todo.py repos`, refresh if its git state changed since `_Updated`; then `todo.py index` and print the index |
| `done <id>` / `reopen <id>` | `todo.py done <id>` / `reopen <id>`, then `todo.py index`. Nothing else |
| `profile` | Re-run the interview in `references/profile.md` and rewrite the profile. No list changes |

## Step 0 — Locate the store and the repo

```bash
SKILL_DIR="$(cd -P ~/.claude/skills/todo && pwd -P)"
python3 "$SKILL_DIR/todo.py" init
KEY="$(python3 "$SKILL_DIR/todo.py" key)"
```

`todo.py` keys the repo off its git remote (falling back to directory name) and
always writes under `$HOME`. Unlike most skills here, reading the *current* repo
is intentional — that's the whole point — but never write list state into it.

If the current directory isn't a git repo, say so and stop: this skill reads git
history to judge what's landed.

## Step 1 — Read the repo's actual state

Gather evidence before judging anything. Do not guess from filenames.

```bash
git log --oneline -25
git status --short
git branch --show-current
gh pr list --state open --json number,title,headRefName,isDraft 2>/dev/null
gh pr list --state merged --limit 5 --json number,title,mergedAt 2>/dev/null
```

Read what those point at: the diff of open PRs, any `TODO`/`FIXME` markers
(`grep -rn "TODO\|FIXME" --include='*.*' | head -40`), failing or skipped tests,
CI status (`gh run list --limit 5`), and the README/CLAUDE.md for what the
project is *supposed* to do. Note anything half-finished — a merged PR whose
acceptance criteria had unchecked boxes is a strong todo source.

If a previous list exists (`todo.py show "$KEY"`), read it first: carry open
items forward with their ids rather than regenerating from scratch.

## Step 2 — Load or build the repo profile

```bash
python3 "$SKILL_DIR/todo.py" profile-path "$KEY"
```

If the profile exists, read it. If not — or if a blocked item needs something
it doesn't cover — **read `references/profile.md` now** and run the interview.
Infer everything the repo already states; ask only for the rest, batched.

Never invent an account, URL, or credential location. Unknowns become
`<unknown — needed>` in the item and a line in the profile's `gaps`.

## Step 3 — Sort the work into the two lists

**Read `references/blocked-reasons.md` now.** For each piece of outstanding
work, decide honestly whether it needs the user. Every blocked item must carry
one of the seven reason tags; anything else belongs on the agent list. Effort,
size, and "I'd like you to check it" are not blockers.

Rank both lists P1/P2/P3 on one scale across the whole repo, and cap P1s at
about three — a list where everything is urgent says nothing.

## Step 4 — Write the list file

**Read `references/item-format.md` now** and write the file at
`todo.py path "$KEY"` in exactly that shape. The `### [ ] B1 — title` heading
format is a parsing contract — `todo.py` reads it for counts and `done`.

Blocked items need all of: the specific reason the agent can't do it, the
environment, the sign-in account, where its credential lives, the click path,
what success looks like, what failure looks like, and what to capture if it
fails. Agent items need plain-language "what this is", why it matters, which
files change, definition of done, and the risk.

Then rebuild the cross-repo view:

```bash
python3 "$SKILL_DIR/todo.py" index
```

## Step 5 — Report

Print, in the session:

1. One-paragraph state of play.
2. The blocked list, P1 first — title, reason tag, and time estimate only.
3. The agent list, P1 first — title, effort, and one line of what it is.
4. Any profile `gaps` that made an item vaguer than it should be.
5. The file path, so they can open the full detail.

End by offering to start the top agent item — but do not begin it unprompted.

## Hard rules

- **Never store a secret.** Passwords, API keys and tokens are never written to
  the profile, the list, or any file — only pointers to where they live. If the
  user volunteers one, say plainly that it wasn't saved.
- Store dir is `chmod 700`, files `chmod 600` (`todo.py` enforces this); it
  holds internal URLs and account identifiers. Preserve the modes on rewrite.
- Never write list state into the analysed repo, and never `git add` anything.
- Report only what the evidence supports. If a test's status is unknown, say
  "unknown", never "passing".
- Do not implement agent items during a refresh, and never commit or push.
