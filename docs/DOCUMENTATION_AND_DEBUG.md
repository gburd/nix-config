# Documentation and Debug Symbols in NixOS

A comprehensive guide to managing man pages, documentation, and debug symbols in NixOS systems and development environments.

## Table of Contents

1. [Understanding the Options](#understanding-the-options)
2. [System-Wide Configuration](#system-wide-configuration)
3. [Development Environments](#development-environments)
4. [Debugging with Symbols](#debugging-with-symbols)
5. [Per-Language Examples](#per-language-examples)

---

## Understanding the Options

### Documentation Types in NixOS

NixOS provides several types of documentation, each controlled separately:

| Type | Option | Description | Disk Impact |
|------|--------|-------------|-------------|
| **Man Pages** | `documentation.man.enable` | Traditional Unix manual pages | Small (~50MB) |
| **NixOS Manual** | `documentation.nixos.enable` | NixOS options and configuration guide | Small (~10MB) |
| **Development Docs** | `documentation.dev.enable` | Headers, pkg-config files | Medium (~100MB) |
| **HTML Docs** | `documentation.doc.enable` | Package HTML documentation | Large (1GB+) |
| **Info Pages** | `documentation.info.enable` | GNU Info documentation | Small (~20MB) |

### Debug Information

Debug symbols are separate files that debuggers (GDB, LLDB) use to:
- Show source code during debugging
- Display meaningful stack traces
- Resolve variable names and types
- Enable breakpoints by function name

**Cost:** Debug symbols typically double the size of binaries.

---

## System-Wide Configuration

### Basic Setup (Current in Your Config)

```nix
# In nixos/workstation/floki/default.nix
imports = [
  ../../_mixins/features/documentation.nix
  ../../_mixins/features/debug-symbols.nix
];
```

This gives you:
- ✅ Linux man pages (malloc, pthread, etc.)
- ✅ POSIX man pages (POSIX standards)
- ✅ Man search index (`man -k keyword`)
- ✅ Debug symbols for system packages
- ✅ Debugging tools (gdb, valgrind, strace)

### Customizing Documentation

Override defaults in your host config:

```nix
# Minimal documentation (save disk space)
documentation = {
  nixos.enable = true;   # Keep NixOS manual
  man.enable = true;     # Keep man pages
  dev.enable = false;    # Skip development headers
  doc.enable = false;    # Skip HTML docs
  info.enable = false;   # Skip GNU info
};
```

```nix
# Maximum documentation (development machine)
documentation = {
  nixos.enable = true;
  man.enable = true;
  man.generateCaches = true;  # Enable man -k search
  dev.enable = true;
  doc.enable = true;   # Warning: Uses significant disk space
  info.enable = true;
};

environment.systemPackages = with pkgs; [
  man-pages
  man-pages-posix
  linux-manual        # Kernel documentation
  stdmanpages         # Additional standard pages
];
```

### Debug Symbols System-Wide

```nix
# Enable debug info for all packages
environment.enableDebugInfo = true;

# This creates separate debug outputs that GDB can find
# Example: glibc.debug contains debug symbols for libc
```

**Important:** This doesn't rebuild packages with debug symbols—it just ensures the separate `.debug` files are available.

---

## Development Environments

### Quick Start: Simple Dev Shell

```nix
# shell.nix or flake.nix devShell
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Your tools
    gcc
    cmake

    # Documentation
    man-pages
    man-pages-posix

    # Debug tools
    gdb
    valgrind
  ];
}
```

### Advanced: Language-Specific Shells

See `examples/dev-flake-with-docs.nix` for complete examples:

- **C/C++**: GDB, Valgrind, man pages for libc/POSIX
- **Python**: Pudb, IPython, Python debug mode
- **Rust**: LLDB, RR time-travel debugger, rustup doc

### Building Your Code with Debug Symbols

**C/C++ (Make):**
```bash
make CFLAGS="-g -O0"
```

**C/C++ (CMake):**
```bash
cmake -DCMAKE_BUILD_TYPE=Debug ..
make
```

**Rust:**
```bash
cargo build  # Debug is default!
# Or explicitly:
RUSTFLAGS="-C debuginfo=2" cargo build
```

**Python:**
```bash
# Python doesn't need compilation, but you can disable optimization:
python -O0 script.py
```

---

## Debugging with Symbols

### Using GDB with Nix Packages

When debugging a program that uses Nix-built libraries:

```bash
# Enter development shell with debug info
nix develop

# Debug your program
gdb ./my-program

# GDB commands:
(gdb) break main
(gdb) run
(gdb) backtrace        # Shows function names because of debug symbols
(gdb) frame 2          # Jump to frame 2
(gdb) info locals      # Shows local variables
(gdb) print myvar      # Inspect variables
```

### Getting Debug Symbols for System Libraries

**Method 1: Use the debug output**
```nix
# In your dev shell
buildInputs = [
  pkgs.glibc.debug    # Debug symbols for libc
  pkgs.openssl.debug  # Debug symbols for OpenSSL
];

NIX_DEBUG_INFO_DIRS = "${pkgs.glibc.debug}/lib/debug";
```

**Method 2: Build with debug symbols**
```nix
# See examples/advanced-debug-example.nix
withDebugInfo = pkg: pkg.overrideAttrs (old: {
  dontStrip = true;
  separateDebugInfo = true;
  NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE or "" + " -g -O0";
});

buildInputs = [
  (withDebugInfo pkgs.mypackage)
];
```

### Debugging Tools Comparison

| Tool | Purpose | Best For |
|------|---------|----------|
| **gdb** | General debugger | C/C++, stepping through code |
| **lldb** | LLVM debugger | Rust, modern C++ |
| **valgrind** | Memory debugger | Finding memory leaks, use-after-free |
| **rr** | Time-travel debugger | Reproducing bugs, reverse execution |
| **strace** | System call tracer | Finding which syscalls fail |
| **ltrace** | Library call tracer | Finding which library functions called |

---

## Per-Language Examples

### C Development

```nix
pkgs.mkShell {
  buildInputs = with pkgs; [
    gcc
    gdb
    valgrind
    man-pages
    man-pages-posix
  ];

  shellHook = ''
    echo "📚 Man pages available:"
    echo "  man malloc    # Memory allocation"
    echo "  man pthread   # POSIX threads"
    echo "  man socket    # Network sockets"
  '';
}
```

**Debugging workflow:**
```bash
gcc -g -O0 program.c -o program
gdb ./program
```

### Python Development

```nix
pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    python3Packages.pudb     # Terminal debugger
    python3Packages.ipython  # Interactive shell
  ];

  PYTHONDEBUG = "1";  # Enable debug mode
}
```

**Debugging workflow:**
```bash
python -m pudb script.py
# Or add to your code:
# import pudb; pudb.set_trace()
```

### Rust Development

```nix
pkgs.mkShell {
  buildInputs = with pkgs; [
    rustc
    cargo
    rust-analyzer
    lldb
    rr
  ];

  RUSTFLAGS = "-C debuginfo=2";
}
```

**Debugging workflow:**
```bash
cargo build
rust-lldb target/debug/my-program

# Or with rr for time-travel:
rr record target/debug/my-program
rr replay
```

---

## Best Practices

### For Development Machines

✅ **Do:**
- Enable `documentation.man.generateCaches` for fast man -k searches
- Include `man-pages` and `man-pages-posix`
- Use `environment.enableDebugInfo = true`
- Create language-specific dev shells

❌ **Don't:**
- Enable `documentation.doc.enable` unless you need it (uses GB of space)
- Build everything with debug symbols (slow, large)

### For Production/Servers

✅ **Do:**
- Keep `documentation.man.enable = true` (troubleshooting)
- Disable `documentation.dev.enable` (save space)
- Disable debug info unless needed

❌ **Don't:**
- Ship binaries with debug symbols (security risk, large)

### For Development Flakes

✅ **Do:**
- Provide multiple shells (default, minimal, debug)
- Document in shellHook what's available
- Set language-specific environment variables (RUSTFLAGS, etc.)
- Include only needed tools per language

❌ **Don't:**
- Include every debugging tool in every shell
- Forget to set NIX_DEBUG_INFO_DIRS for GDB

---

## Quick Reference

### Man Page Sections

| Section | Content |
|---------|---------|
| 1 | User commands |
| 2 | System calls |
| 3 | Library functions |
| 4 | Device files |
| 5 | File formats |
| 6 | Games |
| 7 | Miscellaneous |
| 8 | System administration |

**Usage:** `man 2 open` (section 2, open syscall)

### GDB Quick Commands

```bash
gdb ./program              # Start GDB
(gdb) run arg1 arg2       # Run with arguments
(gdb) break function_name # Set breakpoint
(gdb) continue            # Continue after break
(gdb) next                # Step over
(gdb) step                # Step into
(gdb) backtrace           # Show call stack
(gdb) print variable      # Print variable
(gdb) quit                # Exit
```

### Useful Man Pages for Programming

```bash
man 2 open        # File operations
man 2 fork        # Process creation
man 3 malloc      # Memory allocation
man 3 pthread     # POSIX threads
man 7 socket      # Network programming
man 7 signal      # Signal handling
man 3 regex       # Regular expressions
```

---

## Troubleshooting

### "No manual entry for X"

```bash
# Rebuild man cache
sudo nixos-rebuild switch

# Check MANPATH
echo $MANPATH

# Manually rebuild cache
sudo mandb
```

### GDB can't find source files

```nix
# In your dev shell, add:
NIX_DEBUG_INFO_DIRS = "${pkgs.stdenv.cc.cc.debug}/lib/debug";
```

### Package doesn't have debug output

```nix
# Some packages don't provide .debug outputs
# Build it yourself with debug info:
myPackageDebug = pkgs.myPackage.overrideAttrs (old: {
  dontStrip = true;
  separateDebugInfo = true;
});
```

---

## See Also

- Examples: `examples/dev-flake-with-docs.nix`
- Advanced: `examples/advanced-debug-example.nix`
- NixOS Options: <https://search.nixos.org/options>
- GDB Manual: `info gdb` or <https://sourceware.org/gdb/documentation/>
