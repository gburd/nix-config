---
name: rust-async
description: Write async Rust with tokio. Covers async/await, spawning tasks, select!, channels (mpsc/oneshot/broadcast/watch), shared state (Arc+Mutex), streams, and graceful shutdown.
---

## Basics

`async fn` returns a Future. `.await` to resolve. `#[tokio::main]` for entry point. `#[tokio::test]` for tests.

## Concurrency

- **Sequential:** `let a = op1().await; let b = op2().await;`
- **Concurrent:** `let (a, b) = tokio::join!(op1(), op2());`
- **Fallible:** `tokio::try_join!()` — stops on first error
- **Spawned:** `tokio::spawn(async { ... })` — returns `JoinHandle`

## select! — First to Complete

```rust
tokio::select! {
    result = operation() => handle(result),
    _ = tokio::time::sleep(Duration::from_secs(5)) => bail!("timeout"),
}
```

## Channels

| Type | Use Case |
|------|----------|
| `mpsc` | Multiple producers → single consumer |
| `oneshot` | Single value, one-time |
| `broadcast` | Multiple producers → multiple consumers |
| `watch` | Single producer, consumers see latest value |

## Shared State

- `Arc<Mutex<T>>` for exclusive access across tasks
- `Arc<RwLock<T>>` for read-heavy patterns
- Prefer channels over shared state when possible

## Best Practices

- `spawn_blocking` for blocking operations (file I/O, sync code)
- Prefer `tokio::sync` over `std::sync` in async code
- Never hold locks across `.await` points
- Always use `timeout` for external I/O
- Handle `JoinHandle` results (tasks can panic)
- Implement graceful shutdown with `watch` channel + `select!`
