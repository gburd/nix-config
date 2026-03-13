#!/usr/bin/env bash
# Test script to verify tea CLI installation

set -euo pipefail

echo "🍵 Testing tea CLI for Codeberg"
echo ""

# Check if tea is installed
if command -v tea >/dev/null 2>&1; then
    echo "✓ tea is installed"
    echo "  Version: $(tea --version 2>&1 | head -1)"
    echo "  Location: $(command -v tea)"
else
    echo "✗ tea is not installed"
    echo "  Run: home-manager switch --flake ."
    exit 1
fi

echo ""

# Check for existing logins
echo "📝 Configured Logins:"
if tea login list 2>/dev/null | grep -q .; then
    tea login list | sed 's/^/  /'
else
    echo "  ℹ No logins configured yet"
    echo ""
    echo "  To add Codeberg:"
    echo "    tea login add"
    echo "    URL: https://codeberg.org"
    echo ""
    echo "  Generate token at:"
    echo "    https://codeberg.org/user/settings/applications"
fi

echo ""
echo "💡 Quick Start:"
echo "  # Login to Codeberg"
echo "    tea login add"
echo ""
echo "  # Clone a repo"
echo "    tea repo clone owner/repo"
echo ""
echo "  # List your repos"
echo "    tea repos ls"
echo ""
echo "  # Create an issue"
echo "    tea issues create --title \"Issue title\""
echo ""
echo "📚 Full documentation: docs/CODEBERG_TEA_CLI.md"
