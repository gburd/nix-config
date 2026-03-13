#!/usr/bin/env bash
# Helper script to fetch latest SHAs for GitHub Actions

set -euo pipefail

echo "Fetching latest SHAs for GitHub Actions..."
echo ""

# List of actions with their versions
actions=(
  "actions/checkout:v6"
  "DeterminateSystems/nix-installer-action:v21"
  "DeterminateSystems/magic-nix-cache-action:v13"
  "DeterminateSystems/flake-checker-action:v12"
  "DeterminateSystems/update-flake-lock:v21"
  "astro/deadnix-action:v1"
)

for action in "${actions[@]}"; do
  repo="${action%:*}"
  version="${action##*:}"

  echo "Fetching SHA for ${repo}@${version}..."
  sha=$(gh api "repos/${repo}/git/refs/tags/${version}" --jq '.object.sha' 2>/dev/null || echo "Failed to fetch")
  echo "${repo}@${sha}  # ${version}"
  echo ""
done

echo "Current SHAs (as of $(date +%Y-%m-%d)):"
echo ""
echo "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6"
echo "DeterminateSystems/nix-installer-action@c5a866b6ab867e88becbed4467b93592bce69f8a  # v21"
echo "DeterminateSystems/magic-nix-cache-action@565684385bcd71bad329742eefe8d12f2e765b39  # v13"
echo "DeterminateSystems/flake-checker-action@3164002371bc90729c68af0e24d5aacf20d7c9f6  # v12"
echo "DeterminateSystems/update-flake-lock@a3ccb8f59719c48d6423e97744560221bcf7a3fa  # v21"
echo "astro/deadnix-action@7318ac45eea03ff5785a809e13e6f2c2f2e0cf67  # v1"
