---
name: new-repo
description: "Scaffolds a new repo with steering split by mechanism — factual CLAUDE.md, path-scoped rules, a verified git-write hook, skill symlinks — then stops for the user to describe it. Use for new repos."
argument-hint: "<repo-name>"
allowed-tools: Bash, Write, AskUserQuestion
metadata:
  category: dev
  cadence: monthly
  when-to-use: "starting a brand-new project repo from scratch"
---

# New Repo Scaffold

$ARGUMENTS

---

`<library>` below means the root of this skills repo — resolve it once from this
skill's install symlink: `LIBRARY="$(cd -P ~/.claude/skills/new-repo/../.. && pwd -P)"`.

## Step 1 — Repo name & location

1. The repo name comes from `$ARGUMENTS`. If empty, ask the user for it via AskUserQuestion.
2. Ask the user (via AskUserQuestion) where to create it. Default is a sibling of `<library>` (`<library>/../<repo-name>`). Offer that as option 1; let the user pick a different path as option 2.
3. Run `ls <full-path> 2>/dev/null` via Bash. If the path already exists, **stop and ask** the user whether to abort or pick a different name — never overwrite.

## Step 2 — Pick skills to import

1. List the available skills with:
   ```bash
   ls -1 "$LIBRARY/skills/" | grep -v '^new-repo$'
   ```
2. For each skill, read its `SKILL.md` frontmatter `description:` line (use `head -10`) so you can show a one-liner per skill.
3. Present the list to the user via **AskUserQuestion** as a **multi-select** question titled "Which skills should this repo start with?". Each option label is the skill name; the description is the one-liner. Include an "Install all" option as a convenience.
4. Remember the selection for Step 4.

If `$LIBRARY/skills/` doesn't exist or is empty (just `new-repo`), skip the question and tell the user there are no other importable skills yet.

## Step 3 — Create the structure

Target layout — steering split by mechanism: facts in `CLAUDE.md`, constraints in
path-scoped rules, guarantees in hooks.

```
<repo>/
├── CLAUDE.md                        # facts only, always loaded
├── README.md
├── .gitignore
├── REVIEW.md                        # review-only rules (severity, nit cap, skips)
├── .github/pull_request_template.md # Testing, Risk, How to revert
└── .claude/
    ├── settings.json                # hook registration
    ├── hooks/block-git-write.sh     # copied in Step 4
    ├── rules/code-changes.md        # path-scoped constraint
    ├── agents/                      # empty — created on demand
    └── skills/                      # symlinks, Step 5
```

Read `references/templates.md` now and write each file verbatim from it, swapping
`{REPO_NAME}`. Use the `Write` tool, not heredocs. Create `.claude/agents/` with a
`.gitkeep`; it marks where project-specific subagents go later.

Also handle the user-level `~/.claude/CLAUDE.md` from that reference: create it only if
it does not already exist. Cross-project behavioural preferences go there once per
machine, never duplicated into each repo. If it exists, skip it silently and note
"skipped (already present)" in the Step 7 report.

## Step 4 — Install the git guardrail

```bash
mkdir -p <full-path>/.claude/hooks
cp "$LIBRARY/.claude/hooks/block-git-write.sh" <full-path>/.claude/hooks/
chmod +x <full-path>/.claude/hooks/block-git-write.sh
```

Copy, don't symlink. Skills symlink so edits propagate; a hook is a guardrail and must
not dangle into a silent no-op.

Verify it blocks and allows correctly before moving on:

```bash
echo '{"tool_input":{"command":"git commit -m x"}}' | <full-path>/.claude/hooks/block-git-write.sh >/dev/null 2>&1; echo "commit -> $? (expect 2)"
echo '{"tool_input":{"command":"git status"}}'      | <full-path>/.claude/hooks/block-git-write.sh >/dev/null 2>&1; echo "status -> $? (expect 0)"
```

If either result is wrong, stop and say so — an unverified guardrail is worse than none.

## Step 5 — Install the selected skills

For each skill the user picked in Step 2:

```bash
mkdir -p <full-path>/.claude/skills
ln -s "$LIBRARY/skills/<skill-name>" <full-path>/.claude/skills/<skill-name>
```

Use **symlinks**, not copies, so edits in the library propagate to every repo that imported the skill (single source of truth).

If the user selected none, skip this step.

## Step 6 — Initialise git (no commit)

```bash
cd <full-path> && git init -q
```

Do not run `git add` or `git commit`. Files stay untracked in the working tree so the
user can review the scaffold before the first commit.

## Step 7 — Report and hand off

Print a short summary (5–6 lines max): full path; files created; git guardrail
installed + verified (or failed); user-level `~/.claude/CLAUDE.md` created or skipped
(already present); skills installed (names only, comma-separated, or "none"); git
initialised with no commits.

Then end the turn with **one** open question to the user:

> Repo is ready. What's the idea — what should this project do?

Stop there. Wait for the user to describe the project before proposing features,
architecture, or next steps.

---

## Notes

- **No package manager init by default** (no `npm init`, `swift package init`, etc.);
  the project type isn't known yet.
- **No remote yet.** The user creates it with `gh repo create --private` when ready.
- If the user requests a different baseline (e.g., "also add a docs/ folder"), accept it for this run but don't bake it into the default.
- **Where new steering goes later.** Facts → `CLAUDE.md`; constraints on particular
  files → path-scoped rules; deterministic guarantees → hooks; multi-step procedures →
  skills; fan-out searches or audits → subagents in `.claude/agents/`.
- **Don't pre-write speculative rules.** One path-scoped rule ships by default. Add more
  only when a real constraint shows up.
