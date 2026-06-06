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

## Release Tagging

This repo (and the maintainer's other personal repos) use date-based annotated tags:

- Format: `vYYYY.MM.DD`. For a second+ release on the same day, append `.N`:
  `v2026.05.29`, `v2026.05.29.1`, `v2026.05.29.2`.
- Always **annotated** tags (`git tag -a vYYYY.MM.DD[.N] -m "..."`), never lightweight.
- Tag **after** the fixes are merged to `main`. Order of operations:
  1. merge/fast-forward to `main`, 2. `git push origin main`, 3. create the tag,
  4. `git push origin <tag>`.
- The tag message is a one-line summary of what shipped in that release.
- Pushing a tag triggers the `Build 🏗️ and Publish 📀` workflow (drafts a GitHub
  release, builds any defined ISOs, then un-drafts). Check the run after tagging.
- Note: "never push to main / never force-push" still holds for shared/team repos.
  The direct-to-main + tag flow above is the maintainer's deliberate process for
  these personal single-author repos, and force-pushing a mirror (see below) is a
  maintainer-directed exception — do it only when explicitly asked.

## Lessons: Nix-managed AI Agent Configs

When working on `modules/home-manager/ai/` (Bedrock-backed agents: pi, claude,
maki, hermes, codex; plus kiro-cli):

- **Telemetry ships ON by default.** Disable it declaratively, don't assume:
  kiro-cli (`telemetry.enabled = false` in `~/.kiro/settings/cli.json`),
  Claude Code (`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=true` +
  `DISABLE_TELEMETRY/ERROR_REPORTING/BUG_COMMAND`), pi
  (`enableInstallTelemetry=false` and `PI_TELEMETRY=0`). For tools whose state
  file is mutable, enforce via a `home.activation` `jq` patch (create-if-missing).
- **"Ultra" thinking == pi's `xhigh`** (off/minimal/low/medium/high/xhigh).
  The env-var efforts (`CLAUDE_THINKING_EFFORT`, codex `model_reasoning_effort`,
  hermes `reasoning_effort`) top out at `high` — don't invent higher values.
- **Bedrock auth has two paths.** The bearer token (`AWS_BEARER_TOKEN_BEDROCK`)
  works for `InvokeModel`/Converse and Bedrock's HTTPS endpoint accepts
  `Authorization: Bearer <token>` directly. The Anthropic SDK's `AnthropicBedrock`
  client is **SigV4-only** and fails with "could not resolve credentials from
  session" on a bearer-only host. kiro-cli does **not** use Bedrock at all — it
  authenticates with its own subscription/credits.
- **Verify model reachability before claiming it works.** A direct InvokeModel
  probe (or `curl` to `/model/<id>/invoke`) proving HTTP 200 does not prove a
  given agent's code path works — agents route through different SDKs.
- **Patching pipx/venv tools:** ship an idempotent Python patcher in-repo and run
  it from `home.activation` **after** the pipx install/upgrade (pipx upgrade can
  overwrite the venv). Guard with a sentinel marker, and locate code by parsing
  (e.g. balance parens to find a signature end) rather than matching exact lines,
  so the patch survives upstream version drift. Wrap the agent binary in a
  `writeShellScriptBin` shim that exports the bearer token, mirroring pi/maki.
- **Flakes only see git-tracked files.** A new file referenced by a module won't
  build until `git add`-ed.

## CI Expectations (this repo)

- `deadnix --fail .` and `statix check .` are blocking in the Lint workflow — no
  unused bindings/args (prefix intentionally-unused lambda args with `_`).
  `nixpkgs-fmt --check` is `continue-on-error`, so format your touched files but
  it won't block. Run all three locally before pushing.
- Tag-only workflows must **skip gracefully** when a referenced flake attribute
  doesn't exist (e.g. the ISO build checks `nix eval ...drvPath` first), so a
  missing optional output never fails a release.

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

- Use `<project>/.local/` for project-internal worktrees and ephemeral state
- Use `<project>/.local/worktrees/agent-*` for agent worktree isolation
- Use **`/scratch/<user>/<your-mktemp-dir>`** for builds, tests, benchmarks,
  and any I/O-intensive workload — not `/tmp`. The home-manager
  `console/scratch.nix` mixin already exports `TMPDIR` to a per-shell
  `mktemp` dir under `/scratch/<user>/`, so `nix-shell`, `cargo`, `pnpm`,
  `pgbench`, etc. land there automatically. If you need an explicit
  workspace (e.g. for a long-running benchmark), create your own with
  `mktemp -d /scratch/$USER/<tag>-XXXXXX`.
- **Never use `/tmp` (or any other tmpfs) for database/storage tests** —
  tmpfs is RAM-backed, size-limited, and gives misleading I/O latency
  numbers that won't match production deployment.
- Avoid filling `/tmp`. If you absolutely must put something in `/tmp`,
  clean it up before exiting.

## Cleanup (mandatory, not optional)

Agents and humans alike must leave the host as clean as they found it.
Disk space is finite and `/scratch` is shared.

- **Build/install/benchmark artefacts**: when a task is finished, remove
  build output (`target/`, `build/`, `dist/`, `node_modules/` if not
  needed for repro), benchmark result trees, downloaded test corpora,
  large logs, generated DB clusters (`pg_ctl stop && rm -rf $PGDATA`).
  Use `trash` (or `rm` on individual files; never `rm -rf` arbitrary
  paths).
- **Worktrees**: when finished with a `git worktree`, prune it:
  ```sh
  git worktree remove --force <path>     # then
  git worktree prune
  ```
  Don't leave abandoned `<project>/.local/worktrees/agent-*` lying
  around.
- **`/scratch/$USER/tmp-*` dirs**: shells auto-`rmdir` their own
  empty session dir on exit; anything you wrote into them is yours
  to remove when you're done with it.
- **Long-running data**: if a benchmark needs to keep gigabytes of
  state across runs, put it in a clearly-named directory under
  `/scratch/$USER/<purpose>/` and remove the whole tree when the
  experiment is over.
- **Before declaring "done"**: `du -shx /scratch/$USER ~/.cache ~/.cargo/target ~/ws/<project>/target 2>/dev/null` and reclaim anything you don't need.

## Non-Interactive Tools

Always disable editors and pagers in automated contexts:
- `GIT_EDITOR=true` for git operations that might open an editor
- `--no-pager` or `GIT_PAGER=cat` for git output
- `EDITOR=true VISUAL=true` when spawning tools that might invoke an editor
- Use `| cat` to disable pagers in interactive CLI tools
