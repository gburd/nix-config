---
name: rust-testing
description: Write and organize Rust tests. Covers unit tests, integration tests, doctests, property-based testing (proptest), benchmarks (criterion), mocking (mockall), fuzzing, and snapshot testing.
---

## Unit Tests

`#[cfg(test)] mod tests` in same file. Use `assert_eq!`, `assert_ne!`, `assert!` with custom messages. `#[should_panic(expected = "...")]` for panic tests. Return `Result<(), E>` for fallible tests.

## Integration Tests

`tests/` directory. Shared utilities in `tests/common/mod.rs`. Each file is a separate binary.

## Test Organization

Nest modules: `mod addition { ... }` inside `mod tests`. Use `TestContext` structs with `Drop` for setup/teardown.

## Property-Based Testing (proptest)

```rust
proptest! {
    #[test]
    fn roundtrip(a in 0..1000i32) { assert_eq!(decode(encode(a)), a); }
}
```

Custom strategies with `prop_map`. Always use `--release` for proptest runs.

## Benchmarks (Criterion)

```rust
fn bench(c: &mut Criterion) {
    c.bench_function("name", |b| b.iter(|| func(black_box(input))));
}
```

Use `BenchmarkId` for parameterized benchmarks. `iter_batched` for setup-per-iteration.

## Mocking (mockall)

`#[automock]` on traits. `mock.expect_method().with(eq(val)).times(1).returning(|_| ...)`.

## Async Tests

`#[tokio::test]` macro. Use `tokio::time::timeout` for timeout patterns.

## Best Practices

- Test behavior, not implementation
- Test edges and errors, not just happy path
- Mock boundaries (network, filesystem), not logic
- Verify tests catch failures — break code, confirm test fails
- `cargo test -- --nocapture` to see output
- `cargo tarpaulin` or `cargo llvm-cov` for coverage

See `references/full-guide.md` for complete examples.
