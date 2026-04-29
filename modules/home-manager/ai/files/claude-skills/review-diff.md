# Review Diff

Review a git diff produced by another agent or developer. Check for regressions, style violations, unnecessary complexity, missed edge cases, and security issues.

## Workflow

1. Identify the branch/range to review:
   ```bash
   git -P log --oneline main..HEAD
   git -P diff --stat main..HEAD
   ```

2. Review each changed file:
   ```bash
   git -P diff main..HEAD -- <file>
   ```

3. For each file, check:
   - **Correctness** — Does the change do what it claims? Edge cases handled?
   - **Regressions** — Could this break existing behavior?
   - **Style** — Follows project conventions? (see CLAUDE.md / AGENTS.md)
   - **Complexity** — Is this the simplest approach? Over-engineered?
   - **Security** — Input validation? Error handling? No secrets committed?
   - **Tests** — Are new behaviors tested? Do existing tests still pass?

4. Run tests to verify:
   ```bash
   cargo test  # or project-specific test command from AGENTS.md
   cargo clippy --all-targets --all-features -- -D warnings
   ```

5. Report findings with file:line references and severity (blocker/warning/nit).

## Cross-Tool Usage

This skill is designed for cross-monitoring between Claude Code and Kiro CLI:
- Claude makes changes → commit → switch to Kiro → `/review-diff`
- Kiro makes changes → commit → switch to Claude → "review the diff on this branch"
