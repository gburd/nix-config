---
name: alignment-hunt
description: Find misaligned memory access in C/C++ before it ships, using clang diagnostics, UBSan and a run on a strict-alignment host (UltraSPARC, RISC-V, AArch64). Covers code that keeps typed data in a byte buffer and casts it back (`(uint64_t *)(buf + off)`), packed structs, wire/file formats parsed in place, caller-supplied buffers, and atomics on such data. Use when porting to a non-x86 host, when adding `-Wcast-align`, when a test passes on x86 but crashes with SIGBUS/SIGSEGV elsewhere, or when reviewing serialization, allocator or container code. Triggers on: "alignment", "-Wcast-align", "SIGBUS", "Bus error", "misaligned", "strict alignment", "packed struct", "cast to uint64_t *", "runs on x86 but not on sparc/riscv/arm", "unaligned access".
---

# Alignment hunt

## Why this needs its own procedure

On x86_64 a misaligned load is legal and nearly free, so misaligned code
runs, passes every test, and gcc says nothing. It is still undefined
behaviour in C (C11 6.3.2.3p7). The optimizer may assume alignment, for
example merging two loads into one vector load, and other architectures
punish it:

| host | misaligned scalar load | misaligned atomic |
|---|---|---|
| x86_64 | works, fast | works (a split lock is very slow) |
| UltraSPARC (sun4u, `sun`) | **SIGBUS**, even 4-byte-aligned 8-byte loads | SIGBUS |
| RISC-V, kernel-emulated | works but traps into the kernel each time, ~100x slower | **SIGSEGV/SIGBUS** |
| RISC-V, hardware-fast (SpacemiT X100, `lixr`) | works, fast | **SIGSEGV** |
| AArch64 with LSE2 (`uscat`, e.g. santorini) | works | works |
| AArch64 without LSE2 (older cores) | works for normal memory | can fault (exclusives `ldxr`/`stxr` need natural alignment) |

So a byte buffer cast to `uint64_t *` can be a silent performance cliff on
one RISC-V board and a crash on another. Atomics are worse: on lixr a
misaligned `atomic_fetch_add` is SIGSEGV even though plain loads are
fine. On santorini's aarch64 (LSE2) the same atomic works. Code that has
"always worked" may never have run anywhere that punishes it.

(Measured 2026-10-15 with an 8-byte load and an `atomic_fetch_add` at
offsets 0, 1 and 4. sun: SIGBUS at 1 and 4. lixr: plain loads fine, atomic
SIGSEGV at 1. santorini/wixa aarch64: everything fine.)

## The two-tool split (measured, not assumed)

- **gcc does not warn by default.** `-Wcast-align` is a no-op on targets
  that allow unaligned access (x86_64, and riscv64 per its target
  description). Only `-Wcast-align=strict` warns everywhere.
- **clang `-Wcast-align` warns on every target**, including x86_64. It
  flags any cast that raises the pointee's required alignment.
- **Neither proves anything at runtime.** The warning only says the
  compiler cannot prove alignment. The runtime proof is UBSan
  `-fsanitize=alignment` or a run on a host that traps.

Use all three. Each layer catches what the one before cannot.

## Procedure

### 1. Get clang warnings (any host; x86 is fine)

```sh
CFLAGS="-Wcast-align -Wcast-qual -Watomic-alignment -Waddress-of-packed-member"
# meson:     meson setup build-clang -Dc_args="$CFLAGS" --native-file=<clang> (or CC=clang)
# autotools: CC=clang ./configure CFLAGS="$CFLAGS -O2 -g"
# make:      make CC=clang CFLAGS="$CFLAGS ..."
```

- `-Wcast-align`: the main one. Each hit is a cast that raises alignment.
- `-Watomic-alignment`: an atomic op on an object that may be underaligned.
  On riscv64 and AArch64 that is a crash, not a slowdown. Treat it as an
  error.
- `-Waddress-of-packed-member`: `&packed->field` produces a misaligned
  pointer that the type system still thinks is aligned.

