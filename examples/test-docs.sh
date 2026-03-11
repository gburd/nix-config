#!/usr/bin/env bash
# Quick test to verify documentation and debug tools are available

set -euo pipefail

echo "📚 Testing Documentation Setup..."
echo ""

# Test man pages
echo "✓ Testing man pages:"
if man -w malloc >/dev/null 2>&1; then
    echo "  ✓ man malloc (found at: $(man -w malloc))"
else
    echo "  ✗ man malloc NOT FOUND"
fi

if man -w pthread_create >/dev/null 2>&1; then
    echo "  ✓ man pthread_create (found)"
else
    echo "  ✗ man pthread_create NOT FOUND (install man-pages-posix)"
fi

echo ""
echo "✓ Testing man search index:"
if man -k malloc | grep -q malloc; then
    echo "  ✓ man -k malloc works ($(man -k malloc | wc -l) results)"
else
    echo "  ✗ man search index not available"
fi

echo ""
echo "🐛 Testing Debug Tools:"
for tool in gdb lldb valgrind strace; do
    if command -v $tool >/dev/null 2>&1; then
        echo "  ✓ $tool ($(command -v $tool))"
    else
        echo "  ✗ $tool NOT FOUND"
    fi
done

echo ""
echo "📖 Useful man pages to try:"
echo "  man 2 open      # File operations"
echo "  man 3 malloc    # Memory allocation"
echo "  man 3 pthread   # POSIX threads"
echo "  man 7 signal    # Signal handling"
echo ""
echo "🔍 Search for man pages:"
echo "  man -k network  # Search for network-related pages"
echo "  man -k socket   # Search for socket programming"
