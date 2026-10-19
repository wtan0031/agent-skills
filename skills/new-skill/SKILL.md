---
name: new-skill
description: "Scaffolds a new skill in this library — SKILL.md with lint-clean frontmatter, README entry, install symlink — and verifies it with the catalog lint. Use when adding a skill to this repo."
argument-hint: "<skill-name> [one-line purpose]"
allowed-tools: AskUserQuestion, Read, Write, Edit, Bash
metadata:
  category: meta
  cadence: monthly
  when-to-use: "adding a brand-new skill to this repo"
---

# New Skill — scaffold a skill the standard way

$ARGUMENTS

---

This is the library's own scaffolder. It produces everything the README's "Add a new
skill" section asks for, pre-shaped to pass `/catalog health` on the first run.

## Step 0 — Is a skill the right mechanism?

A skill is for a **multi-step procedure invoked on demand**. Three things get built as
skills by habit but belong elsewhere — check before scaffolding:

| If the purpose is… | Build instead | Why |
| --- | --- | --- |
| "every time X, always Y" / "never do X" | a **hook** in `.claude/settings.json` | instructions are suggestions Claude can drift from; a `PreToolUse` hook exiting 2 is a real block |
| a single constraint on particular files, no steps | a **path-scoped rule** in `.claude/rules/` with `paths:` frontmatter | loads only when those files are touched |
| a wide search/audit whose intermediate output would flood the session | a **subagent** in `.claude/agents/` | runs in its own context; only the summary returns |

If one of these fits better, say so and build that instead — a one-file hook or rule is
usually less work than a skill. Only continue to Step 1 for genuine procedures. When it's
genuinely ambiguous, ask via AskUserQuestion rather than defaulting to a skill.

Note a skill may still *contain* a hook: `.claude/skills/<name>/` supports hook
registration in frontmatter for hooks scoped to that skill's lifecycle.

## Step 1 — Name + purpose

From `$ARGUMENTS` take the skill name (kebab-case) and a one-line purpose. Ask via
AskUserQuestion only for whichever is missing. Then confirm two quick choices in one
batch: **category** (`dev` / `meta` / other) and whether it's a
**recipe** (documentation to re-apply by hand, not an invocable command).

If `skills/<name>/` already exists, stop and say so — never overwrite.

## Step 2 — Write `skills/<name>/SKILL.md`

**Read `references/skill-safety-checklist.md` now** — every item on it was a real
defect once shipped in this repo (secrets in command lines, unvalidated manifest
commands, `git rev-parse` path bugs, PII through `/tmp`, unquoted YAML colons).
The new skill must satisfy every applicable item before Step 4's lint.

Frontmatter (the lint checks the first three):
- `name:` equals the folder name.
- `description:` in double quotes, **≤200 chars**, third person: what it does, then
  "Use when…" with the words a user would actually say. Lead with the key use case (hosts
  truncate long listings) and name the boundary if a sibling skill overlaps. If it writes
  files, opens apps or spawns agents, make the trigger an explicit ask ("Use when asked
  to…") so it doesn't fire on ordinary requests. It loads into every session; detail
  belongs in the body.
- `allowed-tools:` only what the skill genuinely needs.
- Catalog fields go under `metadata:` as strings — `category`, `cadence`
  (`daily`/`weekly`/`monthly`/`quarterly`/`rare`), `when-to-use`, and `recipe: "true"` if
  Step 1 said so. Otherwise use only the spec's top-level keys (`name`, `description`,
  `license`, `compatibility`, `metadata`, `allowed-tools`) plus host extensions the skill
  needs (`argument-hint`, `disable-model-invocation`). Local hosts read those extensions,
  but strict upload validators (claude.ai, the Skills API) accept only the spec keys, so
  strip extensions before uploading a skill there.
- Leave `effort` out so the skill inherits the session's level; it overrides the session
  and means different things on different models.
- For a workflow with side effects the user should trigger by hand (deploys, wipes,
  sending), add `disable-model-invocation: true` and `agents/openai.yaml` with
  `policy:` → `allow_implicit_invocation: false` (Codex).

Body — write for a capable model that follows instructions literally:
- Open with the outcome: what the skill produces, what "done" looks like, what it won't do.
- Use numbered steps only where order matters (approval before an expensive render, backup
  before a delete); for judgment work give the goal, constraints and output shape instead.
- State each rule once, where it applies, with its reason. Reserve always/never for real
  invariants (secrets, destructive or external actions, untrusted input) — a closing
  guardrails list holds only those, never restatements of the steps.
- Skip personas, "when to use" sections (the description does that), re-verification
  steps without a concrete check, asks to write out its reasoning in the reply (current Claude models may
  refuse them), and generic advice the model already follows — test each line with
  "would the agent get this wrong without it?"
- Keep a short **Gotchas** list of concrete, non-obvious corrections (the highest-value
  lines in most skills), and put invariants near the top: after compaction Claude Code
  re-attaches only the first 5k tokens of a skill.
- Push depth into `references/` (create the folder only when there's a first file for it,
  and point to each file at the step that needs it: "Read X when Y"),
  and route reads/writes of large shared data files through a bundled script (see
  `todo/todo.py`) instead of having the model Read them whole.

## Step 3 — README entry

Add one row for the new skill to the skills table in `README.md`, matching the existing
rows: the `/name`, what it does in one line, and why it exists. Leave other rows untouched.

## Step 4 — Install + verify

```bash
./install.sh                   # links every skill into each tool's skills dir; recipes skipped
bash skills/catalog/lint.sh
```

The lint must come back **0 fail** — fix anything it flags before finishing. Remind the
user to restart their AI tool (or open a new session) so `/<name>` registers.

## Step 5 — Hand off

Print the path, the README row and the lint result, then stop so the user can fill in
the skill's real logic. Scaffold only what the README's process names, and leave
committing to the user unless they asked for it.
