#!/usr/bin/env bash
# Helper script to fetch latest SHAs for GitHub Actions
#
# Notes on Node.js runtime:
#   GitHub will force JS actions declared as `node20` to run on Node 24
#   starting 2026-06-02, and Node 20 will be removed 2026-09-16.
#
#   Action statuses (last reviewed 2026-05-25):
#     actions/checkout@v6                          → node24  (Node 24 ✓)
#     DeterminateSystems/nix-installer-action@v22  → node24  (Node 24 ✓)
#     DeterminateSystems/magic-nix-cache-action@v13 → node20  (no newer release)
#     DeterminateSystems/flake-checker-action@v12  → node20  (no newer release)
#     DeterminateSystems/update-flake-lock@v28     → composite (transitive
#       deps DamianReeves/write-file-action, juliangruber/read-file-action,
#       pedrolamas/handlebars-action, peter-evans/create-pull-request are
#       still node20 inside the composite; will follow upstream)
#     astro/deadnix-action@v1                      → composite

set -euo pipefail

echo "Fetching latest SHAs for GitHub Actions..."
echo ""

# List of actions with their versions
actions=(
  "actions/checkout:v6"
  "DeterminateSystems/nix-installer-action:v22"
  "DeterminateSystems/magic-nix-cache-action:v13"
  "DeterminateSystems/flake-checker-action:v12"
  "DeterminateSystems/update-flake-lock:v28"
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
echo "DeterminateSystems/nix-installer-action@ef8a148080ab6020fd15196c2084a2eea5ff2d25  # v22"
echo "DeterminateSystems/magic-nix-cache-action@565684385bcd71bad329742eefe8d12f2e765b39  # v13"
echo "DeterminateSystems/flake-checker-action@3164002371bc90729c68af0e24d5aacf20d7c9f6  # v12"
echo "DeterminateSystems/update-flake-lock@834c491b2ece4de0bbd00d85214bb5e83b4da5c6  # v28"
echo "astro/deadnix-action@7318ac45eea03ff5785a809e13e6f2c2f2e0cf67  # v1"
