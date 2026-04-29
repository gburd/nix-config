---
name: rust-traits
description: Design and implement Rust traits. Covers associated types, generics, trait objects (dyn), derive macros, extension traits, sealed traits, operator overloading, and From/Into conversions.
---

## Trait Design

- **Associated types** when one clear type per implementation
- **Generic parameters** when multiple types might be used simultaneously
- Keep traits small and focused (single responsibility)

## Key Patterns

- **Extension traits** — add methods to existing types: `trait StringExt { fn truncate_to(&self, max: usize) -> String; }`
- **Sealed traits** — prevent external implementation via private supertrait
- **Supertraits** — `trait Loggable: Printable { ... }`
- **Marker traits** — compile-time guarantees (`Send`, `Sync`, custom markers)

## Static vs Dynamic Dispatch

- **Static** (`fn foo<T: Trait>(x: &T)`) — monomorphized, faster, larger binary
- **Dynamic** (`fn foo(x: &dyn Trait)`) — vtable, flexible, smaller binary
- Use `Box<dyn Trait>` for heterogeneous collections

## Derive Macros

Always derive `Debug`. Add `Clone`, `PartialEq`, `Eq`, `Hash` as needed. Use `serde::{Serialize, Deserialize}` for serialization.

## From/Into

Implement `From<T>` (you get `Into` free). Use `TryFrom` for fallible conversions. `impl From<io::Error> for MyError` enables `?` auto-conversion.

## Best Practices

- Implement standard traits (`Debug`, `Clone`, `Display`) for ecosystem integration
- Use `#[derive]` over manual implementations
- Document trait requirements and invariants
