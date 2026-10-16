# Workflow

## Before Committing

1. Re-read your changes for unnecessary complexity, redundant code, unclear naming
2. Run relevant tests — not the full suite
3. Run linters and type checker — fix everything before committing

## Commits

- Imperative mood, one logical change per commit. Keep the subject line
  short; see prose-mechanics.md for message shape and register, and the
  domain steering for project-specific formats (PostgreSQL has its own).
- The message must stand alone and carry what the diff cannot: why the
  change is needed, caveats and how they are handled, alternatives
  considered and why they lost, and work deliberately deferred.
- Never amend/rebase commits already pushed to shared branches
- Never push directly to main — use feature branches and PRs
- Never commit secrets, API keys, or credentials
- Stage explicitly by path. `git add -A` / `git add .` sweep in untracked
  junk; see must-rules.md.

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

## Where agent work goes: worktrees, scratch, `.agent`

Agents run in parallel on the same repositories. Each agent works in its
OWN git worktree, so it never edits a checkout another agent (or the user)
is using, and every file it creates lands somewhere predictable and easy
to clean up.

### Git worktrees: `/scratch/<proj>/wt-<purpose>`

**Every git worktree you create goes in `/scratch/<proj>/wt-<purpose>`.
Never create one under `~/ws`.**

- `<proj>` is the repository's path relative to `~/ws`, with each `/`
  replaced by `-`.
- `<purpose>` is a short name for the task (`rxsize`, `fix-in-regex-value`,
  `cv5`). The branch name can differ.

| repository | worktree for task "rxsize" |
|---|---|
| `~/ws/sparsemap` | `/scratch/sparsemap/wt-rxsize` |
| `~/ws/postgres/idxam` | `/scratch/postgres-idxam/wt-rxsize` |
| `~/ws/postgres/orioledb/ext` | `/scratch/postgres-orioledb-ext/wt-rxsize` |

```sh
mkdir -p /scratch/postgres-idxam
git -C ~/ws/postgres/idxam worktree add -b bark-rxsize \
    /scratch/postgres-idxam/wt-rxsize idxam
```

Worktrees under `<project>/.local/worktrees/` follow the old rule and are
legacy. Don't add new ones there. When you next work in one, move it to
`/scratch` (see Gotchas).

### Everything else a task generates

- **Bulky or throwaway output** goes under the same `/scratch/<proj>/`. Never
  put it in `/tmp` or in the repository. That covers probe and bench
  scripts, data directories, logs, build trees and prompts for sub-agents.
  For example: `/scratch/postgres-idxam/scratch-rxsize/`.
- **Small, durable agent notes for one project** go in `<project>/.agent/`:
  a work log, a handoff, a findings file the next agent should read. Keep
  them out of commits unless the project already tracks `.agent/`. Check
  `.gitignore`, and add `.agent/` to `.git/info/exclude` if needed.
- Anything worth keeping beyond the task gets committed, or moved into the
  project's own docs or team directory.

For builds, tests and benchmarks in general, use `/scratch`, not `/tmp`. The
home-manager `console/scratch.nix` mixin already exports `TMPDIR` to a
per-shell `mktemp` dir under `/scratch/<user>/`, so `nix-shell`, `cargo`,
`pnpm` and `pgbench` land there automatically. **Never use `/tmp` (or any
tmpfs) for database or storage tests.** tmpfs is RAM-backed and
size-limited, and its I/O latency matches no real deployment. If you must
put something in `/tmp`, remove it before you finish.

### When the task is done

1. Commit, merge or push the work, or record exactly where it stopped.
2. Copy anything untracked that is worth keeping (notes, evidence) out of
   the worktree.
3. Remove the worktree with `git worktree remove <path>`, then run
   `git worktree prune`.
4. Delete its branch once the branch is merged.

Do not leave a worktree behind "in case". The branch and the commit keep
the work. The `cleanup` skill has the full end-of-task checklist, including
other hosts and EC2.

### Gotchas

- **`git worktree move` from `~/ws` to `/scratch` fails** with "Invalid
  cross-device link", because they are separate btrfs subvolumes. Commit the
  work, `git worktree remove` the old one, then `git worktree add` the
  branch under `/scratch`.
- **Recursive `rm` is blocked by the sandbox, and `gio trash` refuses
  `/tmp`.** To delete a tree you created, use `find <dir> -user "$USER"
  -delete`; add `-mindepth 1` to keep the directory itself. For a worktree,
  use `git worktree remove --force`. Beware `find -type f -delete`: it
  leaves symlinks behind, while `-mindepth 1 -delete` removes them.
- **Remote (EC2) copies of a worktree** go under `~/wt/<purpose>` on that
  host and disappear when the host is terminated. Copy back anything you
  need first.
- **Check before deleting someone else's work.** Several repositories can
  share one `.git`, so `git worktree list` may show other projects' and
  other agents' worktrees. Touch only the ones your task created. Never
  terminate an EC2 instance you did not launch: check its `Name` and
  `Owner` tags.

## Core files

A core file is evidence for one debugging session, not something to keep.
Cores are large (hundreds of MiB each), they accumulate in whatever
directory a crashing test ran in, and nothing cleans them up. One sweep of
floki on 2026-10-15 found 278 stray cores totalling 6.7 GiB, months old, in
`~/ws/osv`, `~/ws/libxtc` and `/scratch`. Not one was open.

- **Delete a core as soon as you are done with it.** Delete it the moment
  you have the backtrace (`gdb -batch -ex bt <binary> <core>`), or once you
  know nobody needs it.
- **Keep a core only while you are actively debugging that crash.** Then put
  it somewhere deliberate: `/scratch/<proj>/cores/` next to a note naming
  the binary and the build it came from. A core without its exact binary
  is useless.
- **Before deleting, check that nothing has it open**
  (`fuser <core>` returns nothing), and that it is yours.
- **Find them by content, not by name.** `core`, `core.<pid>` and
  `<prog>.core` are also ordinary filenames, so confirm each candidate
  with `file`:
  ```sh
  find <dirs> -xdev -type f \( -name core -o -name 'core.[0-9]*' -o -name '*.core' \) \
    -exec sh -c 'file -b "$1" | grep -q "core file" && echo "$1"' _ {} \;
  ```
  Don't delete a source file named `core.c`, a `core/` directory, or
  anything `file` doesn't call a core.
- Where cores land differs by host. Look there after a crash:
  - floki and meh: `core.%p` in the crashing process's current directory.
  - rv: `core` in the current directory.
  - nuc (FreeBSD): `%N.core`.
  - arnold: systemd-coredump writes compressed cores to
    `/var/lib/systemd/coredump/` (root-owned; systemd-tmpfiles ages them
    out). Use `coredumpctl list` and `coredumpctl debug <pid>`.
  - lixr: none by default (`ulimit -c 0`).

## Non-Interactive Tools

Always disable editors and pagers in automated contexts:
- `GIT_EDITOR=true` for git operations that might open an editor
- `--no-pager` or `GIT_PAGER=cat` for git output
- `EDITOR=true VISUAL=true` when spawning tools that might invoke an editor
- Use `| cat` to disable pagers in interactive CLI tools
