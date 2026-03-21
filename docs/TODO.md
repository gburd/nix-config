# Outstanding TODOs

Last updated: 2026-03-21

## Critical (Blocking Functionality)

### Secrets Management on macOS/Android
- **Location**: android/default.nix:76, darwin/default.nix:85
- **Status**: Completely unimplemented
- **Impact**: Cannot manage deployment secrets on non-NixOS systems
- **Options**: agenix or sops-nix
- **Priority**: High if deploying to macOS/Android

## Important (Incomplete Features)

### Mailspring Message-ID Patch
- **Location**: pkgs/mailspring/default.nix:1-13
- **Status**: Entire feature unimplemented
- **Details**: Requires patching `app/src/flux/stores/draft-factory.ts` to randomize Message-ID headers
- **Priority**: Medium if using Mailspring for privacy-sensitive email

### Docker Rootless Mode
- **Location**: nixos/_mixins/virt/docker.nix:14-17
- **Status**: Configuration commented out
- **Details**: `docker.rootless.enable` and `setSocketVariable` disabled
- **Priority**: Low unless you need rootless containers

### Dynamic Containerization Tools
- **Location**: nixos/_mixins/virt/default.nix:9-10
- **Status**: Only Docker hardcoded; podman commented out
- **Goal**: Make containerization tools dynamic via parameter
- **Priority**: Low - current setup works

### Network Share Mounting Optimization
- **Location**: nixos/_mixins/network-shares/ds418-smb.nix:25
- **Status**: TODO suggests using `systemd.mounts` instead of current
- **Priority**: Low - current implementation functional

## Configuration Issues

### SSH Whitelist Incomplete
- **Location**: nixos/_mixins/services/openssh.nix:28-32
- **Status**: Only three placeholder CIDR blocks defined
- **Priority**: Medium - verify network ranges for sshguard

### GPG Configuration Unclear
- **Location**: home-manager/_mixins/cli/gpg.nix:30, 33
- **Questions**:
  - Line 30: Use `gnupg` vs `gpg-agent`?
  - Line 33: Enable SSH key 149F16412997785363112F3DBD713BC91D51B831?
- **Priority**: Low unless GPG issues occur

### VSCode Extension Manifest Issues
- **Location**: nixos/_mixins/desktop/vscode.nix:333-335, 361-362
- **Status**: Workarounds in place for rst, mdx, mdx-preview extensions
- **Priority**: Low - extensions work via hardcoded method

### Qt Theme Session Setup
- **Location**: nixos/_mixins/desktop/qt-style.nix:8
- **Status**: TODO to move from environment to user-session
- **Priority**: Low - current force works

## Documentation & Maintenance

### NixOS Registry Error
- **Location**: nixos/_mixins/users/nixos/default.nix:102-103
- **Status**: `nix.registry.nixpkgs.to.path` error noted
- **Priority**: Low - doesn't block functionality

### LLDB Script Incomplete
- **Location**: home-manager/_mixins/console/lldb/lldbinit:91
- **Status**: "Iterate through list elements" not implemented
- **Priority**: Low unless using LLDB heavily

### Flake Inputs Review
- **Location**: flake.nix:66
- **Status**: TODO marker - inputs after line 66 need review/audit
- **Priority**: Low - periodic maintenance

## Disabled Configurations

### Darwin Gregory Burd Build
- **Location**: darwin/_mixins/users/gregburd/default.nix:3-8
- **Status**: Temporarily disabled modules (auth0, direnv, kubectl, spotify)
- **Reason**: Network issues downloading Go deps
- **Priority**: Only relevant if building for macOS gregburd user

## Completed

- ✅ Lyrics package removed (broken, unused) - 2026-03-21
- ✅ Chaotic-nyx module removed (deprecated 2025-12-08) - 2026-03-21
- ✅ 1Password extension updated from stable to Beta - 2026-03-21
