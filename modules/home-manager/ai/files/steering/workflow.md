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
- Use `trash` instead of `rm -rf` — never use destructive deletes

## Pull Requests

Describe what the code does now — not discarded approaches or prior iterations. Use plain, factual language. Avoid: critical, crucial, essential, significant, comprehensive, robust, elegant.

## Cross-Tool Compatibility

These standards apply equally in Claude Code and Kiro CLI. See AGENTS.md in project roots for project-specific context. Both tools share the same coding standards, Rust conventions, and workflow expectations.

## Verification

After any code change, run the project's build or compile step. If the build doesn't run tests automatically, run relevant tests separately. Fix errors before presenting results.
