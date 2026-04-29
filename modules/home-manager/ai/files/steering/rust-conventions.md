# Rust Conventions

## Runtime

Latest stable via `rustup`. Build & deps: `cargo`. Always run `cargo clippy --all-targets --all-features -- -D warnings` before committing.

## Style

- Prefer `for` loops with mutable accumulators over iterator chains
- Shadow variables through transformations (no `raw_x`/`parsed_x` prefixes)
- No wildcard matches; avoid `matches!` macro — explicit destructuring catches field changes
- Use `let...else` for early returns; keep happy path unindented

## Type Design

- Newtypes over primitives (`UserId(u64)` not `u64`)
- Enums for state machines, not boolean flags
- `thiserror` for libraries, `anyhow` for applications
- `tracing` for logging (`error!`/`warn!`/`info!`/`debug!`), not println

## Optimization

- Write efficient code by default — correct algorithm, appropriate data structures, no unnecessary allocations
- Profile before micro-optimizing; measure after

## Cargo.toml Lints

```toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
panic_in_result_fn = "deny"
unimplemented = "deny"
allow_attributes = "deny"
dbg_macro = "deny"
todo = "deny"
print_stdout = "deny"
print_stderr = "deny"
await_holding_lock = "deny"
large_futures = "deny"
exit = "deny"
mem_forget = "deny"
module_name_repetitions = "allow"
similar_names = "allow"
```

## Supply Chain

`cargo deny check` (advisories, licenses, bans). `cargo careful test` for stdlib debug assertions + UB checks.
