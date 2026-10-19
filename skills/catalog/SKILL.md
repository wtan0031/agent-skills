---
name: catalog
description: "Lists every skill in this repo grouped by category, surfacing rarely used ones; `health` runs the skill lint. Use when unsure which skill does what, or to check skill health."
argument-hint: "[category | \"rare\" | \"health\" | empty for everything]"
allowed-tools: Bash
metadata:
  category: meta
  cadence: weekly
  when-to-use: "when you've forgotten which skill does what, or want to see everything you have before starting work"
---

# Catalog — what skills do I have, and what are they for?

A discovery layer that sits *beside* invocation, never in front of it. Summon it when you've
lost track of your inventory — especially the once-a-month/quarter skills whose names you've
forgotten. It does not change how you fire a skill: `/<name>` still works instantly.

## How it works

`catalog.sh` finds every `SKILL.md` under the repo's `skills/` directory and reads its
frontmatter (`name`, `description`, and the `metadata:` fields `category`, `cadence`,
`when-to-use`). Output is generated live from those files, so it is always correct as the repo
grows — there is no second list to maintain. Category comes from `metadata.category`, else the
skill's parent folder, else "uncategorized".

## Steps

1. Run the bundled `catalog.sh` that sits next to this SKILL.md, passing `$ARGUMENTS` straight
   through (it may be empty, a category name like `dev`, or the literal `rare`). Use the script's
   absolute path — when installed that's:

   ```bash
   bash ~/.claude/skills/catalog/catalog.sh $ARGUMENTS
   ```

   The script self-locates the repo's `skills/` directory (it follows its own install symlink), so
   you don't need to pass any path to it.

2. Show the script's output as-is — it's already grouped and aligned, and reformatting,
   re-sorting or commenting on it makes the listing harder to scan.

3. If the user passed a filter that returned nothing, say so in one line and suggest
   `/catalog` with no args to see everything.

4. If many skills show no `cadence`/`when-to-use`/`category`, you may add one short closing
   line noting those `metadata:` fields enrich the catalog (cadence drives the "rarely used"
   section) — once, not on every run.

## Notes

- This is the in-flow discovery tool; the README's skills table is the overview for readers.
  Prefer this when working.
- The script reads the **repo** (source of truth), reached via this skill's install symlink — so
  it reflects everything you *can* load, not just an arbitrary machine's state.
- Filters: `/catalog` (all), `/catalog <category>` (one group), `/catalog rare` (only the
  monthly/quarterly/rare-cadence skills), `/catalog health` (lint: install drift, dangling
  symlinks, frontmatter completeness, description budget, dead reference paths).
