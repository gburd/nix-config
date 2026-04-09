#!/usr/bin/env bash
set -euo pipefail

# Add additional MCP servers to Claude Code configuration
# The home-manager module only supports: llms-docs, github, memelord
# This script adds: sequential-thinking, git, brave-search, postgres, sqlite

MCP_CONFIG="$HOME/.config/claude-code/mcp.json"
BACKUP_DIR="$HOME/.config/claude-code/backups"

echo "=== Adding Additional MCP Servers to Claude Code ==="
echo ""

# Check if mcp.json exists
if [ ! -f "$MCP_CONFIG" ]; then
  echo "Error: $MCP_CONFIG not found"
  echo "Run 'home-manager switch' first to create the base configuration"
  exit 1
fi

# Create backup
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/mcp.json.$(date +%Y%m%d_%H%M%S)"
cp "$MCP_CONFIG" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Read current config
CURRENT_CONFIG=$(cat "$MCP_CONFIG")

# Check if servers already exist
if echo "$CURRENT_CONFIG" | jq -e '.mcpServers["sequential-thinking"]' >/dev/null 2>&1; then
  echo "⚠ MCP servers already configured. Skipping."
  echo ""
  echo "Current servers:"
  jq -r '.mcpServers | keys[]' "$MCP_CONFIG" | sed 's/^/  - /'
  exit 0
fi

echo "Adding MCP servers:"
echo "  - sequential-thinking (complex reasoning)"
echo "  - git (Git operations)"
echo "  - brave-search (web search - requires BRAVE_API_KEY)"
echo "  - postgres (PostgreSQL access - requires DATABASE_URL)"
echo "  - sqlite (SQLite access)"
echo ""

# Add new servers using jq
jq '.mcpServers += {
  "sequential-thinking": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
  },
  "git": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-git"]
  },
  "brave-search": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-brave-search"],
    "env": {
      "BRAVE_API_KEY": ""
    }
  },
  "postgres": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres"],
    "env": {
      "DATABASE_URL": ""
    }
  },
  "sqlite": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sqlite"]
  }
}' "$MCP_CONFIG" > "$MCP_CONFIG.tmp"

# Replace original file
mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"

echo "✓ MCP servers added successfully"
echo ""
echo "Current servers:"
jq -r '.mcpServers | keys[]' "$MCP_CONFIG" | sed 's/^/  - /'
echo ""

# Check for required environment variables
echo "=== Configuration Notes ==="
echo ""

if ! grep -q "BRAVE_API_KEY" "$HOME/.bashrc" 2>/dev/null && \
   ! grep -q "BRAVE_API_KEY" "$HOME/.zshrc" 2>/dev/null; then
  echo "⚠ Brave Search requires BRAVE_API_KEY"
  echo "  Get API key from: https://brave.com/search/api/"
  echo "  Add to shell config:"
  echo "    export BRAVE_API_KEY=\"your_key_here\""
  echo ""
fi

if ! grep -q "DATABASE_URL" "$HOME/.bashrc" 2>/dev/null && \
   ! grep -q "DATABASE_URL" "$HOME/.zshrc" 2>/dev/null; then
  echo "⚠ PostgreSQL MCP requires DATABASE_URL"
  echo "  Example for RA testing:"
  echo "    export DATABASE_URL=\"postgresql://user:pass@localhost:5432/ra_test\""
  echo ""
fi

echo "To manually edit MCP configuration:"
echo "  \$EDITOR ~/.config/claude-code/mcp.json"
echo ""
echo "To restore from backup:"
echo "  cp $BACKUP_FILE ~/.config/claude-code/mcp.json"
echo ""
echo "Done!"
