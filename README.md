# agent-skills

Skills I use to work with coding agents (Claude Code, Codex, Copilot CLI, Gemini CLI) as a day-to-day engineering practice — a curated selection from the library I run every day.

Each skill is a folder with a `SKILL.md` in the open [Agent Skills](https://agentskills.io) format, so the same file works across tools. Most pair a short instruction file with a script that does the deterministic part, so the model narrates results instead of recomputing them.

## What these skills are built around

- **The parent agent stays accountable.** Workers get a bounded brief and return evidence; the parent reviews every changed file, maps evidence to each acceptance criterion and stops after three repair loops rather than manufacturing completion.
- **Humans and agents get different work.** A task is only "blocked on you" for one of seven concrete reasons — access, decision, device, external, irreversible, taste or knowledge. Everything else is agent work.
- **Steering goes in the right mechanism.** Facts in `CLAUDE.md`, file-specific constraints in path-scoped rules, guarantees in hooks, procedures in skills. A rule that must always hold is a hook, not a sentence.
- **Tokens are a cost to measure.** Descriptions load every session, bodies per activation, references on demand — so the skills are audited and trimmed in that order, and session cost is measured rather than guessed.

## The skills

| Skill | What it does | Why it exists |
| --- | --- | --- |
| [`/ceo-mode`](skills/ceo-mode/SKILL.md) | Runs a multi-part goal by delegating bounded deliverables to the cheapest capable worker, reviewing real outputs against acceptance criteria, and repairing at most three times. | Delegation is only useful if the result is checked. A worker's claim is not evidence. |
| [`/todo`](skills/todo/SKILL.md) | Reads a repo's git history, PRs, CI and TODOs, then writes two ranked lists: what's blocked on the human (with the reason and an exact test recipe) and what an agent can do unattended. | Coming back to a repo after time away, the first question is "what needs me, and what can run without me?" |
| [`/new-repo`](skills/new-repo/SKILL.md) | Scaffolds a repo with steering split by mechanism — a factual `CLAUDE.md`, a path-scoped rule, a `REVIEW.md`, a PR template, and a git-write hook it verifies before finishing. | Set up a repo for agents from the first commit instead of bolting rules on later. |
| [`/skill-audit`](skills/skill-audit/SKILL.md) | Measures every skill's token footprint and flags over-constraining instructions, then checks whether each one should really be a hook, rule or subagent. | Skills written for older models over-prescribe; current models follow instructions literally. |
| [`/token-report`](skills/token-report/SKILL.md) | Baselines a session and reports what it cost, or prints a 14-day usage history with cache efficiency and trends. | You can't reduce cost per run without measuring it. |
| [`/catalog`](skills/catalog/SKILL.md) | Lists every skill grouped by category from live frontmatter; `/catalog health` runs the library's lint. | The once-a-quarter skills are the ones you forget you have. |
| [`/new-skill`](skills/new-skill/SKILL.md) | Scaffolds a new skill that passes the lint first time — after first checking whether a skill is even the right mechanism. | Every item on its safety checklist was a real defect once shipped. |

## Install

```bash
git clone https://github.com/wtan0031/agent-skills.git
cd agent-skills
./install.sh      # symlinks each skill into Claude Code, Codex, Copilot CLI and Gemini CLI skill folders
```

Restart your agent (or open a new session) for the `/commands` to register. `./uninstall.sh` removes only the links that point back into this repo.

## Layout

```
agent-skills/
├── skills/<name>/SKILL.md      # the skill itself
├── skills/<name>/references/   # detail loaded only when a step needs it
├── .claude/hooks/              # the git-write guard /new-repo installs
├── install.sh · uninstall.sh   # link or unlink every skill
└── skill-links.sh              # the tool directories both scripts share
```

## Add a new skill

Run `/new-skill <name>`. It writes the `SKILL.md`, adds a row to the table above, installs the link and runs `bash skills/catalog/lint.sh`, which must report 0 fail.
