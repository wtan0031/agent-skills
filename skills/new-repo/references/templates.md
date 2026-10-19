# new-repo scaffold templates

Write these verbatim with the Write tool (not heredocs), swapping `{REPO_NAME}`.

The split below follows Anthropic's steering guidance: **CLAUDE.md holds facts**
(always loaded, so keep it small), **rules hold constraints** (path-scoped, so they
load only when relevant files are touched), **hooks hold guarantees** (deterministic,
outside the context window). Behavioural preferences that apply to *every* project
belong in the user-level `~/.claude/CLAUDE.md`, not duplicated into each repo.

## Contents

- [CLAUDE.md](#claudemd) — factual, always loaded
- [README.md](#readmemd)
- [.gitignore](#gitignore)
- [REVIEW.md](#reviewmd) — review-only rules for Code Review
- [.github/pull_request_template.md](#githubpull_request_templatemd) — Testing, Risk, How to revert
- [.claude/settings.json](#claudesettingsjson) — hook registration
- [.claude/rules/code-changes.md](#clauderulescode-changesmd) — path-scoped
- [~/.claude/CLAUDE.md](#user-level-claudemd) — user-level, written once per machine

---

## CLAUDE.md

Facts only — what this project *is* and how to work it. No behavioural directives;
those live in rules and hooks. Keep under 200 lines. Most fields are unknown at
scaffold time, so they are stubbed as TBD for the user to fill in once the project
direction is set.

```markdown
# {REPO_NAME}

_One-line description — TBD._

## Layout

_TBD — fill in once there's structure worth describing._

## Commands

| Task | Command |
| --- | --- |
| Install | _TBD_ |
| Build | _TBD_ |
| Test | _TBD_ |
| Lint | _TBD_ |

## Conventions

_TBD — language/framework norms specific to this repo._

## Steering

- Constraints live in `.claude/rules/` (path-scoped — they load only when matching
  files are touched).
- Git writes are blocked by `.claude/hooks/block-git-write.sh` (PreToolUse, exit 2).
- Procedures live in `.claude/skills/`. Subagents, if any, live in `.claude/agents/`.
- Reviews apply `REVIEW.md` (Code Review reads it; local `/code-review` reads only
  this file, so this line carries it there).
- My instructions in the session override every file here.
```

## README.md

```markdown
# {REPO_NAME}

_TBD — fill in once the project direction is set._
```

## .gitignore

```
.DS_Store
*.log
.vscode/
.idea/
node_modules/
.env
.env.local
```

Note: `.claude/` is deliberately **not** ignored — the rules and hooks are part of the
repo's steering config and should be versioned. Add `.claude/settings.local.json` if
the user later wants machine-local overrides kept out of git.

## REVIEW.md

Review-only rules, read by Claude Code Review from the default branch. Keep project facts in
`CLAUDE.md`. Stubbed until the project's failure modes are known; the evidence and summary
rules apply from day one.

```markdown
# Review instructions

## What Important means here

_TBD — the failures that matter in this repo (for docs, "it lies"; for config, "it
misroutes"). Style, naming and refactors are Nit at most._

## Cap the nits

Report at most five Nits per review.

## Do not report

- Anything CI already enforces (lint, formatting, type errors)
- _TBD — generated files, lockfiles, vendored code_

## Always check

_TBD — rules to flag on every PR._

## Evidence and summary

Behavior claims need a `file:line` citation, not an inference from a name. Start the
summary with a count by severity and say plainly when there is nothing to fix.
```

When the same review comment keeps coming back, add the rule here instead of re-arguing it.

## .github/pull_request_template.md

```markdown
## Summary

## Testing
<!-- Commands run and their results. "Tested" without output doesn't count. -->

## Risk
<!-- Low / Medium / High, set by what the change touches, with the reason. -->

## How to revert
<!-- "Revert this PR", or the migration, flag or data step needed. -->
```

## .claude/settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/block-git-write.sh\""
          }
        ]
      }
    ]
  }
}
```

The hook script itself is **copied** (not symlinked) from
`<library>/.claude/hooks/block-git-write.sh` — see the skill's
Step 4. A guardrail must not be able to dangle; skills symlink, hooks copy.

## .claude/rules/code-changes.md

Path-scoped: costs nothing until Claude touches a source file. The glob list is
deliberately broad because the project's language is unknown at scaffold time —
trim it to the real extensions once the project direction is set.

```markdown
---
paths:
  - "**/*.{ts,tsx,js,jsx,py,swift,go,rs,rb,java,kt,c,h,cpp,cs,sh}"
---

- Read before edit. Prefer a targeted edit over a full rewrite.
- Reuse before create — search the codebase for an existing utility/helper first.
- Implement only what's asked. No speculative abstractions, helpers, or files "for later".
- No code comments unless the WHY is non-obvious (hidden constraint, subtle invariant,
  workaround). Never comment what the code already says.
- Match the surrounding code's naming, structure, and error handling rather than
  importing conventions from elsewhere.
```

## User-level CLAUDE.md

These are cross-project preferences about *how Claude should behave*, not facts about
any one repo — so they are written **once per machine** at `~/.claude/CLAUDE.md`, not
copied into every project. Only create this if it does not already exist; if it does,
leave it alone and tell the user it was skipped.

```markdown
# Global preferences

- Keep responses concise. Skip filler, preamble, and restating the obvious.
- Push back on unnecessary complexity. Surface assumptions instead of guessing.
- Don't claim something works until it's been run and the output checked.
- Project files and my in-session instructions both override this file.
```
