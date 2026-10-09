---
name: libumem
description: Use the libumem slab allocator and its debugging features — the `umem`/`umemctl` CLI tools, the GDB (`umem_gdb.py`) and LLDB (`umem_lldb.py`) command sets, and the UMEM_DEBUG/UMEM_OPTIONS tunables — to find leaks, double frees, buffer overruns and use-after-free in a process that links or LD_PRELOADs libumem. Triggers on: "umem findleaks", "umem walk", "UMEM_DEBUG", "libumem_malloc.so", "bufctl", "audit trail", "slab allocator leak", "which cache is this pointer in", "umem status", or any memory-corruption hunt in a project that uses libumem.
---

# libumem: allocator debugging

libumem is the Solaris/illumos userspace slab allocator, ported to Linux,
Windows and BSD/Darwin. Source: `codeberg.org/gregburd/libumem`, checked out
at `~/ws/libumem` on floki. It ships three debugging surfaces that share one
backend: a CLI (`umem`), a GDB module, and an LLDB module.

## Read the project's AGENTS.md first

`~/ws/libumem/AGENTS.md` is 236 lines of rules that came from real failures,
not style preference. Two matter before you run anything:

- **Never build, test, stress or benchmark libumem on floki.** The local
  machine is for editing and git only. Everything else runs on EC2 via
  `scripts/ec2/{launch,bootstrap,job,terminate}.sh` with roles `intel-lo`
  (8 vCPU x86_64), `intel-hi` (192 vCPU metal), `arm-lo`, `arm-hi`.
- **The AWS profile rotates** (`numa` → `beef` → `bene` → `hotdog` so far).
  Verify `AWS_PROFILE` at session start; never assume the one in your memory
  is current.

Debugging *another* program that uses libumem is not a libumem build, so it
does not need EC2. Building libumem itself does.

## Turning debugging on

Nothing below works unless the allocator is in a debugging mode. Two
environment variables, read at process start:

```sh
UMEM_DEBUG=default                 # audit,contents,guards — the usual choice
UMEM_DEBUG=audit                   # record a stack trace per allocation
UMEM_DEBUG=audit=20                # ...with 20 frames instead of the default
UMEM_DEBUG=contents                # save freed-buffer contents for inspection
UMEM_DEBUG=guards                  # redzones either side of each buffer
UMEM_DEBUG=firewall=64             # VM-backed guard pages for >64-byte bufs
UMEM_DEBUG=lite                    # cheap subset, usable in production
UMEM_DEBUG=verbose                 # louder diagnostics
UMEM_OPTIONS=tcache=0              # disable the per-thread cache
```

Two rules worth stating because both have wasted time:

- **`UMEM_DEBUG` must be set before the process starts.** It is read during
  allocator init; exporting it later does nothing.
- **Disable the per-thread cache (`UMEM_OPTIONS=tcache=0`) when hunting a
  leak.** With tcache on, freed buffers sit in thread-local magazines and
  `findleaks` reports them inconsistently.

Preloading into a program that does not link libumem:

```sh
UMEM_DEBUG=default LD_PRELOAD=/path/to/libumem_malloc.so ./myprog
```

**Never preload `libumem_malloc.so` into a Node, Python or Electron runtime
you care about.** Interposing a debug allocator under those has SIGSEGV'd
them in this environment — that is exactly why `modules/home-manager/ai/pi.nix`
strips `LD_PRELOAD` before exec'ing pi.

## The `umem` CLI

```
umem --pid PID CMD [ARGS...]
umem --core CORE --exe BIN CMD [ARGS...]     # accepted but REFUSED, see below
```

Commands (from `tools/umem.c`): `status`, `findleaks`, `walk`, `whatis`,
`bufctl`, `log`, `allocated`, `freed`, `snapshot`, `gdb`, `text`.

