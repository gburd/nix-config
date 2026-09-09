#!/usr/bin/env bash
set -euo pipefail

# Deploy one or more NixOS hosts remotely.
#   ./deploy.sh host1[,host2,...] [extra nixos-rebuild args]
# Forwards the SSH agent so the build/target host can reach private inputs.
export NIX_SSHOPTS="-A"

hosts="${1:-}"
if [ -z "$hosts" ]; then
    echo "Usage: $0 host1[,host2,...] [extra nixos-rebuild args]" >&2
    exit 2
fi
shift

IFS=',' read -ra host_list <<<"$hosts"
for host in "${host_list[@]}"; do
    nixos-rebuild switch \
        --flake ".#${host}" \
        --target-host "$host" \
        --use-remote-sudo \
        --use-substitutes \
        "$@"
done
