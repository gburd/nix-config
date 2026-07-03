---
name: subagent-teams
description: >
  How to run coordinated sub-agent teams (worker → reviewer → re-reviewer) and
  the Bedrock model-dispatch rules for sub-agents. Use this skill ONLY when
  spawning/dispatching sub-agents (e.g. Pi's Agent tool, parallel task fan-out)
  or debugging a sub-agent that dies instantly. Triggers on: "sub-agent",
  "subagent", "dispatch agents", "parallel agents", "Agent tool", "sub-agent
  finished in <2s / 0 tool uses".
---

# Sub-Agent Teams

Use teams of coordinated sub-agents when possible to parallelize work and avoid
single-agent bottlenecks. Follow the three-step verdict pattern:
1. **Worker** agent implements the change
2. **Reviewer** agent analyzes architecture and finds issues
3. **Re-reviewer** verifies the fix — catches lead-level errors

## Sub-Agent Model Selection (Bedrock specifics)

When calling the Agent tool, **omit the `model` parameter unless you must
override it** — inherited-model sub-agents are guaranteed dispatchable (the
parent already proved it). Bedrock model IDs come in two forms:
- **Bare ID** (`anthropic.claude-...`) needs provisioned throughput; on-demand
  calls fail ("on-demand throughput isn't supported") and the sub-agent dies in
  ~1s with "completed: 0 tool uses".
- **Cross-region inference profile** (`us.`/`eu.`/`apac.` prefix) supports
  on-demand — this is what `enabledModels` in pi's settings should contain.

If you must pass `model:`, use a full `us.`/`eu.`/`apac.` profile ID, never a
bare `anthropic.*`. Fuzzy names (sonnet/haiku/opus) usually work but can resolve
to a bare ID; `pi-extensions/safety-hooks.ts` warns on fuzzy and blocks bare IDs.
**A sub-agent finishing in <2s with 0 tool uses = model-dispatch failure** —
verify the ID, drop the `model:` override, re-dispatch.
