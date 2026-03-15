# Development Environment Setup - Comprehensive Guide

This document describes the complete development environment configuration for Rust, C/C++, Python, Bash, SQL (PostgreSQL), and more, with integrated editing, debugging, testing, and workflow tools.

## Table of Contents

1. [Neovim Configuration](#neovim-configuration)
2. [Debuggers (GDB/LLDB)](#debuggers-gdblldb)
3. [Testing Framework](#testing-framework)
4. [Editor Alternatives](#editor-alternatives)
5. [Email Client](#email-client-neomutt)
6. [Development Toolchains](#development-toolchains)
7. [Virtualization](#virtualization)
8. [Workflow Guide](#workflow-guide)

---

## Neovim Configuration

### Features Added

#### 1. **DAP Debugging** (F5-F12, `<leader>d` prefix)
- **Rust**: codelldb adapter for cargo debug builds
- **C/C++**: codelldb adapter with full symbol support
- **Python**: debugpy with venv auto-detection
- **Go**: delve debugger

**Key Bindings:**
- `<F5>`: Start/Continue debugging
- `<F10>`: Step over
- `<F11>`: Step into
- `<F12>`: Step out
- `<leader>db`: Toggle breakpoint
- `<leader>dB`: Conditional breakpoint
- `<leader>du`: Toggle debug UI
- `<leader>de`: Evaluate expression
- `<leader>dt`: Terminate debugger

**Usage:**
```bash
# Rust debugging
cd your-rust-project
nvim src/main.rs
# Set breakpoints with <leader>db
# Press F5 to start debugging
# Select "Launch" and provide path to target/debug/executable

# Python debugging
nvim script.py
# Set breakpoints, press F5
# Automatically detects venv/virtualenv
```

#### 2. **Testing Framework** (neotest, `<leader>t` prefix)
- **Rust**: cargo test, cargo-nextest support
- **Python**: pytest, unittest
- **C/C++**: GoogleTest (gtest)
- **Lua**: plenary (for neovim plugins)

**Key Bindings:**
- `<leader>tt`: Run nearest test
- `<leader>tf`: Run all tests in current file
- `<leader>tF`: Run all tests in project
- `<leader>td`: Debug nearest test
- `<leader>to`: Show test output
- `<leader>tS`: Toggle test summary panel
- `[t` / `]t`: Jump to prev/next failed test

**Usage:**
```rust
// Rust test example
#[test]
fn test_something() {
    assert_eq!(2 + 2, 4);
}
// Place cursor on test, press <leader>tt
```

```python
# Python test example
def test_example():
    assert 2 + 2 == 4
# Place cursor on test, press <leader>tt
```

#### 3. **Enhanced Linting**
- **Python**: ruff (style), mypy (types)
- **Bash**: shellcheck
- **Markdown**: markdownlint
- **Rust/C++**: Built-in LSP diagnostics + clippy/clang-tidy

**Key Bindings:**
- `<leader>ll`: Manually trigger linting

#### 4. **Improved Formatters**
- **Rust**: rustfmt (via rust-analyzer)
- **C/C++**: clang-format (via clangd)
- **Python**: black
- **Bash**: shfmt
- **SQL/PostgreSQL**: pgformatter, sqlfluff
- **Nix**: nixpkgs-fmt

#### 5. **Development Workflow** (`<leader>c` prefix)
Quick compile/run/test/commit cycle:

**Build & Run:**
- `<leader>cc`: Quick compile check
  - Rust: `cargo check`
  - C/C++: `cmake --build build`
  - Python: syntax check
- `<leader>cb`: Build release
- `<leader>cr`: Run current file/project

**Git Workflow:**
- `<leader>gc`: Git commit
- `<leader>gp`: Git push
- `<leader>gP`: Git pull
- `<leader>gs`: Git status
- `<leader>gl`: Git log
- `<leader>gd`: Git diff
- `<leader>gb`: Git blame

**Quickfix:**
- `<leader>qo/qc`: Open/close quickfix
- `<leader>qn/qp`: Next/previous error
- `[q` / `]q`: Navigate with trouble.nvim

**Code Actions:**
- `<leader>cf`: Format buffer
- `<leader>co`: Organize imports

#### 6. **LSP Servers Configured**
All provided by Nix (no Mason installation):
- `lua_ls`: Lua
- `nil_ls`: Nix
- `clangd`: C/C++
- `pyright`: Python
- `rust_analyzer`: Rust (via rustup)
- `bashls`: Bash/Shell
- `sqlls`: SQL

---

## Debuggers (GDB/LLDB)

### GDB Configuration (`~/.gdbinit`)

**Features:**
- PostgreSQL-specific pretty printers
- Custom commands for Node, List, Query structures
- Breakpoint shortcuts for common functions
- History saved across sessions

**Usage:**
```bash
# Debug PostgreSQL backend
gdb /path/to/postgres
(gdb) bexec       # Break at exec_simple_query
(gdb) bplan       # Break at planner
(gdb) bparse      # Break at parser
(gdb) berror      # Break at error handler

# PostgreSQL structures
(gdb) pnode $node_var     # Print Node
(gdb) plist $list_var     # Print List
(gdb) pquery $query_var   # Print Query

# Attach to running backend
gdb
(gdb) pbackend 12345      # Attach to PID 12345
```

### LLDB Configuration (`~/.lldbinit`)

Similar features as GDB but for LLDB/LLVM:
```bash
# Debug with LLDB
lldb ./your-program
(lldb) bexec              # Break at exec_simple_query
(lldb) pnode node_var     # Print Node structure
```

**PostgreSQL Development:**
Both configs include:
- Pretty printers for PostgreSQL data structures
- Breakpoint shortcuts for common functions
- Memory context helpers
- Backend process attachment

---

## Testing Framework

### Neotest Integration

**Test Runners Available:**
- **Rust**: `cargo test`, `cargo-nextest` (faster test runner)
- **Python**: `pytest` (with venv detection)
- **C/C++**: GoogleTest (`gtest`)

**Watch Mode:**
```vim
" Enable watch mode for automatic test rerun
:lua require('neotest').run.run({strategy = 'dap', watch = true})
```

**Test Output Panel:**
- Opens automatically on test failure
- Shows full test output and diagnostics
- Integrates with quickfix for navigation

**Example Workflow:**
```bash
# 1. Write test
# 2. Run with <leader>tt
# 3. If fails, fix code
# 4. Rerun with <leader>tt
# 5. Debug if needed with <leader>td
```

---

## Editor Alternatives

### Zed Editor

**Configuration:** `~/.config/zed/`
- **Theme**: Gruvbox Dark Hard (matching nvim)
- **Vim Mode**: Enabled
- **LSP**: All same servers as nvim
- **Keybindings**: Space as leader, similar to nvim

**Key Features:**
- Native performance (Rust-based)
- Built-in collaboration
- Same formatters and linters as nvim
- Vim keybindings with nvim-like leader mappings

**Launch:**
```bash
zed /path/to/project
```

### Sublime Text

**Configuration:** `~/.config/sublime-text/Packages/User/`
- **Theme**: Adaptive with Mariana color scheme
- **Font**: JetBrains Mono (same as nvim)
- **LSP**: Configure via LSP package

**Features:**
- Fast startup and indexing
- Multiple cursors
- Powerful search and replace
- Good for large files

**Launch:**
```bash
subl /path/to/project
```

---

## Email Client (Neomutt)

### Features
- **Fastmail Integration**: IMAP/SMTP configured
- **Text-Only Workflow**: Optimized for mailing lists
- **Patch Handling**: Syntax highlighting for diffs
- **Line Wrapping**: 72 characters (mailing list standard)
- **Threading**: Full thread support for discussions

### Configuration

**Setup Credentials:**
```bash
# Add to ~/.bashrc or ~/.config/fish/config.fish
export FASTMAIL_USER="your.email@fastmail.com"
export FASTMAIL_PASS="your-app-password"  # Get from Fastmail settings
```

**Or use a password manager:**
```bash
# Example with pass
set -x FASTMAIL_PASS (pass show email/fastmail)
```

### Key Bindings (Vim-style)

**Navigation:**
- `gg`: First message
- `G`: Last message
- `Ctrl-d/u`: Half page down/up
- `-/_`: Collapse thread/all threads

**Actions:**
- `R`: Reply to all (important for mailing lists)
- `A`: Archive message
- `S`: Mark as spam
- `Ctrl-p`: View in vim (for patches)
- `Ctrl-e`: Edit/reply to patch in nvim

### Workflow for PostgreSQL Hackers List

1. **Reading Patches:**
   ```
   - Open email with patch attachment
   - Press 'v' to view attachments
   - Select patch, press Enter
   - Patch opens in nvim with syntax highlighting
   ```

2. **Replying with Comments in Patch:**
   ```
   - Open patch email
   - Press Ctrl-e to edit in nvim
   - Add inline comments prefixed with '>'
   - Save and quit
   - Email composition opens with your comments
   ```

3. **Sending Patches:**
   ```
   - Compose new email with 'c'
   - Add patch as attachment with Ctrl-f
   - Or pipe: git format-patch HEAD~1 --stdout | neomutt -s "Subject"
   ```

### Viewing HTML Emails
- Automatically converted to text via w3m
- Press `v` to view attachments and select HTML part if needed

---

## Development Toolchains

### Available Compilers & Tools

**C/C++:**
- GCC 14 (latest)
- Clang 18/LLVM 18
- Full debug symbols enabled
- `clang-tools` (clangd, clang-format, clang-tidy)

**Build Systems:**
- CMake 4.x
- Meson + Ninja
- GNU Make
- Autotools (autoconf, automake, libtool)

**Development Libraries:**
- glibc dev headers
- musl libc (for static linking)
- pkg-config for library discovery

### Using musl vs glibc

**musl (static linking):**
```bash
# Compile with musl
musl-gcc -static -o program program.c

# Verify static binary
ldd program  # Should show "not a dynamic executable"
```

**glibc (dynamic linking):**
```bash
# Standard compilation
gcc -o program program.c

# With debug symbols
gcc -g -O0 -o program program.c
```

### Cross-Compilation

```bash
# Set toolchain
export CC=musl-gcc
export CXX=musl-g++

# Or for specific architecture
export CC=x86_64-linux-gnu-gcc
```

---

## Virtualization

### Tools Installed

**QEMU/KVM:**
- Full system emulation
- KVM acceleration
- Supports x86, ARM, RISC-V, etc.

**Firecracker:**
- Lightweight microVM manager
- Fast boot times (<125ms)
- Minimal memory footprint

**libvirt:**
- Virtualization API
- Manage VMs via `virsh`
- virt-manager GUI (if needed)

### Usage Examples

**QEMU:**
```bash
# Create VM with KVM acceleration
qemu-system-x86_64 -enable-kvm -m 2G -hda disk.img -cdrom install.iso

# With network
qemu-system-x86_64 -enable-kvm -m 2G -hda disk.img -net nic -net user
```

**Firecracker:**
```bash
# Start microVM
firecracker --config-file vm-config.json

# Example config: vm-config.json
{
  "boot-source": {
    "kernel_image_path": "vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  }
}
```

**libvirt:**
```bash
# List VMs
virsh list --all

# Start VM
virsh start myvm

# Connect to console
virsh console myvm
```

### PostgreSQL Testing in VMs

```bash
# Test PostgreSQL in clean environment
qemu-system-x86_64 -enable-kvm -m 4G \
  -hda postgresql-test.qcow2 \
  -net nic -net user,hostfwd=tcp::5432-:5432

# SSH into VM and run tests
ssh -p 2222 user@localhost
cd /postgres
make check
```

---

## Workflow Guide

### Integrated Edit-Compile-Test-Debug-Commit Cycle

#### 1. **Edit** (Neovim/Zed/Sublime)
```vim
nvim src/main.rs
" Make changes
```

#### 2. **Compile/Check**
```vim
" In nvim, press:
<leader>cc    " Quick check (cargo check, cmake build, etc.)
<leader>cb    " Full release build
```

Or from terminal:
```bash
cargo build  # Rust
cmake --build build  # C/C++
```

#### 3. **Test**
```vim
" In nvim:
<leader>tt    " Run nearest test
<leader>tf    " Run all tests in file
<leader>tF    " Run all tests

" View test output
<leader>to    " Show output panel
```

#### 4. **Debug (if test fails)**
```vim
" Set breakpoint:
<leader>db    " Toggle breakpoint on current line

" Start debugging:
<F5>          " Start debugger
<F10>         " Step over
<F11>         " Step into
<F12>         " Step out

" Inspect:
<leader>de    " Evaluate expression
K             " Hover info
```

#### 5. **Fix Issues**
```vim
" Use quickfix to navigate errors:
<leader>qn    " Next error
<leader>qp    " Previous error
]q / [q       " Navigate with trouble.nvim

" Or navigate diagnostics:
]d / [d       " Next/previous diagnostic
```

#### 6. **Lint & Format**
```vim
<leader>cf    " Format buffer
<leader>ll    " Run linters
```

#### 7. **Commit**
```vim
" Stage changes and commit:
<leader>gc    " Open git commit
" Write commit message, save and quit

" Or use fugitive:
:Git add %    " Stage current file
:Git commit   " Commit
:Git push     " Push
```

Or from terminal:
```bash
git add -A
git commit -m "Fix: issue description"
git push
```

#### 8. **Repeat**
Go back to step 1 or 3 as needed.

### Example: Full Rust Development Cycle

```bash
# 1. Start project
cargo new myproject
cd myproject
nvim src/main.rs

# 2. Edit (in nvim)
" Write code...

# 3. Quick check
<leader>cc  # cargo check

# 4. Write tests
" Add #[test] functions

# 5. Run tests
<leader>tt  # Run nearest test

# 6. Debug if needed
<leader>db  # Set breakpoint
<F5>        # Start debugging

# 7. Format and lint
<leader>cf  # Format with rustfmt

# 8. Commit
<leader>gc  # Git commit

# 9. Push
<leader>gp  # Git push
```

### Example: PostgreSQL Development

```bash
# 1. Clone PostgreSQL
git clone https://git.postgresql.org/git/postgresql.git
cd postgresql

# 2. Build
./configure --enable-debug --enable-cassert
make -j8

# 3. Edit (in nvim)
nvim src/backend/executor/execMain.c

# 4. Quick compile check
<leader>cc  # cmake --build build (or make)

# 5. Set GDB breakpoints in nvim
<leader>db  # On line you want to debug

# 6. Debug PostgreSQL
gdb src/backend/postgres
(gdb) bexec          # Break at exec_simple_query
(gdb) run mydb
(gdb) pquery $query  # Print query structure

# 7. Run regression tests
make check

# 8. Format and commit
<leader>cf  # Format
<leader>gc  # Commit

# 9. Send patch to mailing list
git format-patch HEAD~1 --stdout > mypatch.patch
# Open neomutt, attach patch
```

---

## Performance Analysis Tools

### Installed Tools

**Memory:**
- `valgrind`: Memory leak detection
- `heaptrack`: Heap profiler

**CPU:**
- `perf`: Linux performance analyzer
- `hyperfine`: Command-line benchmarking

**System:**
- `strace`: System call tracer
- `ltrace`: Library call tracer

### Usage Examples

```bash
# Memory leak detection
valgrind --leak-check=full ./program

# Heap profiling
heaptrack ./program
heaptrack_gui heaptrack.program.*.zst

# CPU profiling
perf record -g ./program
perf report

# Benchmark
hyperfine 'cargo run --release' 'cargo run'
```

---

## Additional Resources

### PostgreSQL Development
- [PostgreSQL Hacker's Guide](https://wiki.postgresql.org/wiki/Developer_FAQ)
- [Mailing List Etiquette](https://www.postgresql.org/community/lists/)
- [Patch Submission Guidelines](https://wiki.postgresql.org/wiki/Submitting_a_Patch)

### Debugging Resources
- [GDB Cheat Sheet](https://darkdust.net/files/GDB%20Cheat%20Sheet.pdf)
- [LLDB Tutorial](https://lldb.llvm.org/use/tutorial.html)
- [PostgreSQL Debugging with GDB](https://wiki.postgresql.org/wiki/Developer_FAQ#Debugging)

### Email Workflow
- [Neomutt Manual](https://neomutt.org/guide/)
- [Email Patches with Git](https://git-send-email.io/)

---

## Troubleshooting

### Neovim Issues

**LSP not starting:**
```bash
# Check LSP status
:LspInfo

# Restart LSP
:LspRestart

# Check which clangd/pyright
which clangd pyright

# Should be in ~/.nix-profile/bin/
```

**DAP not working:**
```bash
# Check if codelldb is available
which codelldb

# Should be in nix store path from neovim wrapper
# Check with: nvim -c 'echo $PATH' -c 'qa!'
```

**Tests not running:**
```bash
# Check neotest status
:Neotest summary

# Check if pytest/cargo is in PATH
which pytest cargo
```

### Email Issues

**Can't connect to Fastmail:**
```bash
# Check credentials
echo $FASTMAIL_USER
echo $FASTMAIL_PASS  # (won't show for security)

# Test IMAP connection
openssl s_client -connect imap.fastmail.com:993
```

**HTML emails not rendering:**
```bash
# Install w3m if missing
nix-shell -p w3m

# Or update mailcap
nvim ~/.config/neomutt/mailcap
```

### Debugger Issues

**GDB can't attach:**
```bash
# May need to adjust ptrace scope
echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope

# Or use capabilities
sudo setcap cap_sys_ptrace=eip /usr/bin/gdb
```

**Debug symbols missing:**
```bash
# Ensure compiled with -g
gcc -g -O0 -o program program.c

# For Rust
cargo build  # Debug build has symbols by default

# For release with symbols
cargo build --release --profile release-with-debug
```

---

## Summary

You now have a complete, integrated development environment with:

✅ **Neovim**: Full IDE with LSP, DAP debugging, testing, linting, formatting
✅ **Zed & Sublime**: Alternative editors with matching configurations
✅ **GDB/LLDB**: PostgreSQL-optimized debugger configs
✅ **Neomutt**: Text-based email for mailing list workflows
✅ **Testing**: Integrated test runners for all languages
✅ **Toolchains**: Latest GCC, Clang, musl, glibc
✅ **Virtualization**: QEMU, KVM, Firecracker
✅ **Workflow**: Streamlined edit-compile-test-debug-commit cycle

**Next Steps:**
1. Set Fastmail credentials: `export FASTMAIL_USER=...`
2. Customize signature: `nvim ~/.config/neomutt/signature`
3. Try workflow: `nvim` → edit → `<leader>cc` → `<leader>tt` → `<F5>` → `<leader>gc`

Happy coding! 🚀