If the project builds with `-Werror`, add these to a throwaway CFLAGS
first and count the hits. Don't turn on `-Werror` and fix them one build
failure at a time.

To get the same warning set without the target hardware, clang can
cross-compile translation units with `--target=riscv64-linux-gnu` or
`--target=sparc64-unknown-linux-gnu`. Use the UNWRAPPED clang
(`nixpkgs#llvmPackages.clang-unwrapped`). The nix cc-wrapper injects
x86-only flags such as `-fzero-call-used-regs` and the cross target
rejects them. The warnings match x86 clang, so this only matters for
target-specific code paths (`#ifdef __riscv`, `__sparc__`, `__aarch64__`).

### 2. Triage every hit into exactly one bucket

For each warning, read the code and decide which bucket it falls in.
Never decide from the warning text alone.

1. **Provably aligned.** The base comes from `malloc` / `aligned_alloc` /
   an aligned struct member, and every offset or stride is a multiple of
   the target type's alignment. Write down WHY next to the cast. Then
   launder the cast through `void *`:
   `(uint64_t *)(void *)(buf + off)`. That is the standard "I know the
   alignment" annotation, and it changes no code. Check the disassembly
   is identical before and after (`objdump -d`, or `-S` output diff).
2. **Caller-controlled or format-defined alignment.** A buffer the API
   accepts from the caller, a field at an odd offset in a file or wire
   format, a pointer into an mmap'd file. NOT safe. Read and write
   through `memcpy` (compilers lower a fixed-size memcpy to a single load
   where the hardware allows it), or through a type that admits
   misalignment:
   `typedef uint64_t u64_unaligned __attribute__((aligned(1), may_alias));`
   Never put an atomic on such data. There is no misaligned-atomic
   fallback; fix the layout instead.
   Then add a test that exercises offsets 0..7.
3. **Genuinely misaligned in normal operation.** A real bug. Fix the
   layout (pad, reorder, align the allocation) rather than paper over it.

`(void *)` laundering on a bucket-2 or bucket-3 cast hides a crash. Use it
only after a written argument for bucket 1.

### 3. Prove it at runtime with UBSan

```sh
CC=clang CFLAGS="-O1 -g -fsanitize=alignment -fno-sanitize-recover=alignment"
```

`-fno-sanitize-recover` makes the first misaligned access abort with
`runtime error: load of misaligned address ... requires 8 byte
alignment`, file and line included, rather than logging and carrying
on. This works on x86_64 and on lixr (clang 21 supports
address/undefined/thread/leak on riscv64; `-fsanitize=memory` is
unsupported there). It does NOT work on `sun`: OpenIndiana's clang 21
ships no `libclang_rt.ubsan` for sparc. Use step 4 there.

Run the FULL test suite, plus a test that drives the same API from every
buffer offset 0..7. If the code accepts external buffers, that offset
sweep is the test that matters.

**Before trusting a clean UBSan run, prove two things.** A sanitizer that
silently did not engage looks exactly like a pass.

- **The code under test is instrumented.** With a shared library, clang
  does not link the UBSan runtime into a `-shared` link. The `.so` then
  fails with `undefined reference to __ubsan_handle_*`, and meson/make can
  still go on to run tests against a stale or uninstrumented library.
  Check the build exit status, then `nm -D --undefined-only lib*.so | grep
  -c __ubsan_handle` (should be > 0). Fix it by putting the sanitizer in
  the LINK flags too, with the shared runtime: `-fsanitize=... 
  -shared-libsan`. Bianbu's clang embeds no rpath for that runtime
  (`error while loading shared libraries:
  libclang_rt.ubsan_standalone-<arch>.so`), so add
  `-Wl,-rpath,$(dirname $(clang -print-file-name=libclang_rt.ubsan_standalone-$(uname -m).so))`.
- **The check fires with this toolchain.** Build a three-line program that
  does a misaligned `uint64_t` load with the SAME flags, and confirm it
  aborts with `runtime error: load of misaligned address`. If a known bug
  is available (the parent of a commit that fixed one), build that too: it
  must fail.

