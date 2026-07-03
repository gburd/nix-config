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

Describe what the code does now, not discarded approaches or prior iterations.
See opinions.md for prose/language preferences (plain factual language, no
em-dashes, avoid the inflated register).

## Release Tagging

See the **release-tagging** skill for the date-based tag conventions
(vYYYY.MM.DD, commit→push→tag→push-tag, dual-remote, maintainer exceptions).
Load it when actually cutting a release.

## Lessons: Nix-managed AI Agent Configs

See the **nix-agent-configs** skill (telemetry-off, Bedrock auth paths,
AWS_PROFILE gotcha, pipx patching, this repo's CI expectations). Load it when
editing `modules/home-manager/ai/` or debugging agent auth/model routing.

## Cross-Tool Compatibility

These standards apply equally in Claude Code, Kiro CLI, Pi, and Maki. See AGENTS.md in project roots for project-specific context. All tools share the same coding standards, Rust conventions, and workflow expectations.

## Verification

After any code change, run the project's build or compile step. If the build doesn't run tests automatically, run relevant tests separately. Fix errors before presenting results.

## Sub-Agent Teams

See the **subagent-teams** skill (worker→reviewer→re-reviewer pattern +
Bedrock model-dispatch rules). Load it when spawning/dispatching sub-agents or
debugging a sub-agent that dies instantly.

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
