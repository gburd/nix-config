---
name: rust-error-handling
description: Handle errors in Rust using Result, Option, thiserror, anyhow, and the ? operator. Covers custom error types, error conversion, combinators, and context patterns.
---

## Quick Reference

- **Libraries:** `thiserror` for structured errors, `#[from]` for auto-conversion
- **Applications:** `anyhow` with `.context("what failed")?`
- **Propagation:** `?` operator, never `.unwrap()` in production
- **Option→Result:** `.ok_or(Error::NotFound)?`

## thiserror (Libraries)

```rust
#[derive(Error, Debug)]
enum DataError {
    #[error("not found: {0}")]
    NotFound(String),
    #[error("IO error")]
    Io(#[from] std::io::Error),
}
```

## anyhow (Applications)

```rust
use anyhow::{Result, Context, bail, ensure};
fn process(path: &str) -> Result<()> {
    let content = std::fs::read_to_string(path).context("failed to read")?;
    ensure!(!content.is_empty(), "file is empty");
    Ok(())
}
```

## Combinators

- `Option`: `.map()`, `.and_then()`, `.unwrap_or()`, `.filter()`
- `Result`: `.map()`, `.map_err()`, `.and_then()`, `.context()`

## Best Practices

- `Result` for recoverable errors, `panic!` only for unrecoverable bugs
- `?` over `.unwrap()` everywhere
- Add context as errors propagate up the stack
- Use `expect("descriptive message")` over bare `unwrap()` in tests only
- Never use `String` as error type — use custom types
