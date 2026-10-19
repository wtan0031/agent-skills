# Agent Skills audit rubric — token efficiency and instruction fit

Sources (re-verified 2026-10-10): Anthropic's [Agent Skills best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), [Claude Code skills](https://code.claude.com/docs/en/skills) and the model prompting guides ([Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5), [Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5), [Sonnet 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5), [Fable 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5), [Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1)); the [Agent Skills spec](https://agentskills.io/specification), [best practices](https://agentskills.io/skill-creation/best-practices) and [description guide](https://agentskills.io/skill-creation/optimizing-descriptions); OpenAI's [Build skills](https://learn.chatgpt.com/docs/build-skills) (formerly developers.openai.com/codex/skills), [GPT-5.5 prompt guidance](https://developers.openai.com/api/docs/guides/prompt-guidance?model=gpt-5.5) and [GPT-6 model guide](https://developers.openai.com/api/docs/guides/latest-model). Use as the scoring checklist when auditing a skill.

## Contents
- Progressive-disclosure model (the 3 loading levels)
- Description field rules
- Frontmatter portability
- Body length & structure
- When to split into reference files
- Content-efficiency principles
- Over-constraint — instructions that hold current models back
- Anti-patterns
- Placement — is this a skill at all?
- Measure, don't guess

## Progressive-disclosure model — the core idea
| Level | Content | Loads | Cost |
|-------|---------|-------|------|
| **L1 Metadata** | frontmatter `name` + `description` | always, at startup | ~100 tokens **per skill, every turn** |
| **L2 Instructions** | SKILL.md body | when the skill triggers, then **stays in context for the rest of the session** | should stay under ~5k tokens |
| **L3 Resources** | `references/*.md`, scripts | on demand, only when read/run | ~zero until used |

Optimisation order: **L1 is the recurring tax** (cut it and every turn gets cheaper) → **L2 is the per-activation cost** (push bulk to L3) → **L3 is effectively free** (park detail here).

The L1 listing is capped per host: Claude Code budgets ~1% of the context window and,
on overflow, drops descriptions of the *least-invoked* skills first (names stay, triggers
go); Codex budgets 2% (or 8,000 chars) and shortens descriptions first. So unused skills
also crowd out the triggers of skills that are used.

## Description (L1)
- ≤1024 chars hard limit. For recurring-cost hygiene, aim well under that; flag >~220.
- Third person ("Generates…", not "I/you can…").
- Must state **what it does** AND **when to use it** (trigger words / filenames / intent) — "when to use" belongs here, not in the body, which only loads after triggering.
- Key use case first: hosts shorten listings under load (Claude Code truncates `description` + `when_to_use` at 1,536 chars and can drop descriptions of rarely used skills; Codex shortens descriptions first when its skill list exceeds its budget).
- Where sibling skills overlap, name the boundary ("for features use /backlog") so the right one triggers. Describe user intent, not internal mechanics — the model matches against what the user asked for.
- Heavy or side-effecting skills (write files, open apps, spawn agents): phrase the trigger as an explicit ask ("Use when asked to…"), not a situation the model judges ("after a fix", "when planning work") — hosts auto-invoke on a match.
- Don't over-trim: a description that's too thin stops the skill from triggering — that *costs* tokens (wrong tool, retries). Keep the triggers.

## Frontmatter portability
- The spec's top-level keys are `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. Strict validators (claude.ai upload, the Skills API, `package_skill.py`) reject anything else, so custom catalog fields go under `metadata:` as string values.
- Host extensions are fine where they earn their place: `argument-hint`, `disable-model-invocation`, `effort`, `paths` (auto-activate only on matching files), `context: fork` (run in a subagent), `hooks` (Claude Code); `agents/openai.yaml` (Codex). Codex ignores the Claude Code keys, so never rely on one for safety.
- `effort` *overrides* the session's level and its meaning shifts between models — omit it unless a level was measured to help (e.g. `low` on a pure script wrapper).
- Workflows with side effects that the user triggers deliberately → `disable-model-invocation: true` plus Codex `agents/openai.yaml` → `policy.allow_implicit_invocation: false`. This also drops the description from Claude Code's always-loaded listing.

## Body (L2)
- ≤500 lines hard ceiling. "When approaching this limit, split content into separate files."
- Should read as a high-level guide / orchestration, not a full reference.
- All reference links **one level deep** from SKILL.md (no SKILL→a.md→b.md chains).
- Forward slashes in paths; works cross-platform.
- Put invariants and the most important instructions near the top: after compaction Claude Code re-attaches only the first 5,000 tokens of each invoked skill.
- The body isn't re-read on later turns, so word standing guidance for the whole task ("run the tests after every edit", not "run the tests").
- A rule that must hold every time belongs in a hook (a skill can carry its own in `hooks:` frontmatter), not in prose.

## Split content into L3 when it is…
- Large, tabular, or reference-heavy (schemas, field lists, long rubrics).
- A template / sample output / HTML+CSS block / verbatim file payload.
- Mutually exclusive with other sections (user needs A *or* B, not both).
- Rarely used, or used only at one specific step.

## Content efficiency
- Challenge every sentence: "would the agent get this wrong without it?" If not, cut it. Assume Claude is already smart — don't explain what PDFs are, what "a library" is, etc.
- Keep **gotchas** — concrete, environment-specific corrections ("`/health` returns 200 even when the DB is down; use `/ready`"). They are the highest-value lines in most skills; keep them in SKILL.md, not a reference the agent may not know to open.
- Say *when* to load each reference ("Read `references/api-errors.md` if the API returns non-200"), not a generic "see references/".
- Prefer code + short caption over prose.
- One term per concept (don't alternate "endpoint"/"URL"/"route").
- Deterministic / fragile / repeated procedures → a **script** the skill runs (its output enters context, not its source).
- No time-sensitive phrasing ("before August 2025…"); use a `<details>` "legacy" block instead.
- Reference files >100 lines should open with a `## Contents` TOC.

## Over-constraint — instructions that hold current models back
Current Claude and GPT models follow instructions closely and literally. Scaffolding
written for earlier models now tends to *lower* quality: Anthropic's Fable 5 guide says
skills built for prior models "are often too prescriptive… and can degrade output
quality", and OpenAI's GPT-5.5 prompt guidance reserves ALWAYS/NEVER for true invariants
and asks for outcome, success criteria and output shape over step-by-step process. GPT-6
models are more sensitive to instructions in skill files and can stall on conflicting
ones; the precedence line ("user instructions win over a skill") belongs once in
AGENTS.md/CLAUDE.md, not in every skill. Flag, then fix:

| Pattern | Fix |
| --- | --- |
| ALWAYS / NEVER / MUST / CRITICAL / bold-caps on judgment calls | plain decision rule plus its reason ("do X because Y"); keep absolutes for real invariants — secrets, destructive or external actions, untrusted input, honesty about unknowable data |
| Same rule stated in a step, a persona and a "Hard rules" tail | state it once, where it applies; keep a tail only for cross-cutting invariants |
| Persona trait lists ("you are blunt… you never…") | one role line, or none; move any real rule into the steps |
| Rigid step lists for judgment work | goal, success criteria, constraints, output shape, stop rule; keep exact order only where it is load-bearing (cache-before-web, approve-before-render, backup-before-delete) |
| "Double-check / re-verify your work", "use a subagent to verify", with no concrete check | remove — Opus 5+ already self-verifies; Anthropic measured dropping "verify twice" cut cost per ticket by about a third. Keep checks a script or measurement performs. Exception: in review skills, a fresh-context check of each candidate finding is a precision step (Anthropic's Code Review finds, verifies, then ranks); keep it, ideally for risk-matched Deep reviews |
| "Explain / show / write out your reasoning" in the reply | remove — beyond wasted tokens, Opus 5/5.5, Sonnet 5.5 and Fable 5/5.1 may decline it (`reasoning_extraction` refusal). A short explanation of the answer is fine |
| Blanket "think carefully before answering" lines used in place of effort | consider removing and measure the effect on your own tasks — effort is the control. In Anthropic's chat testing on Opus 5.5, removing such a line made replies start sooner with no clear quality decline. Task-specific care ("weigh the privacy trade-off") is fine |
| Severity filters in review skills ("only report high-severity", "be conservative") | report everything with severity/confidence and filter in a separate pass — current models obey the filter literally and miss real findings. Labels such as Important / Nit / Pre-existing and a nit cap are fine: they rank findings rather than suppress them |
| Anti-formatting bans written for older models ("no bullets / bold / headers") | remove, or say when formatting helps — Fable 5.1 under-formats. Keep format contracts that a parser or paste target needs |
| Blanket narration suppression ("hold all findings for the final response") | remove — Fable 5.1 and Sonnet 5.5 already write fewer updates. Keep cadence guidance the product needs ("one line before the first tool call, a recap at the end"); describing the cadence you want is the recommended lever |
| Search-discouraging lines in freshness-sensitive research ("minimise tool calls", "search only when strictly necessary") where a search tool is available | remove — Sonnet 5.5 then answers from stale training knowledge on facts that change. Keep tool limits that guard cost, privacy or side effects |
| Anti-laziness nudges ("be thorough", "don't skip") and "if in doubt, use tool X" | remove — they cause over-triggering and over-verification |
| The same approval gate repeated | one gate, before the irreversible, external or expensive step |
| In-body "When to use" sections; maintainer notes for skill authors | move to the description / README |
| Pinned `effort` or other model-era tuning | inherit from the session unless measured |

Guard against over-correcting: user product requirements (sizes, counts, formats, languages)
and parsing contracts that scripts consume are not over-constraint — keep them.

## Anti-patterns
- Inline HTML/CSS specs, long templates, or sample outputs living in the body (move to L3).
- "Important Rules" / "Hard Rules" tails that restate guidance already in the steps (dedupe).
- Offering 5 equivalent options ("use pypdf, pdfplumber, PyMuPDF…") — pick one, name the exception.
- Magic numbers without a why-comment.
- Windows-style backslash paths.
- Deeply nested references.

## Placement — is this a skill at all?
The cheapest skill is one that shouldn't exist as a skill. Before scoring a body for
size, check whether the *mechanism* is wrong; moving it out beats any trim.

| Symptom in SKILL.md | Belongs as | Tell |
| --- | --- | --- |
| Body is mostly "always / never / every time" directives | **hook** | no ordered steps; it's a policy, not a procedure |
| One constraint about one file type, padded into steps | **path-scoped rule** | collapses to <5 lines once the padding goes |
| Whole body is "search everywhere for X, report findings" | **subagent** | intermediate reads dwarf the conclusion |
| Facts about the project (layout, build commands) | **CLAUDE.md** | describes what *is*, never what to *do* |

Flag these as `placement` findings, listed above size findings — a skill deleted in
favour of a 10-line hook saves its whole L2 body plus its recurring L1 description
tax, and a hook actually enforces where a skill only suggests.

Two guards against over-firing: a procedure that merely *contains* imperatives is
still a procedure (look for ordered steps and branching, not tone), and a skill the
user invokes by name deliberately is a skill even if a hook could approximate it —
`/name` is a feature, not an accident.

## Measure, don't guess
- **L1 usage:** `/skill-doctor` (Claude Code ≥2.1.252; `claude -p "/skill-doctor"` prints text) lists each skill's listing cost, uses and last use. A never-invoked skill the user only runs by `/name` → `disable-model-invocation: true` (or `skillOverrides: "name-only"` per machine).
- **Frontmatter parse:** `claude plugin validate ~/.claude/skills` (≥2.1.233) finds SKILL.md files whose YAML silently fails.
- **Removing instructions:** compare with/without on ≥3 eval tasks and keep a line only if output is worse without it. Pick the baseline by skill source:
  - plugin skills: `claude plugin eval` runs each prompt with and without the plugin itself (`skillOverrides` doesn't apply to plugin skills);
  - personal and project skills (this repo's): run skill-creator's `evals/evals.json` loop, taking the baseline with the skill set to `"off"` in `skillOverrides`.
- **Triggering:** ~20 realistic queries (8–10 should-trigger, 8–10 near-miss should-not), 3 runs each, 60/40 train/validation split.
- **Review skills:** turn each real miss or wrong finding into an eval case and score every skill change against all of them; measure noise by how authors answered past findings (fixed, wrong, intentional, didn't matter) and fix recurring noise at its source (a reference, `REVIEW.md`, a lint rule).

## Beyond tokens
This rubric scores efficiency only. Security & correctness defects (secrets in
command lines, unvalidated manifest commands, `/tmp` PII, path-resolution bugs,
unquoted YAML) are a separate checklist: `../../new-skill/references/skill-safety-checklist.md`.

## Quick scoring checklist
```
L1  [ ] description ≤1024 chars, third person, what + "Use when…" triggers, key use first
FM  [ ] only spec/host keys at top level; catalog fields under metadata:; no unmeasured effort pin
L2  [ ] body ≤500 lines (≤250 ideal); high-level, not a full reference
    [ ] references one level deep, forward slashes
L3  [ ] templates/HTML/long rubrics/sample outputs externalised
EFF [ ] no explaining-the-obvious; code over prose; one term per concept
    [ ] deterministic procedures are scripts, not prose
    [ ] no duplicate "rules" tail; no time-sensitive phrasing
    [ ] ref files >100 lines have a TOC
FIT [ ] absolutes only on invariants, each with a reason; every rule stated once
    [ ] outcome-first; no forced re-verification, reasoning echo or blanket narration suppression
    [ ] no review severity filters, stale anti-formatting bans, blanket narration suppression, or search-discouraging lines in research
    [ ] invariants near the top; gotchas kept in SKILL.md; each reference says when to load it
USE [ ] /skill-doctor checked; never-invoked, by-name-only skills taken out of the listing
```
