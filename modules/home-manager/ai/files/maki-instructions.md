# Maki Global Instructions

These instructions apply to all projects. Project-specific context is in AGENTS.md at each project root.

## Coding Standards

- ≤100 lines/function, cyclomatic complexity ≤8
- ≤5 positional params, 100-char line length
- No commented-out code. No speculative features.
- Fix every warning from linters, type checkers, compilers.
- Test behavior, not implementation. Test edges and errors.

## Rust

- `cargo clippy --all-targets --all-features -- -D warnings` before committing
- `thiserror` for libraries, `anyhow` for applications
- `tracing` for logging, not println
- Newtypes over primitives, enums over boolean flags
- `let...else` for early returns

## Git

- Imperative mood, ≤72 char subject, one logical change per commit
- Never force push, never rewrite history, never push to main
- Use `trash` instead of `rm -rf`

## AWS (Isengard)

```bash
ada credentials update --once --account <ACCOUNT_ID> --role <ROLE> --provider conduit --profile <PROFILE>
export AWS_PROFILE=<PROFILE>
aws sts get-caller-identity
```

- Tag all resources: Owner=gregburd, Purpose=<desc>, Expiry=<date>
- Prefer spot instances for testing
- Terminate when done

## Tools

| tool | use |
|------|-----|
| `rg` | fast grep |
| `fd` | fast find |
| `ast-grep` | AST-based code search |
| `trash` | safe delete (never rm -rf) |
| `shellcheck` | shell linter |
