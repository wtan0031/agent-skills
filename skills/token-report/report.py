#!/usr/bin/env python3
"""token-report compute engine.

Subcommands:
  start                 snapshot all-time totals as a session baseline
  end                   diff current totals against the baseline -> session report
  history [--days=N] [--no-save]
                        full historical report + trend signals; saves a dated snapshot

All mechanical work (JSON reading, deltas, trends, formatting) happens here so the
model only narrates and writes recommendations. Prints ready-to-show text; `history`
also prints a SIGNALS-JSON block for the recommendation step.
"""
import json
import os
import sys
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
STATS = os.path.join(HOME, ".claude", "stats-cache.json")
REPORTS_DIR = os.path.join(HOME, ".claude", "token-reports")
BASELINE = os.path.join(REPORTS_DIR, "session-start.json")
TOKEN_FIELDS = ("inputTokens", "outputTokens", "cacheReadInputTokens", "cacheCreationInputTokens")
BAR = "━" * 48
RULE = "─" * 48


def fmt(n):
    n = int(n)
    if abs(n) >= 1_000_000:
        return f"{n / 1_000_000:.1f}m"
    return f"{n:,}"


def load_stats():
    try:
        with open(STATS) as f:
            return json.load(f)
    except OSError:
        sys.exit(f"Cannot read {STATS} — no usage stats available on this machine.")


def model_totals(stats):
    per_model, grand = {}, {k: 0 for k in TOKEN_FIELDS}
    for model, usage in stats.get("modelUsage", {}).items():
        per_model[model] = {k: int(usage.get(k, 0)) for k in TOKEN_FIELDS}
        for k in TOKEN_FIELDS:
            grand[k] += per_model[model][k]
    return per_model, grand


def cache_eff(inp, reads):
    return None if inp + reads == 0 else reads / (inp + reads) * 100


def eff_label(pct):
    if pct is None:
        return "n/a"
    if pct < 50:
        return f"{pct:.1f}%  🔴 Needs Work"
    if pct <= 80:
        return f"{pct:.1f}%  🟡 Good"
    return f"{pct:.1f}%  🟢 Excellent"


def cmd_start():
    per_model, grand = model_totals(load_stats())
    now = datetime.now(timezone.utc)
    os.makedirs(REPORTS_DIR, exist_ok=True)
    with open(BASELINE, "w") as f:
        json.dump({
            "timestamp": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "date": now.strftime("%Y-%m-%d"),
            "time": now.strftime("%H:%M"),
            "modelTotals": per_model,
            "grandTotals": grand,
        }, f, indent=2)
    print(f"  Session baseline saved at {now.strftime('%H:%M')} on {now.strftime('%Y-%m-%d')} (UTC).")
    print(f"  All-time totals at start: {fmt(grand['outputTokens'])} output tokens · "
          f"{fmt(grand['cacheReadInputTokens'])} cache reads.")
    print("  Run /token-report --end to see what this session cost.")


