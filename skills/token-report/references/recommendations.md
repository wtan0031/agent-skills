# Behavioural recommendations — selection rules

Produce **exactly 5** ranked recommendations from the SIGNALS-JSON the script printed
(`current` metrics + `trends` comparing oldest vs latest snapshot). Sort 🔴 first, then 🟡, then 🟢.
Make each one **specific to the user's numbers** — e.g. "cache efficiency dropped 84% → 67% across
your last 4 runs", never generic advice. If fewer than 2 snapshots exist, base them on `current` alone.

| Condition | Recommendation | Priority |
|-----------|---------------|----------|
| cacheEfficiencyPct < 70 OR cache trend ↘ | Too many short sessions. The prompt cache has a 5-min TTL and only kicks in after ~5 turns. Batch related tasks into one long session instead of opening Claude for each small question. | 🔴 HIGH |
| cacheEfficiencyPct > 85 and stable/↗ | Cache is working well. Protect it: avoid switching projects mid-session and don't clear conversation unnecessarily. | 🟢 LOW |
| claudeMdChars > 15000 OR baseCostTokens trend ↗ | Always-loaded context is growing; every message pays this cost. Audit CLAUDE.md and memory files — move infrequently needed sections to reference docs loaded on demand. | 🔴 HIGH |
| memoryFileCount > 8 OR memoryChars trend ↗ | Memory files load every session. Prune stale entries via /memory — each removed file saves tokens on every future turn. | 🟡 MED |
| outputToInputRatio > 0.5 OR ratio trend ↗ | Lots of output relative to input — likely full-file rewrites. Switch to targeted Edit calls; this alone can halve output tokens on coding tasks. | 🟡 MED |
| avgMsgsPerSession7d trend ↘ | Sessions are getting shorter — work is fragmenting and each new session reloads full context. Aim for 20+ messages by queuing related tasks. | 🟡 MED |
| avgSessionsPerDay7d > 6 | High session count = the fixed context cost is paid many times. Open one session in the morning, keep it open, queue questions. | 🟡 MED |
| daily burn ↗ AND msgs/session ↘ | Worst-case pattern: more sessions + shorter = repeated context overhead with no gain. Prioritise longer, focused sessions with a clear task list. | 🔴 HIGH |
| daily burn →/↘ AND cache ↗ | Usage is healthy and improving. No urgent changes — keep doing what you're doing. | 🟢 LOW |
| Always applicable | For broad codebase searches, use the Explore subagent — it runs in an isolated context and doesn't grow the main conversation window. | 🟢 LOW |

Output format (append after the script's report):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BEHAVIOURAL RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [priority]  [recommendation with the user's actual numbers]
  × 5
```

Then close with a 3-line "why tasks cost what they cost" note: every turn pays the fixed
context (~baseCostTokens from the signals) + conversation history; the cache covers items
already seen at the quoted efficiency; longer sessions amortise the fixed cost.