UBSan also slows the code down a lot. Raise test timeouts (`meson test
--timeout-multiplier 6`) rather than reading a timeout as a pass or a
hang.

### 4. Run on a host that punishes misalignment

The warnings and UBSan show what the code may do. A strict-alignment run
shows what it actually does:

- **`sun`** (UltraSPARC-IIIi, OpenIndiana, gcc 13 + clang 21): the
  strictest. Any misaligned 8-byte access is SIGBUS (exit 138), even at a
  4-byte offset. A clean suite here proves the buffers really are
  aligned, not just warning-silenced.
- **`lixr`** (SpacemiT K3, riscv64, Bianbu, clang 21 + gcc 15): scalar
  misaligned access is FAST in hardware (`riscv_hwprobe` key 9 = 3), so
  plain loads will NOT crash. Misaligned atomics still SIGSEGV. lixr's
  value is UBSan on a non-x86 ISA, plus catching atomics, plus
  `#ifdef __riscv` paths.
- **AArch64** (EC2 Graviton, or `santorini`'s wixa WSL guest): plain loads
  are tolerated. santorini has LSE2 (`uscat` in /proc/cpuinfo) and
  tolerates misaligned atomics too, so it is the weakest of the three as a
  trap. Its value is the `__aarch64__` code paths and UBSan on a third
  ISA.

On RISC-V, check what the kernel does before reading a clean run as
proof. Read `/proc/sys/kernel/unaligned-trap` and the hwprobe
`MISALIGNED_SCALAR_PERF` key. On an EMULATED board a misaligned load
"works" at around 100x the cost and shows up only as a slowdown.

### 5. Sanity-check the result

- gcc and clang both still build with the project's normal flags.
- For every bucket-1 cast, the object code is unchanged. The `(void *)`
  launder must be a no-op.
- The strict-alignment run had zero SIGBUS/SIGSEGV, and UBSan reported
  zero `misaligned address` errors.
- Record which hosts and compilers ran, and the counts, in the commit
  message.

## Things that bit before

- **Locale-dependent test output.** riscv64 Bianbu collated `-1` vs `1`
  differently from glibc on x86 in a `sort`-based expected-output test.
  Set `LC_ALL=C` in test harnesses that sort.
- **Compiler-specific `-Wno-` flags.** gcc rejects some clang `-Wno-`
  spellings and the reverse. Probe them in configure/meson
  (`cc.get_supported_arguments`), don't hard-code them.
- **SIMD intrinsics.** `_mm_loadu_si128((const __m128i *)p)` warns under
  `-Wcast-align`, but `loadu`/`storeu` are alignment-agnostic by
  definition. That is a bucket-1 launder, not a bug.
- **Separate your code from vendored code.** Amalgamated third-party
  sources compiled into the tests (a bundled `roaring.c`, `munit.c`,
  `sqlite3.c`) can drown the real signal: in one run 112 of 112
  `-Wcast-align` hits were in a vendored file and 0 in the library. Group
  hits by file before triaging, and do not "fix" generated or vendored
  files. Report them upstream, or scope the flag to your own targets.
- **`-Wcast-qual` is not an alignment warning.** It reports dropped
  `const`/`volatile`. Count it separately so it doesn't inflate the
  alignment tally.
- **A warning count of zero under gcc proves nothing.** gcc's
  `-Wcast-align` is silent on x86_64 and riscv64. A project whose
  `-Werror` list includes `-Wcast-align` but has only ever been built
  with gcc has never had that check run.

## Hosts

- `lixr`: `ssh -o IdentitiesOnly=yes -o IdentityAgent=none -i ~/.ssh/id_ed25519 gburd@192.168.1.179`. No nix binary cache for riscv64, so use the system clang/gcc from apt for this work.
- `sun` (icarus): `ssh gburd@192.168.1.206`. gcc at `/usr/gcc/13/bin/gcc`, clang at `/usr/bin/clang`. Single 1.6 GHz core: builds are slow. Run only the test binaries you need.
