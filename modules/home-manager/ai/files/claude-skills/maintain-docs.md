# Maintain Docs

Audit and update project documentation files (CLAUDE.md, AGENTS.md). Use periodically to keep instruction files in sync with actual project state.

## Workflow

1. Read current CLAUDE.md and AGENTS.md for this project
2. Check actual project state:
   - `cat Cargo.toml` (or Makefile, package.json) for build config
   - `ls src/` for directory structure
   - `cargo test 2>&1 | tail -5` for test status
   - `git -P log --oneline -5` for recent changes
3. Compare documented state vs actual state
4. Report:
   - **Stale entries** — documented commands that no longer work
   - **Missing entries** — new crates, features, or patterns not documented
   - **Incorrect architecture** — structural changes not reflected
5. Suggest specific updates (show the diff)

## What to Check

- Build commands still work as documented
- Test commands still work
- Directory structure matches what's described
- Architecture description reflects current code
- Feature flags are up to date
- Known issues are still relevant (or resolved)
