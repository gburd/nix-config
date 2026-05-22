# Workflow

## Before Committing

1. Re-read your changes for unnecessary complexity, redundant code, unclear naming
2. Run relevant tests — not the full suite
3. Run linters and type checker — fix everything before committing

## Commits

- Imperative mood, ≤72 char subject line, one logical change per commit
- Never amend/rebase commits already pushed to shared branches
- Never push directly to main — use feature branches and PRs
- Never commit secrets, API keys, or credentials

## Git Safety

- Never delete `.git` directories or rewrite history
- Never force push (`git push --force`)
- Never amend commits that have already been created
- Use `-P` flag on git commands that produce paginated output
- Use `GIT_EDITOR=true` for non-interactive rebase continuations
- Use `trash` instead of `rm -rf` — never use destructive deletes

## Pull Requests

Describe what the code does now — not discarded approaches or prior iterations. Use plain, factual language. Avoid: critical, crucial, essential, significant, comprehensive, robust, elegant.

## Cross-Tool Compatibility

These standards apply equally in Claude Code, Kiro CLI, Pi, and Maki. See AGENTS.md in project roots for project-specific context. All tools share the same coding standards, Rust conventions, and workflow expectations.

## Verification

After any code change, run the project's build or compile step. If the build doesn't run tests automatically, run relevant tests separately. Fix errors before presenting results.

## Sub-Agent Teams

Use teams of coordinated sub-agents when possible to parallelize work and avoid single-agent bottlenecks. Follow the three-step verdict pattern:
1. **Worker** agent implements the change
2. **Reviewer** agent analyzes architecture and finds issues
3. **Re-reviewer** verifies the fix — catches lead-level errors

### Sub-Agent Model Selection (Bedrock specifics)

When calling the Agent tool, **omit the `model` parameter unless
you have a specific reason to override it.** Sub-agents that
inherit the parent's model are guaranteed to work because the
parent's invocation already proved the model is dispatchable.

Bedrock model IDs come in two forms:

- **Bare model ID** (`anthropic.claude-haiku-4-5-20251001-v1:0`) —
  requires *provisioned* throughput. On-demand calls fail with
  `Invocation of model ID ... with on-demand throughput isn't
  supported.` The sub-agent dies after ~1 second with no usable
  output; the parent sees only "completed: 0 tool uses".
- **Cross-region inference profile** (`us.anthropic.claude-...`,
  `eu.anthropic.claude-...`, `apac.anthropic.claude-...`) —
  supports on-demand throughput. This is what `enabledModels`
  in `~/.pi/agent/settings.json` should contain.

If you must pass a `model:` parameter explicitly:

- ✅ Use a full inference-profile ID with the `us.` / `eu.` /
  `apac.` prefix.
- ❌ Do **not** use a bare `anthropic.*` model ID.
- ⚠️ Fuzzy names (`sonnet`, `haiku`, `opus`) work *most* of the
  time but the resolver can land on a bare ID. The safety hooks
  in `pi-extensions/safety-hooks.ts` warn on fuzzy names and
  block bare IDs.

**If a sub-agent completes in under 2 seconds with 0 tool uses,
assume it failed at model dispatch.** Verify the model ID, drop
the `model:` override, and re-dispatch.

## Project Layout Conventions

- Use `<project>/.local/` for worktrees, temp artifacts, and ephemeral state
- Use `<project>/.local/worktrees/agent-*` for agent worktree isolation
- Use `<project>/.local/tmp/` for test databases and I/O-intensive workloads
- Never use `/tmp` or other tmpfs for database/storage tests — they are RAM-backed, size-limited, and don't represent real I/O latency
- Avoid filling `/tmp` — clean up anything placed there when finished

## Cleanup

Always clean up intermediate files (build artifacts, test outputs, temp dirs). They accumulate and waste disk. Remove them when no longer needed.

## Non-Interactive Tools

Always disable editors and pagers in automated contexts:
- `GIT_EDITOR=true` for git operations that might open an editor
- `--no-pager` or `GIT_PAGER=cat` for git output
- `EDITOR=true VISUAL=true` when spawning tools that might invoke an editor
- Use `| cat` to disable pagers in interactive CLI tools
