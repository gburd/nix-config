# Watchdog

Comprehensive health check for a project. Run periodically to catch drift, regressions, and quality issues. Use as a cross-tool monitoring checkpoint.

## Checks

1. **Build** — Does it compile cleanly?
   ```bash
   cargo build 2>&1 | tail -5
   ```

2. **Tests** — Do all tests pass?
   ```bash
   cargo test 2>&1 | tail -20
   ```

3. **Lint** — Zero warnings?
   ```bash
   cargo clippy --all-targets --all-features -- -D warnings 2>&1 | tail -10
   ```

4. **Format** — Properly formatted?
   ```bash
   cargo fmt -- --check
   ```

5. **Unintended changes** — Any unexpected modified files?
   ```bash
   git status --short
   ```

6. **Architecture** — Check AGENTS.md constraints are maintained. Read the project's AGENTS.md and verify the described architecture still holds.

## Report Format

```
## Watchdog Report — <project> — <date>
- Build: ✅/❌
- Tests: ✅/❌ (N passed, M failed)
- Lint: ✅/❌ (N warnings)
- Format: ✅/❌
- Uncommitted changes: <list>
- Architecture concerns: <any drift from AGENTS.md>
```
