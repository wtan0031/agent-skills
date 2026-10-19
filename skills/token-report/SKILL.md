---
name: token-report
description: "Token usage report card — --start baselines a session, --end shows its cost, no args gives a 14-day history with trends. Use when checking what a session or recent work cost."
argument-hint: "[--start | --end | --days=N]"
allowed-tools: Read, Bash
effort: low
metadata:
  category: dev
  cadence: weekly
  when-to-use: "checking what a session cost, or token-usage trends"
---

# Token Report Card

$ARGUMENTS

All computation lives in `report.py` next to this file (installed path:
`~/.claude/skills/token-report/report.py`). It reads `~/.claude/stats-cache.json`,
manages baselines/snapshots in `~/.claude/token-reports/`, and prints a ready-to-show
report. Do not recompute its numbers by hand.

## Mode routing

Map the arguments to one script call (run via Bash, from the current directory — the
history mode measures the *current project's* CLAUDE.md + memory footprint):

| Arguments | Command |
|-----------|---------|
| `--start` | `python3 ~/.claude/skills/token-report/report.py start` |
| `--end` | `python3 ~/.claude/skills/token-report/report.py end` |
| none, or `--days=N` | `python3 ~/.claude/skills/token-report/report.py history [--days=N]` |

## --start / --end

Run the command and show its output verbatim. That's the whole job — stop there.

## Historical report (no args)

1. Run the `history` command. Show everything it printed **except** the trailing
   `SIGNALS-JSON` block verbatim.
2. Read `references/recommendations.md` and use the SIGNALS-JSON values to append the
   5 ranked behavioural recommendations in the format it specifies.

## Notes

- Claude Code stores only daily aggregates, not per-turn counts. For per-task cost,
  run `--start` before and `--end` after the task.
- If the script errors (missing stats-cache, etc.), show its message as-is — don't
  improvise numbers.
