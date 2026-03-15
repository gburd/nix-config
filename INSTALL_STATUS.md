# Installation Status Report

## ✅ Successfully Installed & Working

### Core Development Environment
- **Neovim** 0.11.6 with full enhancements
  - DAP debugging (lldb for Rust/C/C++, debugpy for Python)
  - Testing framework (neotest)
  - Enhanced linting (ruff, mypy, shellcheck)
  - PostgreSQL SQL formatting (pgformatter, sqlfluff)
  - Development workflow keybindings

### Debuggers
- **GDB** 16.3 with PostgreSQL config (`~/.gdbinit`)
- **LLDB** 21.1.7 with PostgreSQL config (`~/.lldbinit`)

### Email Client
- **Neomutt** 20250905 configured for Fastmail
  - Config: `~/.config/neomutt/neomuttrc`
  - Mailcap: `~/.config/neomutt/mailcap`
  - Signature: `~/.config/neomutt/signature`
  - **Setup Guide**: See `FASTMAIL_SETUP.md` and `EMAIL_QUICK_START.md`

### Editors
- **Neovim**: Primary editor with full IDE features
- **Zed**: Binary is `zeditor` (config at `~/.config/zed/`)
- **Sublime Text 4**: Build 4200 (installed via nix profile due to OpenSSL 1.1.1w dependency)

### Development Toolchains
- **GCC** 14.3 (latest)
- **Clang** 18 / LLVM 18
- **musl** libc for static linking
- **glibc** dev headers
- **Build tools**: cmake, meson, make, autotools
- **cargo-nextest**: Better Rust test runner

### Analysis & Profiling Tools
- **ccache**: Compiler cache
- **valgrind**: Memory debugger
- **heaptrack**: Heap profiler
- **strace**: System call tracer
- **ltrace**: Library call tracer
- **perf**: Linux performance analyzer

---

## ✅ Virtualization Tools & Sublime - Installed via Nix Profile

**Status**: Virtualization tools and Sublime Text 4 are installed and working via `nix profile install`.

**Discovery**:
- QEMU, Firecracker, libvirt, virt-manager, distcc: No longer depend on insecure OpenSSL 1.1.1w
- Sublime Text 4: DOES depend on OpenSSL 1.1.1w, requires `NIXPKGS_ALLOW_INSECURE=1`

### Installed Tools:
- **QEMU** 10.1.2 - Full system emulator (includes KVM support)
- **Firecracker** 1.13.2 - Lightweight microVM manager
- **libvirt** 11.7.0 - Virtualization API and management
- **virt-manager** 5.1.0 - Virtualization GUI
- **distcc** 3.3.5 - Distributed compilation
- **Sublime Text 4** Build 4200 - Text editor

### Installation Methods:
```bash
# Virtualization tools (no insecure deps)
nix profile install nixpkgs#qemu nixpkgs#firecracker nixpkgs#libvirt nixpkgs#virt-manager nixpkgs#distcc --impure

# Sublime Text 4 (requires insecure OpenSSL)
NIXPKGS_ALLOW_INSECURE=1 nix profile install nixpkgs#sublime4 --impure
```

### Verification:
```bash
$ which qemu-system-x86_64 firecracker virsh virt-manager distcc
/home/gburd/.nix-profile/bin/qemu-system-x86_64
/home/gburd/.nix-profile/bin/firecracker
/home/gburd/.nix-profile/bin/virsh
/home/gburd/.nix-profile/bin/virt-manager
/home/gburd/.nix-profile/bin/distcc
```

### Configuration Status:
`permittedInsecurePackages = ["openssl-1.1.1w"]` has been added to `home-manager/default.nix`, but this setting is NOT being respected during package evaluation in home-manager builds.

**Root Cause**: Home-manager's nixpkgs configuration doesn't properly propagate `permittedInsecurePackages` to package evaluation, causing packages that depend on OpenSSL 1.1.1w (like Sublime Text 4) to be silently skipped during builds.

**Workaround**: Install via `nix profile` with `NIXPKGS_ALLOW_INSECURE=1` environment variable.

**Note**: Virtualization and sublime packages are listed in config files for documentation, but must be installed via nix profile until home-manager's permittedInsecurePackages handling is fixed.

---

## 📁 Configuration Files Status

All configuration files are in place:

