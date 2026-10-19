---
name: skill-audit
description: "Audits skills for token cost, mechanism fit and over-constraining instructions — bloat, inline templates, rigid rules, skills better as a hook, rule or subagent. Use for a periodic skill tune-up."
argument-hint: "[skills-dir | --apply]"
allowed-tools: Bash, Read, Write, Edit, Agent
metadata:
  category: dev
  cadence: monthly
  when-to-use: "skills feel token-heavy, after adding several skills, or a periodic efficiency pass"
---

# Skill Audit — token and instruction-fit pass over your skills

$ARGUMENTS

Find where skills waste tokens or over-constrain the model, and propose (or apply) fixes scored against [references/rubric.md](references/rubric.md) — read it before judging anything. It merges Anthropic's progressive-disclosure model with current Anthropic and OpenAI guidance on instruction style.

**Lever order:** L1 descriptions load *every session* (recurring tax) → L2 bodies load per activation → L3 reference files are ~free. Optimise in that order, but keep every trigger word: a description too thin to trigger costs more than it saves.

## Step 1 — Measure

Run the bundled script rather than eyeballing sizes:
```
bash ./skills/skill-audit/audit.sh [skills-dir]
```
Outside this repo, run the same `audit.sh` through the host's symlinked skill path. It prints description lengths, body line counts (>250 split candidate, >500 over ceiling), reference-file sizes, inline-content heuristics (code blocks, inline HTML/CSS, duplicate "rules" tails) and over-constraint signals (CAPS absolutes, forced re-verification, reasoning echo, severity filters, anti-format and tool-suppression lines, personas, pinned `effort`, bodies past 5k tokens). Default dir is `./skills` or the repo's `skills/`.

In Claude Code, also run `claude -p "/skill-doctor"` for real usage: each skill's listing cost, use count and last use. Usage tells you which descriptions earn their recurring cost and which skills overlap in practice — a size count can't.

## Step 2 — Deep-read (keep it token-disciplined)

Reading every body into this context defeats the purpose, so delegate the deep read to a read-only subagent with the skill list and the rubric's checklist, asking for a prioritized table: `Skill | lines | finding type (placement/fit/size) | top issue | specific fix | est. lines saved | risk (low/med/high)`. It returns conclusions, not file dumps; pull a body into your own context only when you're about to edit it.

Have it check every skill, not only the script's flags:
1. **Placement** first — a skill that should be a hook, path-scoped rule or subagent is a bigger win than any trim, and trimming it would be wasted work.
2. **Fit** — the rubric's Over-constraint table and Frontmatter portability section. The script's counts only point at lines to read; an absolute that guards a secret or a destructive step is correct.
3. **Size** — what to externalise.

## Step 3 — Report

Lead with **placement** findings (what the skill would become, and how invoking `/<name>` would look afterwards), then **fit**, then the **size** table sorted by estimated savings. Separate **low-risk** (static templates, sample outputs, duplicated rules, obsolete scaffolding) from **med/high-risk** (load-bearing format contracts, prose→script rewrites, loosening a rule the output depends on). Name skills that are already lean so they don't get churned.

## Step 4 — Apply (with `--apply` or an explicit go-ahead)

Placement changes — converting or deleting a skill — need the user's explicit go-ahead even under `--apply`.

- **Size:** create `references/<name>.md` (with a `## Contents` TOC if >100 lines), move the bulk there verbatim, and leave a one-line "Read references/<name>.md now" pointer at the step that needs it. The existing symlink already exposes the new file. Externalise load-bearing detail rather than deleting it.
- **Fit:** delete duplicates and obsolete scaffolding; rewrite judgment-call absolutes as decision rules with reasons; keep invariants, product requirements and parsing contracts.

Re-run Step 1 afterwards to confirm the body shrank and nothing exceeds the ceiling. Leave commits, pushes and PRs to the user unless they ask for them.
