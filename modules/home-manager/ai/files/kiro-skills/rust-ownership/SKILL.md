---
name: rust-ownership
description: Ownership, borrowing, and lifetimes in Rust. Covers move semantics, references, lifetime annotations, smart pointers (Box/Rc/Arc/RefCell), interior mutability, Pin, Cow, and RAII patterns.
---

## Ownership Rules

- Each value has one owner. When owner goes out of scope, value is dropped.
- **Move:** `let s2 = s;` — `s` is no longer valid
- **Borrow:** `&s` (immutable) or `&mut s` (mutable, exclusive)
- **Clone:** explicit copy when needed

## Lifetimes

```rust
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str  // returned ref lives as long as inputs
struct Excerpt<'a> { part: &'a str }                  // struct borrows data
```

## Smart Pointers

| Type | Use Case |
|------|----------|
| `Box<T>` | Heap allocation, single owner |
| `Rc<T>` | Reference counting (single-threaded) |
| `Arc<T>` | Atomic reference counting (thread-safe) |
| `RefCell<T>` | Interior mutability (runtime borrow checking) |
| `Cell<T>` | Interior mutability for `Copy` types |

**Combinations:** `Rc<RefCell<T>>` for shared mutable (single-thread), `Arc<Mutex<T>>` for shared mutable (multi-thread).

## Cow (Clone on Write)

`Cow::Borrowed(x)` when no modification needed, `Cow::Owned(x.to_string())` when modification required. Avoids unnecessary allocations.

## Function Parameters

- Prefer `&str` over `&String`
- Prefer `&[T]` over `&Vec<T>`
- Use `impl Into<String>` for owned string parameters

## Best Practices

- Borrow by default, clone only when necessary
- Use RAII (`Drop` trait) for cleanup
- `PhantomData` to constrain variance when needed
- Profile before optimizing ownership patterns
