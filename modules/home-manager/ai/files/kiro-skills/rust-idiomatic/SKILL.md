---
name: rust-idiomatic
description: Write idiomatic Rust when porting from C or reviewing Rust code. Covers newtypes, methods over functions, enums over booleans, iterator patterns, and the two-layer approach (C-compatible public API wrapping idiomatic internals).
---

## Core Principle

The C code is a spec, not a template. Understand what it does (behavior) and why (intent), then implement idiomatically in Rust.

## Two-Layer Approach

1. **Public API Layer** — matches C signatures, uses flags, preserves parameter order
2. **Internal Implementation Layer** — methods on types, newtypes, enums, iterators, full Rust idioms

## Key Patterns

- **Put logic where the data lives** — if a struct has the info, make it a method
- **Newtypes for domain concepts** — `PageNo(u32)` not bare `u32` (except FFI/shared-memory/on-disk)
- **Enums over boolean flags** — `DirtyFlag::Dirty` not `true`
- **Methods over standalone functions** — `dbmf.get(pgno)` not `memp_fget(dbmf, pgno)`
- **Iterators freely** — doesn't affect API compatibility
- **`?` operator freely** — internal implementation detail

## When to Stay Close to C

- Public API functions (match C signatures)
- `#[repr(C)]` shared memory structures (exact layout)
- On-disk formats (binary compatibility)
- File format structures

## Checklist

Before writing code, ask: Is this public API? → match C. Is this shared memory/on-disk? → `#[repr(C)]`. Is this internal? → full idiomatic Rust.

See `references/full-guide.md` for detailed examples and Berkeley DB caveats.
