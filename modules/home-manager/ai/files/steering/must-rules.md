# Must Rules — Read First

These are the **non-negotiable** rules every agent must follow. If a request conflicts with one of these, surface the conflict and ask — do not silently bypass.

## Workflow

- **MUST** run lint + tests before committing. For Rust: `cargo clippy -- -D warnings` then `cargo test` (or the project-relevant subset). For Python: `ruff check`. For shell: `shellcheck`. If a project has a `Justfile`/`Makefile` with `pre-commit` / `check` targets, prefer those.
- **MUST** use `trash` (not `rm -rf`) for any directory removal. The user's environment has a `trash` command on PATH; if a script must use `rm`, prefer `rm -ri` (interactive) or skip cleanup.
- **MUST NOT** force-push (`git push --force`, `git push --force-with-lease`, or `git push -f`) to any branch unless the user explicitly authorized this specific push in the current session.
- **MUST NOT** rewrite shared/published history (`git rebase -i`, `git commit --amend`, `git reset --hard origin/...`) on `main` or any branch that exists on `origin`.
- **MUST NOT** push directly to `main`. Use a feature branch + PR. The only exception: tiny fixes to a personal nix-config-style repo where the user has explicitly opted into direct-to-main commits in their CONTRIBUTING/AGENTS.md.

## MCP Routing (Use These Servers, Not Manual Search)

Before reaching for `grep`, `rg`, `find`, or `git log` to answer one of these question types, **MUST** consult the corresponding MCP server first. The MCPs are configured because manual search returns lower-quality results and wastes tokens.

| Question type | Use this MCP first |
|---|---|
| PostgreSQL internals (`why does the buffer manager...`, `where is XLogInsert...`, prior pgsql-hackers discussion) | **postgresq** |
| Library/crate API docs (tokio, serde, etc.) | **context7** |
| GitHub repo operations (PRs, issue search, code search across orgs) | **github** |
| Local git ops on `~/ws/*` projects | **git** |
| Persistent knowledge across sessions | **memory** |
| Multi-step architectural reasoning | **sequential-thinking** |
| Nix / home-manager / Rust / Python official docs | **llms-docs** wrappers |

## Output Discipline

- **MUST NOT** mark something "complete" or "verified" unless you actually ran the verification step. If you can't run it (no shell access, missing tools), say so explicitly.
- **MUST NOT** invent file paths, function names, command flags, or library APIs. If you're not sure, look it up via the appropriate MCP or read the file.
- **MUST NOT** include speculative features or unreached error paths "just in case". Code that isn't exercised by a test is dead code.
- **MUST** prefer explicit code over clever one-liners. The reader is the future-you; clever costs more than it saves.

## Confirmation Friction

The user has explicitly stated, repeatedly, that confirmation prompts on routine tool use are friction. The denylists in your agent config block the destructive ops; everything else proceeds without asking. **Do not insert "Should I do X?" prompts before:**

- Running tests
- Running linters
- Reading or grepping files
- Building (cargo build, nix build, make, etc.)
- Creating or modifying files within the repo working tree
- Committing your work to a feature branch
- Using any MCP server

Do continue to ask before:

- Force-push, hard-reset, or any history-rewriting operation
- Deploying to production or any non-development environment
- Spending money (paid API calls outside Bedrock, cloud resource creation)
- Deleting anything outside `<project>/.local/` or `/tmp/`

## Sub-Agent Coordination

For tasks that span more than ~3 phases or ~500 lines of expected output, **default to a sub-agent team** (worker → reviewer → re-reviewer) rather than tackling solo. The reviewer/re-reviewer pattern catches lead-level errors the worker won't notice. See `workflow.md` § Sub-Agent Teams for the exact pattern and Bedrock model-ID gotchas.

## Session Continuity

When resuming work on a project, check `~/.memelord/` and any project-local `AGENTS.md` / `.memelord/` first to recover prior task phase, design decisions, and known blockers. Do not re-explain to the user state that's already documented.
