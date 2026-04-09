#!/usr/bin/env bash
set -euo pipefail

echo "=== Claude Code Configuration Health Check ==="
echo ""

# Check critical tools
echo "## Essential Tools"
for tool in cargo-nextest cargo-audit cargo-deny ast-grep ruff pyright actionlint uv rpg-cli; do
  if command -v "$tool" &>/dev/null; then
    version=$(command -v "$tool" | xargs basename 2>/dev/null || echo "")
    echo "✓ $tool: $(command -v "$tool")"
  else
    echo "✗ $tool: MISSING"
  fi
done
echo ""

# Check Rust tools
echo "## Rust Ecosystem"
for tool in cargo rustc rust-analyzer cargo-watch cargo-expand cargo-flamegraph; do
  if command -v "$tool" &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ $tool: MISSING"
  fi
done
echo ""

# Check Python tools
echo "## Python Ecosystem"
for tool in python3 uv ruff pyright pytest; do
  if command -v "$tool" &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ $tool: MISSING"
  fi
done
echo ""

# Check SQL/Database tools
echo "## Database Tools"
for tool in psql sqlite3 sqlfluff pgcli; do
  if command -v "$tool" &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ $tool: MISSING"
  fi
done
echo ""

# Check LSPs
echo "## Language Servers"
for tool in rust-analyzer pyright bash-language-server typescript-language-server nil; do
  if command -v "$tool" &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ $tool: MISSING"
  fi
done
echo ""

# Check Nix tools
echo "## Nix Development"
for tool in nixpkgs-fmt alejandra statix deadnix nix-tree nix-diff; do
  if command -v "$tool" &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ $tool: MISSING"
  fi
done
echo ""

# Check MCP servers
echo "## MCP Configuration"
if [ -f "$HOME/.config/claude-code/mcp.json" ]; then
  server_count=$(jq '.mcpServers | length' ~/.config/claude-code/mcp.json 2>/dev/null || echo "0")
  echo "✓ MCP servers configured: $server_count"

  # List MCP servers
  if command -v jq &>/dev/null; then
    echo "  Servers:"
    jq -r '.mcpServers | keys[]' ~/.config/claude-code/mcp.json 2>/dev/null | sed 's/^/    - /'
  fi
else
  echo "✗ MCP config missing"
fi
echo ""

# Check nix-config status
echo "## Nix Configuration"
if [ -d "$HOME/ws/nix-config" ]; then
  cd ~/ws/nix-config
  if git status --porcelain | grep -q '^??'; then
    echo "⚠ Untracked files in nix-config:"
    git status --porcelain | grep '^??' | sed 's/^/  /'
  elif git status --porcelain | grep -q '^[MADRCU]'; then
    echo "⚠ Modified files in nix-config:"
    git status --porcelain | grep '^[MADRCU]' | sed 's/^/  /'
  else
    echo "✓ Nix config clean"
  fi
else
  echo "✗ Nix config directory missing"
fi
echo ""

echo "=== Health Check Complete ===" echo ""
echo "Run 'home-manager switch --flake ~/ws/nix-config' to apply changes"
