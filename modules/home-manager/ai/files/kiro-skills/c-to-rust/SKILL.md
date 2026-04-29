---
name: c-to-rust
description: Port C code to Rust faithfully. Covers pointer-to-reference conversion, macro-to-function translation, error handling patterns, memory management, and verification checklist.
---

## Core Principles

1. **Understand C first** — read and understand completely
2. **Port logic, not syntax** — translate intent, not line-by-line
3. **Use Rust idioms** — don't write C in Rust
4. **Maintain semantics** — same behavior, same edge cases
5. **Test everything** — every function needs a test

## Common Translations

| C Pattern | Rust Pattern |
|-----------|-------------|
| `void func(DB *dbp, PAGE *p)` | `fn func(db: &Db, page: &mut [u8])` |
| `#define DUP_SIZE(len) ((len) + 2 * sizeof(db_indx_t))` | `const fn dup_size(len: usize) -> usize` |
| `if ((ret = func()) != 0) return ret;` | `func()?;` |
| `void *buf = malloc(size); ... free(buf);` | `let buf = vec![0u8; size];` |

## Anti-Patterns

- ❌ `unsafe` everywhere — use only when necessary
- ❌ Raw pointers when references work
- ❌ Manual memory management
- ❌ Ignoring borrow checker — fix the design

## Verification Checklist

- [ ] Same inputs → same outputs
- [ ] Same edge cases handled
- [ ] Same error conditions
- [ ] Same performance characteristics
- [ ] Byte-by-byte file compatibility (if applicable)