```sh
umem --pid 4242 status            # arenas, caches, debug flags in force
umem --pid 4242 findleaks         # unreferenced allocations + stacks
umem --pid 4242 walk              # iterate buffers; ALLOCATED/FREE/CACHED
umem --pid 4242 whatis 0x7f...    # which cache/slab owns this pointer
umem --pid 4242 bufctl 0x7f...    # the bufctl audit record for a buffer
umem --pid 4242 log               # the transaction log
umem --pid 4242 snapshot /tmp/s   # dump state for offline reading
```

`umemctl` is the control sibling; `umem_dump_reader` reads a snapshot back.
`man 1 umem`, `man 3 umem_debug`, `man 7 umem_debugging` are in the repo
(`umem.1`, `umem_debug.3`, `umem_debugging.7`).

**The `--core` mode is accepted on the command line and then refused.** The
man page says so explicitly under MODES. Do not plan a post-mortem workflow
around it; use the debugger modules on the core instead.

## GDB

```sh
gdb -p PID -ex 'source ~/ws/libumem/tools/gdb/umem_gdb.py'
```

Registers a `umem` command prefix:

| Command | What it does |
|---|---|
| `umem status` | allocator state, caches, active debug flags |
| `umem findleaks` | unreferenced buffers with allocation stacks |
| `umem walk` | iterate buffers in a cache |
| `umem whatis ADDR` | identify the cache/slab backing an address |
| `umem bufctl ADDR` | the audit record: stack, thread, timestamp |
| `umem log` | transaction log |
| `umem events` | allocator events |
| `umem break` | break on allocator events |
| `umem snapshot` | dump state |
| `umem help` | the authoritative list for the version you have |

It also exposes `umem_event_alloc`, `umem_event_free`, `umem_event_error`
and `umem_null_cache` for breakpoint work.

## LLDB

```sh
lldb -p PID -o 'command script import ~/ws/libumem/tools/lldb/umem_lldb.py'
```

`__lldb_init_module` registers a single `umem` command
(`command script add -f umem_lldb.umem_cmd umem`) with the same
subcommands: `findleaks`, `log`, `status`, `whatis`, `snapshot`, `break`,
`events`, `walk`, `help`.

The LLDB module works by calling *into the library* in the live process
(`_call_library`, `_ensure_loaded`), and it checks `_is_live` first — so
**most subcommands need a live process, not a core file.** That is the same
limitation as the CLI's refused `--core` mode, for the same reason.

## Reading the output

`walk` labels every buffer:

- **ALLOCATED** — handed out and not yet freed.
- **FREE** — returned to the cache's free list.
- **CACHED** — sitting in a thread-local magazine (the tcache). This is the
  state that makes leak hunting ambiguous; see `tcache=0` above.

A `bufctl` record is the useful one during a corruption hunt: it carries the
allocating stack, so `umem whatis` → `umem bufctl` turns a raw pointer from a
crash into the line that allocated it.

## Choosing a mode for the bug you have

| Symptom | Mode |
|---|---|
| leak | `UMEM_DEBUG=audit` + `UMEM_OPTIONS=tcache=0`, then `findleaks` |
| double free / use-after-free | `UMEM_DEBUG=default`, then `bufctl` on the pointer |
| buffer overrun | `UMEM_DEBUG=guards`, or `firewall=N` for page-granular faults |
| "what is this pointer" | any mode; `whatis` then `bufctl` |
| production, low overhead | `UMEM_DEBUG=lite` |

`firewall` costs a VM page per buffer above the threshold — it finds overruns
precisely and exhausts address space fast. Use it on a reduced repro, not a
full workload.

## Honest limits

- Everything here needs libumem in the process. On a program using glibc
  malloc, these commands have nothing to inspect.
- `audit` records a stack per allocation; it is slow and memory-hungry. Do
  not benchmark under it and call the number representative.
- A leak `findleaks` reports under `tcache` on may be a cached buffer, not a
  leak. Re-run with `tcache=0` before believing it.
