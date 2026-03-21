#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Validating Nix configuration..."

# Phase 1: Syntax checks
echo "→ Checking syntax with nix fmt..."
nix fmt -- --check . || {
  echo "❌ Formatting issues found. Run 'nix fmt' to fix."
  exit 1
}

# Phase 2: Static analysis
echo "→ Running statix (anti-patterns)..."
nix run nixpkgs#statix -- check . || {
  echo "❌ Statix found issues. Review and fix."
  exit 1
}

# Phase 3: Evaluation checks
echo "→ Evaluating flake..."
nix flake check --no-build || {
  echo "❌ Flake evaluation failed. Check error messages above."
  exit 1
}

# Phase 4: Build dry-runs
echo "→ Testing NixOS config (floki)..."
nix build .#nixosConfigurations.floki.config.system.build.toplevel --dry-run || {
  echo "❌ NixOS config build failed."
  exit 1
}

echo "→ Testing home-manager config (gburd@floki)..."
nix build .#homeConfigurations."gburd@floki".activationPackage --dry-run || {
  echo "❌ Home-manager config build failed."
  exit 1
}

echo "✅ All validations passed!"
