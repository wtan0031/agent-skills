# Why an item is blocked on the human — taxonomy & priority

Two jobs: decide whether an item genuinely needs the user, and rank what's left.

## Contents
- [The seven legitimate reasons](#the-seven-legitimate-reasons)
- [Not a real reason](#not-a-real-reason)
- [Priority ranking](#priority-ranking)

## The seven legitimate reasons

Every blocked item must name exactly one. If none fits, it isn't blocked — it
belongs on the agent list. Use the tag verbatim so the lists stay scannable.

| Tag | Means | Typical item |
| --- | --- | --- |
| `access` | Needs credentials, SSO, 2FA, a paid seat, or an account the agent has no session for | Sign in to the staging console and check the webhook fired |
| `decision` | A product/business judgement with no objectively right answer | Pick between two onboarding flows; decide if this ships behind a flag |
| `device` | Needs real hardware, a physical sensor, or a store/OS surface | Test on a real iPhone; verify camera permissions; check the widget on a locked screen |
| `external` | Waiting on another person or organisation | Vendor's API key; teammate's review; App Store approval |
| `irreversible` | Real-world consequence the agent must not risk unsupervised | Prod deploy, DNS change, payment capture, data deletion, sending email to real users |
| `taste` | Subjective quality only a human can grade | Does the animation feel smooth; is this copy on-brand |
| `knowledge` | Information that exists only in the user's head or private channels | What the client actually asked for; which pricing tier we're on |

## Not a real reason

Do **not** file these as blocked — they are the agent's job, and mislabelling
them is how the list becomes noise the user learns to ignore:

- "It's complicated / large / touches many files." Effort is not a blocker.
- "I'd want you to review it first." Review happens at PR time, not as a todo.
- "I'm not sure which approach is better" **when one is objectively better** —
  do the analysis, recommend, and put it on the agent list. Only a genuine
  values trade-off is a `decision`.
- "Tests might fail." Run them.
- "The credential might be wrong." Try it; escalate only on actual failure.

When tempted to file one of these, write the agent item instead and note the
open question inside it.

## Priority ranking

Rank both lists with the same scale, most urgent first. Rank across the whole
repo, not within categories.

- **P1** — blocks other work, or something user-facing is broken right now.
  If a P1 blocked item is unblocked, agent items usually free up behind it;
  say which ones in the item's "unblocks" line.
- **P2** — real work with no one waiting on it. The default.
- **P3** — worth doing, safe to leave. Cleanups, nice-to-haves, deferred polish.

Tie-breakers, in order: (1) unblocks the most other items, (2) smallest effort,
(3) oldest. Never let a list have more than ~3 P1s — if everything is urgent,
re-rank, because a list where everything is P1 conveys nothing.
