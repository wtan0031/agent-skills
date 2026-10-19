# Output format — the list file and its two item shapes

Write the file exactly in this shape; `todo.py` parses the `### [ ] B1 — title`
headings, so that line's format is a contract (heading level, brackets, the
em-dash separator, and the `B`/`A` + number id).

## Contents
- [File skeleton](#file-skeleton)
- [Blocked-on-you item](#blocked-on-you-item)
- [Agent item](#agent-item)
- [Writing rules](#writing-rules)

## File skeleton

```markdown
# <repo name> — todo

_Updated YYYY-MM-DD · branch <branch> · <n> commits ahead of main · PR #<n> open_

## State of play

<3–6 sentences in plain language: what this repo is, what has actually landed
recently, what is in flight right now, and what the single biggest thing
standing in the way is. Written so it makes sense after four weeks away.>

## Blocked on you (<n>)

<B-items, P1 first. If none: "Nothing blocked on you right now.">

## Agent can do unattended (<n>)

<A-items, P1 first. If none: "No agent-ready work queued.">

## Recently done

<Ticked items, most recent first, one line each. Keep the last ~10, drop older.>
```

## Blocked-on-you item

```markdown
### [ ] B1 — <short imperative title>

**Priority:** P1 · **Reason:** `access` · **Time:** ~10 min

**What's needed:** <one or two sentences, concrete.>

**Why the agent can't do this:** <specific to this item — "the staging console
is behind Okta SSO with a hardware key, so no automated session can reach it".
Never generic. This is the line that justifies the item's existence.>

**Unblocks:** A3, A4 <or "nothing — standalone">

**Steps for you**
1. <one action per step, in order, nothing assumed>
2. …

**How to test**
- **Environment:** <staging / local / prod> — `<url>`
- **Sign in as:** `<account identifier>` — credential in <where it lives>
- **Get the app running:** `<command or app + scheme>`
- **Path to the flow:** <click-by-click from landing to the thing under test>
- **What to do:** <the actual interaction being tested>

**Success looks like**
- <observable, checkable statement — "the row appears with status Paid within 5s">

**Failure looks like**
- <the specific wrong outcomes, including partial ones>
- **If it fails, capture:** <screenshot / console error / network tab entry /
  log line> and paste it back — that's what the agent needs to fix it.
```

## Agent item

```markdown
### [ ] A1 — <short imperative title>

**Priority:** P2 · **Effort:** S · **Blocked by:** none <or "B1">

**What this is:** <plain language, no jargon — written so the user understands
what will change without opening the code. Two or three sentences.>

**Why it matters:** <the consequence of doing it, or of not doing it.>

**What the agent will change:** `<path>`, `<path>` <or "new file: <path>">

**Definition of done:** <checkable — "the lint reports 0 fail and the new test
covers the empty-input case">

**Risk if it goes wrong:** <what could break, and how it would be noticed.
"None — additive" is a valid answer, but say it explicitly.>
```

## Writing rules

- **Effort:** `S` (<30 min) · `M` (a focused session) · `L` (multi-session, and
  a candidate for splitting — if you write `L`, suggest the split).
- Ids are stable across refreshes. Never renumber an open item; a refresh
  reuses the id for the same underlying task, retires ids that are done, and
  allocates new numbers from the highest ever used.
- Never invent a test account, URL, or credential location. If the profile
  doesn't have it, write `<unknown — needed>` and list the gap in Step 5's
  report so the user can fill it in once.
- Every credential reference is a *pointer* (1Password item name, `.env` key),
  never the secret itself. See the skill's Hard rules.
- Plain language over repo jargon in both lists — the user reads these cold,
  weeks later, across several projects.