```bash
$ ls -la ~/.gdbinit ~/.lldbinit
-rw-r--r-- 1 gburd users 4276 Mar 15 14:20 /home/gburd/.gdbinit
-rw-r--r-- 1 gburd users 6579 Mar 15 14:20 /home/gburd/.lldbinit

$ ls ~/.config/neomutt/
mailcap  neomuttrc  signature

$ ls ~/.config/zed/
keymap.json  settings.json

$ ls ~/.config/nvim/ | head -3
init.lua
lua/
```

---

## 🚀 Quick Start

### 1. Neovim Development Workflow
```bash
nvim

# Inside nvim:
:LspInfo        # Check LSP servers
:checkhealth    # Verify DAP, neotest installed

# Try debugging:
# - Open Rust/C/Python file
# - Set breakpoint: <leader>db
# - Start debug: <F5>

# Try testing:
# - Open test file
# - Run nearest test: <leader>tt
# - Debug test: <leader>td
```

### 2. Email Setup (Neomutt + Fastmail)
```bash
# See complete guide:
cat EMAIL_QUICK_START.md

# Quick setup (5 minutes):
# 1. Get Fastmail app password from web interface
# 2. Set credentials in ~/.config/fish/config.fish:
#    set -gx FASTMAIL_USER "your.email@fastmail.com"
#    set -gx FASTMAIL_PASS "your-app-password"
# 3. Customize signature: nvim ~/.config/neomutt/signature
# 4. Test: neomutt
```

### 3. Debugger Testing
```bash
# Test GDB PostgreSQL helpers
gdb
(gdb) help pnode
(gdb) help bexec
(gdb) quit

# Test LLDB
lldb
(lldb) help
(lldb) quit
```

---

## 📊 What Works Now

### ✅ Complete Development Workflow
1. **Edit**: Neovim with LSP, completion, formatting
2. **Compile**: `<leader>cc` for quick check
3. **Test**: `<leader>tt` to run tests
4. **Debug**: `<F5>` to start DAP debugging
5. **Fix**: Navigate errors with `<leader>qn/qp`
6. **Commit**: `<leader>gc` for git commit
7. **Repeat**: Fast iteration cycle

### ✅ PostgreSQL Development
- GDB/LLDB with PostgreSQL-specific helpers
- Pretty printers for Node, List, Query structures
- Breakpoint shortcuts: `bexec`, `bplan`, `bparse`
- Memory context inspection: `pmemctx`, `pcurctx`

### ✅ Email for Mailing Lists
- Text-only workflow optimized for PostgreSQL Hackers
- 72-character line wrapping (mailing list standard)
- Patch syntax highlighting in nvim
- Inline patch commenting workflow
- Thread support for discussions

---

## 🔧 Known Issues & Solutions

### Issue: Virtualization tools not available
**Cause**: Dependencies on insecure OpenSSL 1.1.1w

**Solution**: Install at system level in NixOS configuration.nix
```nix
environment.systemPackages = with pkgs; [
  qemu_kvm
  libvirt
];
```

### Issue: Zed binary name is `zeditor` not `zed`
**Status**: This is correct - package installs as `zeditor`
```bash
which zeditor  # Correct
zeditor        # Launch Zed
```

### Issue: Neomutt/Zed not in home-manager packages list
**Status**: Installed manually via `nix profile install`
**Workaround**: Configs are properly set up, no action needed

---

## 📚 Documentation

Complete guides available:
1. **DEVELOPMENT_SETUP.md** - Full development environment guide
2. **FASTMAIL_SETUP.md** - Complete email setup and workflow
3. **EMAIL_QUICK_START.md** - 5-minute email quick start

---

## ✨ Summary

**What's Working**:
- ✅ Neovim with DAP, testing, linting, formatting
- ✅ GDB/LLDB with PostgreSQL helpers
- ✅ Neomutt email client for Fastmail
- ✅ GCC 14, Clang 18, musl, glibc
- ✅ Build tools, profilers, tracers
- ✅ Zed editor (`zeditor` command)
- ✅ Sublime Text 4 Build 4200 (`sublime` command)
- ✅ QEMU 10.1.2, Firecracker 1.13.2, libvirt 11.7.0, virt-manager 5.1.0, distcc 3.3.5

**Known Issues**:
- ⚠️ Home-manager's `permittedInsecurePackages` setting not working - packages with OpenSSL 1.1.1w dependency must be installed via `nix profile` with `NIXPKGS_ALLOW_INSECURE=1`

**Action Items**:
1. Set up Fastmail credentials (see EMAIL_QUICK_START.md)
2. Test nvim workflow: `nvim` → `<leader>cc` → `<leader>tt` → `<F5>`
3. Optional: Add virtualization tools to system config

The core development environment is fully functional! 🎉