def cmd_end():
    if not os.path.exists(BASELINE):
        print("  No session baseline found. Run /token-report --start at the beginning of a session first.")
        return
    with open(BASELINE) as f:
        base = json.load(f)
    per_model, _ = model_totals(load_stats())

    deltas, grand = {}, {k: 0 for k in TOKEN_FIELDS}
    for model, cur in per_model.items():
        ref = base.get("modelTotals", {}).get(model, {k: 0 for k in TOKEN_FIELDS})
        d = {k: cur[k] - int(ref.get(k, 0)) for k in TOKEN_FIELDS}
        if any(d.values()):
            deltas[model] = d
            for k in TOKEN_FIELDS:
                grand[k] += d[k]

    eff = cache_eff(grand["inputTokens"], grand["cacheReadInputTokens"])
    ratio = grand["outputTokens"] / grand["inputTokens"] if grand["inputTokens"] else None
    dominant = max(deltas, key=lambda m: deltas[m]["outputTokens"] + deltas[m]["cacheReadInputTokens"]) if deltas else "n/a"

    started = datetime.strptime(base["timestamp"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    mins = int((datetime.now(timezone.utc) - started).total_seconds() // 60)
    duration = f"{mins // 60}h {mins % 60}m" if mins >= 60 else f"{mins}m"

    print(BAR)
    print(f"  SESSION COST REPORT  ·  {datetime.now(timezone.utc).strftime('%Y-%m-%d')}")
    print(BAR)
    print(f"\n  Session started:   {base['time']} UTC  ({duration} ago)")
    print(f"  Dominant model:    {dominant}\n")
    print("  TOKENS THIS SESSION")
    print(f"  {RULE}")
    print(f"  Output generated   {fmt(grand['outputTokens'])} tokens")
    print(f"  Fresh input        {fmt(grand['inputTokens'])} tokens")
    print(f"  Cache reads        {fmt(grand['cacheReadInputTokens'])} tokens")
    print(f"  Cache created      {fmt(grand['cacheCreationInputTokens'])} tokens")
    print(f"  {RULE}")
    print(f"  Cache efficiency   {eff_label(eff)}")
    print(f"  Output/input ratio {f'{ratio:.2f}×' if ratio is not None else 'n/a'}\n")
    print("  Per-model breakdown:")
    for m, d in sorted(deltas.items(), key=lambda kv: -kv[1]["outputTokens"]):
        print(f"    {m}  out:{fmt(d['outputTokens'])}  cache-reads:{fmt(d['cacheReadInputTokens'])}  "
              f"fresh-in:{fmt(d['inputTokens'])}")
    print("\n  COST NOTES")
    print(f"  {RULE}")
    notes = []
    if eff is not None and eff < 50:
        notes.append("  ⚠ Low cache hit rate — many short bursts or context resets.\n"
                     "    Try to stay in one long session.")
    if ratio is not None and ratio > 5:
        notes.append(f"  ⚠ High output ratio ({ratio:.2f}×) — consider Edit tool calls\n"
                     "    instead of full-file rewrites.")
    if eff is not None and eff >= 80:
        notes.append("  ✓ Cache efficiency was strong this session.")
    if not notes:
        notes.append("  ✓ Session looked healthy — no obvious inefficiencies.")
    print("\n".join(notes))
    print(BAR)


def context_footprint():
    claude_md = 0
    try:
        claude_md = os.path.getsize(os.path.join(os.getcwd(), "CLAUDE.md"))
    except OSError:
        pass
    project_key = "".join(c if c.isalnum() else "-" for c in os.getcwd())
    mem_dir = os.path.join(HOME, ".claude", "projects", project_key, "memory")
    mem_chars = mem_count = 0
    if os.path.isdir(mem_dir):
        for name in os.listdir(mem_dir):
            if name.endswith(".md"):
                mem_count += 1
                mem_chars += os.path.getsize(os.path.join(mem_dir, name))
    return claude_md, mem_chars, mem_count


def trend(old, new, tol=0.03):
    if old is None or new is None:
        return "→"
    if old == 0:
        return "↗" if new > 0 else "→"
    change = (new - old) / abs(old)
    return "↗" if change > tol else ("↘" if change < -tol else "→")


def cmd_history(days, save=True):
    stats = load_stats()
    per_model, grand = model_totals(stats)
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    claude_md, mem_chars, mem_count = context_footprint()
    base_cost = (claude_md + mem_chars) // 4

    eff = cache_eff(grand["inputTokens"], grand["cacheReadInputTokens"])
    ratio = grand["outputTokens"] / grand["inputTokens"] if grand["inputTokens"] else 0.0

    activity = {d["date"]: d for d in stats.get("dailyActivity", [])}
    daily = []
    for row in stats.get("dailyModelTokens", []):
        by_model = row.get("tokensByModel", {})
        act = activity.get(row["date"], {})
        daily.append({
            "date": row["date"],
            "tokens": sum(by_model.values()),
            "sessions": act.get("sessionCount", 0),
            "messages": act.get("messageCount", 0),
            "dominant": max(by_model, key=by_model.get) if by_model else "n/a",
        })
    daily.sort(key=lambda d: d["date"], reverse=True)
    window = daily[:days]
    last7 = daily[:7]
    avg7 = sum(d["tokens"] for d in last7) / len(last7) if last7 else 0
    sess7 = sum(d["sessions"] for d in last7)
    msgs7 = sum(d["messages"] for d in last7)
    avg_sessions = sess7 / len(last7) if last7 else 0
    avg_msgs = msgs7 / sess7 if sess7 else 0
    peak = max(window, key=lambda d: d["tokens"])["date"] if window else None
    top3 = sorted(window, key=lambda d: -d["tokens"])[:3]

    snapshots = []
    if os.path.isdir(REPORTS_DIR):
        names = sorted(n for n in os.listdir(REPORTS_DIR)
                       if n.endswith(".json") and n != "session-start.json" and n != f"{today}.json")
        for name in names[-7:]:
            try:
                with open(os.path.join(REPORTS_DIR, name)) as f:
                    snapshots.append(json.load(f))
            except (OSError, ValueError):
                pass

    print(BAR)
    print(f"  TOKEN REPORT CARD  ·  {today}")
    print(BAR)
    print("\n  CONTEXT OVERHEAD  (every session, before you type)")
    print(f"  {RULE}")
    print(f"  CLAUDE.md          {claude_md:,} chars  ≈  {fmt(claude_md // 4)} tokens")
    print(f"  Memory files ({mem_count})   {mem_chars:,} chars  ≈  {fmt(mem_chars // 4)} tokens")
    print(f"  {RULE}")
    print(f"  Base cost/session               ≈  {fmt(base_cost)} tokens\n")
    print("  CACHE EFFICIENCY  (all time)")
    print(f"  {RULE}")
    print(f"  Cache reads    {fmt(grand['cacheReadInputTokens'])} tokens")
    print(f"  Raw input      {fmt(grand['inputTokens'])} tokens")
    print(f"  Overall        {eff_label(eff)}\n")
    print("  Per-model breakdown:")
    for m, u in sorted(per_model.items(), key=lambda kv: -kv[1]["outputTokens"]):
        e = cache_eff(u["inputTokens"], u["cacheReadInputTokens"])
        print(f"    {m}  {f'{e:.1f}%' if e is not None else 'n/a'}  |  in:{fmt(u['inputTokens'])} "
              f"out:{fmt(u['outputTokens'])} cached:{fmt(u['cacheReadInputTokens'])}")
    print(f"\n  {len(window)}-DAY USAGE TREND  (data from {stats.get('lastComputedDate', '?')})")
    print(f"  {RULE}")
    print("  Date          Total Tokens   Sessions  Messages")
    for d in window:
        mark = "   ← peak" if d["date"] == peak else ""
        print(f"  {d['date']}   {fmt(d['tokens']):>11}      {d['sessions']:>3}      {d['messages']:>4}{mark}")
    print(f"  7-day avg     {fmt(avg7):>11}\n")
    print("  BEHAVIOUR METRICS  (last 7 days)")
    print(f"  {RULE}")
    print(f"  Avg sessions/day      {avg_sessions:.1f}")
    print(f"  Avg messages/session  {avg_msgs:.1f}")
    print(f"  Output-to-input ratio {ratio:.2f}×\n")
    print("  TOP 3 MOST EXPENSIVE DAYS")
    print(f"  {RULE}")
    for i, d in enumerate(top3, 1):
        print(f"  {i}. {d['date']}  —  {fmt(d['tokens'])} tokens  (dominant: {d['dominant']})")

    print(f"\n{BAR}")
    print(f"  7-RUN TREND COMPARISON  ({len(snapshots)} snapshots available)")
    print(BAR)
    signals = {}
    if snapshots:
        oldest, latest = snapshots[0], snapshots[-1]
        eff_avg = sum(s.get("cacheEfficiencyPct", 0) for s in snapshots) / len(snapshots)
        rows = [
            ("Cache efficiency", "cacheEfficiencyPct", lambda v: f"{v:.1f}%"),
            ("Base cost/session", "baseCostTokens", lambda v: fmt(v)),
            ("Daily token burn (7d)", "avgDailyTokens7d", lambda v: fmt(v)),
            ("Msgs/session", "avgMsgsPerSession7d", lambda v: f"{v:.1f}"),
            ("Output-to-input ratio", "outputToInputRatio", lambda v: f"{v:.2f}×"),
            ("Memory files", "memoryFileCount", lambda v: str(int(v))),
        ]
        print("\n  Metric                  Oldest     Latest     Trend")
        print(f"  {RULE}──")
        for label, key, f in rows:
            o, l = oldest.get(key), latest.get(key)
            arrow = trend(o, l)
            print(f"  {label:<22}  {f(o) if o is not None else 'n/a':>8}   {f(l) if l is not None else 'n/a':>8}      {arrow}")
            signals[key] = {"oldest": o, "latest": l, "trend": arrow}
        signals["cacheEffRecentVs7RunAvg"] = {"recent": latest.get("cacheEfficiencyPct"), "avg": round(eff_avg, 1)}
    else:
        print("\n  (First run — no history to compare against yet.)")

    snapshot = {
        "date": today,
        "claudeMdChars": claude_md,
        "memoryChars": mem_chars,
        "memoryFileCount": mem_count,
        "baseCostTokens": base_cost,
        "cacheEfficiencyPct": round(eff or 0, 1),
        "totalInputTokens": grand["inputTokens"],
        "totalOutputTokens": grand["outputTokens"],
        "totalCacheReads": grand["cacheReadInputTokens"],
        "totalCacheCreations": grand["cacheCreationInputTokens"],
        "avgDailyTokens7d": int(avg7),
        "avgSessionsPerDay7d": round(avg_sessions, 1),
        "avgMsgsPerSession7d": round(avg_msgs, 1),
        "outputToInputRatio": round(ratio, 2),
    }
    if save:
        os.makedirs(REPORTS_DIR, exist_ok=True)
        with open(os.path.join(REPORTS_DIR, f"{today}.json"), "w") as f:
            json.dump(snapshot, f, indent=2)
        print(f"\n  Snapshot saved → ~/.claude/token-reports/{today}.json")

    print("\nSIGNALS-JSON (for the recommendations step — do not show to the user):")
    print(json.dumps({"current": snapshot, "trends": signals, "snapshotCount": len(snapshots)}))


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit("usage: report.py start | end | history [--days=N] [--no-save]")
    cmd = args[0]
    if cmd == "start":
        cmd_start()
    elif cmd == "end":
        cmd_end()
    elif cmd == "history":
        days = 14
        for a in args[1:]:
            if a.startswith("--days="):
                days = max(1, int(a.split("=", 1)[1]))
        cmd_history(days, save="--no-save" not in args)
    else:
        sys.exit(f"unknown subcommand: {cmd}")


if __name__ == "__main__":
    main()
