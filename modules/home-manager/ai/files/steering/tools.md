# CLI Tools

Prefer these over their slower counterparts:

| tool | replaces | usage |
|------|----------|-------|
| `rg` (ripgrep) | grep | `rg "pattern"` — 10x faster regex search |
| `fd` | find | `fd "*.py"` — fast file finder |
| `ast-grep` | — | `ast-grep --pattern '$FUNC($$$)' --lang rust` — AST-based code search |
| `shellcheck` | — | `shellcheck script.sh` — shell script linter |
| `shfmt` | — | `shfmt -i 2 -w script.sh` — shell formatter |
| `trash` | rm | `trash file` — moves to macOS Trash (recoverable). **Never use `rm -rf`** |

Prefer `ast-grep` over ripgrep when searching for code structure (function calls, class definitions, imports). Use ripgrep for literal strings and log messages.

## Language-Specific

### Rust
- Build & deps: `cargo`
- Lint: `cargo clippy --all-targets --all-features -- -D warnings`
- Format: `cargo fmt`
- Supply chain: `cargo deny check`
- Safety: `cargo careful test`

### Python
- Runtime: 3.13 with `uv venv`
- Deps: `uv`
- Lint & format: `ruff check` · `ruff format`
- Types: `ty check`
- Tests: `pytest -q`

### Bash
- All scripts: `set -euo pipefail`
- Lint: `shellcheck script.sh && shfmt -d script.sh`

### Terraform
- Format: `terraform fmt`
- Validate: `terraform validate`
- Plan before apply: `terraform plan -out=tfplan && terraform apply tfplan`
