# Runtime delegation

Use the live tool schema and exposed model metadata as the source of truth. These
examples are runtime-specific conveniences, not a portable API contract.
The entrypoint's `allowed-tools` value is a Claude-oriented discovery hint, not a
promise that Codex exposes tools with those names.

## Claude Code

Claude Code's Agent tool supports the model aliases `haiku` (mechanical retrieval),
`sonnet` (bounded implementation), and `opus` (hard reasoning/security);
respect any higher repository routing floor. Its subagent
configuration can also inherit or select models. Follow the schema shown in the
current session. See the official [Claude Code subagents documentation](https://code.claude.com/docs/en/sub-agents).

## Codex

When the current Codex session exposes `collaboration.spawn_agent` with `model`,
`reasoning_effort`, and `fork_turns`, a practical configurable starting point is:

| Work | Model | Effort |
|---|---|---|
| Mechanical search or transformation | `gpt-5.6-luna` | low |
| Bounded coding or documentation | `gpt-5.6-terra` | medium |
| Demanding implementation or reasoning | `gpt-5.6-sol` | high |
| Hardest or security-sensitive work | `gpt-6-astra` | high |

With that schema, use `fork_turns: "none"` when overriding model or effort and
send a self-contained brief. Use exposed follow-up, message, and wait operations
according to their live schemas. Other Codex harnesses may expose different
`spawn_agent` parameters, configured roles, or no per-call model selection; in
those cases use what is available rather than emulating unsupported controls. See
the official [Codex subagents documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents).

Use these model IDs only if the session exposes them, with a supported effort.
Prefer configured task roles when per-call model selection is unavailable; do not
pass a model field to a schema that lacks it. Record a model as requested unless
the runtime confirms which model actually ran. If the runtime reports no usage,
report token/cost usage as unavailable rather than estimating savings.

These defaults are capability heuristics, not measured prices or an equivalence
ranking across providers. Do not call external model APIs or CLIs, incur separate
billing, or mutate configuration merely to obtain a preferred worker.
