#!/usr/bin/env bash
# Test script to verify Rust development tools installation

set -euo pipefail

echo "🦀 Testing Rust Development Tools"
echo ""

# Core toolchain
echo "📦 Core Toolchain:"
tools=(rustup rustc cargo rust-analyzer)
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$("$tool" --version 2>&1 | head -1)
        echo "  ✓ $tool"
        echo "    $version"
    else
        echo "  ✗ $tool NOT FOUND"
    fi
done

echo ""

# Coverage tools
echo "🎯 Coverage Tools:"
coverage_tools=(cargo-llvm-cov cargo-tarpaulin)
for tool in "${coverage_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$("$tool" --version 2>&1 | head -1)
        echo "  ✓ $tool"
        echo "    $version"
    else
        echo "  ✗ $tool NOT FOUND"
    fi
done

echo ""

# Check rustup toolchains
if command -v rustup >/dev/null 2>&1; then
    echo "🔧 Rustup Toolchains:"
    if rustup toolchain list 2>/dev/null | grep -q .; then
        rustup toolchain list | sed 's/^/  /'
    else
        echo "  ℹ No toolchains installed yet"
        echo "  Run: rustup default stable"
    fi
    echo ""
fi

# Check cargo home
echo "📁 Cargo Configuration:"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
echo "  CARGO_HOME: $cargo_home"
if [ -d "$cargo_home" ]; then
    echo "  ✓ Directory exists"
    if [ -d "$cargo_home/bin" ]; then
        bin_count=$(find "$cargo_home/bin" -type f 2>/dev/null | wc -l)
        echo "  Installed binaries: $bin_count"
    fi
else
    echo "  ℹ Directory will be created on first use"
fi

echo ""

# Environment check
echo "🌍 Environment:"
echo "  PATH includes ~/.cargo/bin: $(echo "$PATH" | grep -q '.cargo/bin' && echo "✓" || echo "✗")"
echo "  CARGO_TERM_COLOR: ${CARGO_TERM_COLOR:-<not set>}"

echo ""

# Quick start guide
echo "💡 Quick Start:"
echo "  # Initialize rustup with stable toolchain:"
echo "    rustup default stable"
echo ""
echo "  # Install additional components:"
echo "    rustup component add clippy rustfmt rust-src"
echo ""
echo "  # Create a new project:"
echo "    cargo new my-project && cd my-project"
echo ""
echo "  # Run tests with coverage:"
echo "    cargo llvm-cov"
echo ""
echo "  # Generate HTML coverage report:"
echo "    cargo llvm-cov --html"
echo ""
echo "📚 Full documentation: docs/RUST_DEVELOPMENT.md"
