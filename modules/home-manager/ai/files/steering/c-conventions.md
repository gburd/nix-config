# C Conventions

## Build & Tooling

- Prefer whatever build system the project already uses (`make`, `meson`,
  `cmake`, autotools) — don't introduce a second one.
- Compile with `-Wall -Wextra` at minimum; treat new warnings in touched code
  as errors, don't silence with a blanket pragma.
- Find and use the project's own formatter/indent tool if it has one (check
  for a `.clang-format`, a documented custom indent script, or contributor
  docs before assuming a style) — match its exact configured version if one
  is pinned, since indent tools can differ in output between versions. No
  project-wide reformatting in a feature/fix commit — formatting changes are
  their own commit.

## Memory & Resource Safety

- Every `malloc`/`calloc`/`strdup` etc. gets an immediate NULL check before use.
- Every allocation has one clear owner and one clear free site — prefer
  goto-based cleanup (`goto cleanup;` + a single `cleanup:` label) over
  duplicating free logic on every error path.
- No unnecessary allocations — reuse buffers, prefer stack allocation for
  bounded, small, non-escaping data.
- `free()` sets the pointer to NULL at the same call site when the pointer
  could plausibly be reused/rechecked afterward (defends against double-free,
  not a substitute for correct ownership).
- Match allocator families: don't `free()` something a library-specific
  allocator returned (an arena, a pool allocator, a runtime with its own
  `alloc`/`dealloc` pair) — free with whatever the allocating API expects.

## Error Handling

- Check every return value that can fail (syscalls, allocations, library
  calls) — no silently ignored `int` return from something that can error.
- Prefer one consistent error-propagation style per project (errno + return
  code, a `Result`-shaped struct, or the project's existing error-handling
  macro/convention) — don't mix styles within one file.
- Never sizeof() or index into a pointer that hasn't been checked for NULL
  on the current path.

## Verification Before Claiming Correctness

- Build with sanitizers when investigating a crash or memory bug:
  `-fsanitize=address,undefined` (ASan+UBSan) for general use;
  `-fsanitize=thread` (TSan) for suspected data races. Don't guess at a
  memory bug's cause without a sanitizer run to confirm it.
- `valgrind --leak-check=full` for a leak hunt when sanitizers aren't wired
  into the build.
- A crash reproducer is worth more than a plausible-sounding theory — get a
  minimal repro before proposing a fix.

## Structural Search & Refactoring

Prefer AST-aware tools over `grep`/`rg` for anything beyond a literal string
or log-message search:

- **`coccinelle`** (`spatch`, see the `coccinelle` skill) — semantic
  patches for renaming APIs, finding a call pattern across a large
  codebase, enforcing a structural rule (e.g. "every `malloc` has a NULL
  check"), migrating a deprecated API. Understands C at the AST level, not
  text.
- **`ast-grep`** — quick structural queries without writing a full SmPL
  patch (`ast-grep --pattern '$FUNC($$$)' --lang c`).
- Use `rg`/`grep` only for literal strings, log messages, or comments —
  not for "find all callers of X" or "find every place that frees Y."
