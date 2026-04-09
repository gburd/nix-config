# Claude Code Optimization - Quick Start Guide

**Status**: ✅ NixOS configuration applied, Home-manager in progress

---

## What Was Fixed

### ✅ Completed Successfully
1. **Sops-nix Issue Fixed**
   - Updated floki's age key in `.sops.yaml`
   - Re-encrypted secrets
   - `nixos-rebuild switch` now exits with code 0 ✅

2. **Configuration Files Updated**
   - Rust tools added to `home-manager/_mixins/languages/rust.nix`
   - Development tools added to `home-manager/_mixins/console/claude-code/default.nix`
   - MCP configuration updated in `home-manager/_mixins/console/ai/default.nix`

### ⏳ Pending Verification
1. **Tool Installation**
   - Tools defined in configuration but may not be in PATH yet
   - May require shell reload or re-login

2. **MCP Servers**
   - Core servers (github, memelord, llms-docs) work via home-manager
   - Additional servers need manual configuration

---

## Immediate Next Steps

### 1. Add MCP Servers Manually
The home-manager AI module only supports predefined MCP servers. Additional servers must be added manually:

```bash
# Run the helper script to add:
# - sequential-thinking (complex reasoning)
# - git (Git history analysis)
# - brave-search (web research)
# - postgres (PostgreSQL access)
# - sqlite (SQLite access)
~/ws/nix-config/scripts/add-mcp-servers.sh
```

### 2. Verify Tool Installation
```bash
# Check if tools are available
which cargo-nextest ruff pyright ast-grep rpg-cli

# If missing, try reloading shell
exec $SHELL
# OR
source ~/.bashrc  # or ~/.zshrc

# Run health check
~/ws/nix-config/scripts/claude-health-check.sh
```

### 3. If Tools Still Missing
```bash
# Check home-manager generation
home-manager generations | head -5

# Verify packages in profile
ls ~/.nix-profile/bin/ | grep -E "(cargo-nextest|ruff|ast-grep)"

# If still not there, rebuild
home-manager switch --flake ~/ws/nix-config#gburd@floki
```

---

## Configuration Files Changed

1. **`home-manager/_mixins/languages/rust.nix`**
   - Added: cargo-nextest, cargo-audit, cargo-deny, cargo-watch, cargo-expand, cargo-flamegraph, ast-grep

2. **`home-manager/_mixins/console/claude-code/default.nix`**
   - Python: Replaced pylint → ruff + uv + pyright
   - SQL: postgresql_17, sqlite, sqlfluff, pgcli
   - Rust: rpg-cli
   - CI/CD: actionlint
   - LSPs: bash-language-server, typescript-language-server, nil
   - TypeScript: typescript, prettier
   - Nix: nixpkgs-fmt, alejandra, statix, deadnix, nix-tree, nix-diff

3. **`home-manager/_mixins/console/ai/default.nix`**
   - Documented manual MCP server configuration
   - Core servers remain: llms-docs, github, memelord

4. **`.sops.yaml`** + secrets files
   - Updated floki age key
   - Re-encrypted secrets

5. **New Scripts**
   - `scripts/claude-health-check.sh` - Verify tool installation
   - `scripts/add-mcp-servers.sh` - Add additional MCP servers

---

## Expected Tool Count

After successful installation, you should have:
- **Rust**: 7 cargo tools + ast-grep
- **Python**: uv, ruff, pyright, pytest
- **SQL**: psql, sqlite3, sqlfluff, pgcli
- **Nix**: 6 development tools
- **LSPs**: 6 language servers
- **MCP**: 8 servers (3 via home-manager + 5 manual)

---

## Troubleshooting

### Tools Not in PATH
```bash
# 1. Check if tools exist in nix store
nix-store --query --references ~/.nix-profile | xargs -I {} ls {}/bin 2>/dev/null | grep cargo-nextest

# 2. Check home-manager build log
home-manager switch --flake ~/ws/nix-config#gburd@floki --show-trace

# 3. Verify package names are correct
nix search nixpkgs cargo-nextest
```

### MCP Servers Not Working
```bash
# 1. Check MCP configuration
cat ~/.config/claude-code/mcp.json

# 2. Add servers manually
~/ws/nix-config/scripts/add-mcp-servers.sh

# 3. Verify server commands work
npx -y @modelcontextprotocol/server-sequential-thinking --help
```

### Sops-nix Issues
```bash
# 1. Verify age key matches
sudo ssh-to-age < /persist/etc/ssh/ssh_host_ed25519_key.pub
# Should output: age1z2x0g05q2erpux006vwhul70d8akj9avrj67s9p27fm4ce32ly8qt8nllz

# 2. Check .sops.yaml has correct key
grep "floki" .sops.yaml

# 3. Re-encrypt if needed
sops updatekeys nixos/workstation/floki/secrets.yaml
```

---

## Verification Commands

Once tools are in PATH:

```bash
# Test Rust tools
cargo-nextest --version
cargo audit --version
cargo deny --version
ast-grep --version

# Test Python tools
ruff --version
pyright --version
uv --version

# Test SQL tools
psql --version
sqlite3 --version
sqlfluff --version

# Test Nix tools
alejandra --version
statix --version
deadnix --version

# Test MCP configuration
jq '.mcpServers | keys' ~/.config/claude-code/mcp.json
```

---

## Known Issues

1. **Home-manager packages not immediately available**
   - May require shell reload or re-login
   - Check with: `which cargo-nextest`

2. **Some nixpkgs packages may not exist**
   - If a package fails to build, it might not be in nixpkgs yet
   - Check with: `nix search nixpkgs <package-name>`

3. **MCP servers require manual configuration**
   - Home-manager module doesn't support arbitrary server names
   - Use provided script: `scripts/add-mcp-servers.sh`

4. **Environment variables needed**
   - Brave Search: `BRAVE_API_KEY`
   - PostgreSQL MCP: `DATABASE_URL`

---

## Success Criteria

✅ You're done when:
1. `nixos-rebuild switch` exits with code 0 (DONE ✅)
2. `home-manager switch` exits with code 0 (DONE ✅)
3. Health check shows most tools installed
4. MCP servers listed in `~/.config/claude-code/mcp.json`
5. Tools available in PATH: `which cargo-nextest ruff pyright`

---

## Getting Help

If issues persist:
1. Check full build log: `home-manager switch --show-trace`
2. Verify nixpkgs version: `nix flake metadata`
3. Review summary: `CLAUDE-CODE-OPTIMIZATION-SUMMARY.md`
4. Check configuration: `git diff HEAD~5` to see recent changes

---

## Rollback

If needed:
```bash
# Git rollback
cd ~/ws/nix-config
git status
git restore <file>

# Nix rollback
home-manager generations
# Activate previous generation if needed
```

---

Last Updated: 2026-04-08
