# NixOS Configuration Modernization Summary

## Overview
This document summarizes the modernization of the NixOS configuration completed in March 2026.

## Changes Implemented

### Phase 1: Preparation & Backup
- Created `modernization-prep` branch
- Tagged `pre-modernization` for rollback
- Committed initial state

### Phase 2: Core Updates
- **Updated nixpkgs**: 24.11 → 25.11
- **Updated home-manager**: release-24.11 → release-25.11
- **Updated stateVersion**: "24.11" → "25.11"
- Regenerated `flake.lock` with all updated inputs

### Phase 3: Architecture Modernization
- **Added Taskfile.yml** for convenient build/rebuild commands:
  - `task rebuild-all` - Rebuild both NixOS and home-manager
  - `task rebuild-host` - Rebuild NixOS only
  - `task rebuild-home` - Rebuild home-manager only
  - `task test-build` - Dry-build test
  - `task check` - Run flake check
  - `task gc` - Garbage collect old generations
  - `task fmt` - Format Nix code
  - `task update` - Update flake inputs
- Added `go-task` to `shell.nix`

### Phase 4: Arnold Integration
- **Added arnold as second home-manager host** (Fedora + Nix)
- Created `home-manager/_mixins/users/gburd/hosts/arnold.nix`
- Added `"gburd@arnold"` to `flake.nix` homeConfigurations
- Arnold imports shared CLI and console mixins

### Phase 5: Neovim Modernization
- **Merged arnold-nvim with current setup**
- Created modular structure:
  ```
  home-manager/_mixins/console/neovim/
  ├── default.nix          # Nix wrapper with packages
  ├── init.lua             # Entry point
  └── lua/
      ├── options.lua
      ├── keymaps.lua
      ├── lazy-bootstrap.lua
      ├── lazy-plugins.lua
      └── kickstart/plugins/
          ├── blink-cmp.lua
          ├── conform.lua
          ├── gitsigns.lua
          ├── git-blame.lua
          ├── lspconfig.lua
          ├── neo-tree.lua
          ├── overseer.lua
          ├── telescope.lua
          ├── treesitter.lua
          ├── trouble.lua
          └── (others)
  ```
- **Configured LSPs**: lua_ls, nil_ls, rust-analyzer, clangd, pyright, bashls
- **Added F11 keybinding** for meson compile
- **Included development tools**: language servers, formatters, build tools

### Phase 6: Claude Code & MCP
- **Created Claude Code mixin** at `home-manager/_mixins/console/claude-code/`
- **Configured MCP servers**:
  - filesystem (for local file access)
  - memelord (for meme generation)
  - github (for GitHub integration)
- Moved claude-code from `shell.nix` to home-manager mixin
- Included development tools for Claude Code

### Phase 7: Browser Consolidation
- **Created browser mixin** at `home-manager/_mixins/desktop/browsers.nix`
- **Consolidated to ungoogled-chromium** (Orion pending)
- Preserved Chromium profile location at `~/.config/chromium/`

### Phase 8: Mailspring Custom Package
- **Created Mailspring package** at `pkgs/mailspring/`
- Added Message-ID randomization patch (placeholder)
- Updated `pkgs/default.nix` to include mailspring

### Phase 9: Cleanup & Documentation
- Formatted code with `nix fmt`
- Removed old `neovim.nix` file (replaced with directory structure)
- Created this documentation

## Current Configuration

### Hosts
- **floki**: NixOS workstation (Lenovo Carbon X1 Extreme Gen 5)
- **arnold**: Fedora + Nix (home-manager only)

### Key Features
- **Unified Neovim**: Modern kickstart-based configuration with LSPs and plugins
- **Claude Code**: Integrated with MCP servers for enhanced AI assistance
- **Custom Packages**: Mailspring (with Message-ID patch), pending Orion
- **Task Runner**: Convenient Taskfile for common operations
- **Multi-host**: Shared mixins between NixOS and Fedora systems

## Quick Start Commands

### Building Configurations
```bash
# Build and activate everything
task rebuild-all

# Build NixOS only
sudo nixos-rebuild switch --flake .

# Build home-manager only
home-manager switch -b backup --flake .

# Test builds without activation
task test-build
```

### Arnold (Fedora + Nix)
```bash
# Build arnold home-manager config
nix build .#homeConfigurations."gburd@arnold".activationPackage

# Activate on arnold
./result/activate
```

### Maintenance
```bash
# Update flake inputs
task update

# Format code
task fmt

# Garbage collect old generations
task gc

# Check flake
task check
```

## Structure Overview

```
nix-config/
├── flake.nix              # Main flake configuration
├── flake.lock             # Locked input versions
├── Taskfile.yml           # Task runner configuration
├── shell.nix              # Development shell
├── lib/                   # Helper functions
├── nixos/                 # NixOS configurations
├── home-manager/
│   ├── _mixins/
│   │   ├── cli/           # CLI tools (bash, git, gh, etc.)
│   │   ├── console/       # Console apps (neovim, tmux, claude-code)
│   │   ├── desktop/       # Desktop apps (browsers, etc.)
│   │   └── users/
│   │       └── gburd/
│   │           ├── hosts/
│   │           │   ├── floki.nix   # NixOS-specific config
│   │           │   └── arnold.nix  # Fedora-specific config
│   │           └── default.nix
│   └── default.nix
├── pkgs/                  # Custom packages
│   ├── mailspring/        # Patched Mailspring
│   └── (others)
└── overlays/              # Package overlays
```

## Rollback Procedure

### Rollback to Previous Generation
```bash
# NixOS
sudo nixos-rebuild switch --rollback

# Home Manager
home-manager switch --switch-generation <prev-gen>
```

### Rollback to KNOWN_WORKING (62bfa8c)
```bash
git checkout 62bfa8c
nix flake lock
sudo nixos-rebuild switch --flake .#floki
home-manager switch -b backup --flake .#gburd@floki
```

### Rollback to Pre-Modernization
```bash
git checkout pre-modernization
nix flake lock
sudo nixos-rebuild switch --flake .#floki
home-manager switch -b backup --flake .#gburd@floki
```

## Known Issues / TODO

1. **Orion Package**: Needs actual download URL and hash from Kagi website
2. **Mailspring Patch**: Needs testing to verify Message-ID randomization works
3. **Arnold Directories**: Old arnold-config/, arnold-nix-setup/, arnold-nvim/ directories still present (will remove after full verification)

## Breaking Changes

- Moved from home-manager release-24.11 to release-25.11
- Changed stateVersion from "24.11" to "25.11"
- Restructured Neovim configuration (old `neovim.nix` removed)
- Moved claude-code from shell.nix to home-manager mixin

## Testing Checklist

- [x] Flake updates successfully
- [x] NixOS builds without errors
- [x] Home-manager builds for floki
- [x] Home-manager builds for arnold
- [x] Neovim modular structure in place
- [x] Claude Code mixin configured
- [x] Taskfile commands work
- [ ] Full system activation (pending user confirmation)
- [ ] Neovim LSPs verified
- [ ] Claude Code MCP servers verified
- [ ] Chromium profile preserved
- [ ] Mailspring Message-ID patch verified
