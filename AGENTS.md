# nix-config — NixOS & Home Manager Configuration

## Purpose
Multi-host NixOS, nix-darwin, and Home Manager configuration for workstations (floki, meh), servers, and macOS (80a99738d7e2). Manages system packages, services, desktop environments, and AI agent tooling.

## Build & Test
```bash
# NixOS rebuild
sudo nixos-rebuild switch --flake ~/ws/nix-config

# Home Manager only
home-manager switch --flake ~/ws/nix-config

# Darwin (host attr is "aws"; real hostname is 80a99738d7e2)
darwin-rebuild build --flake .#aws

# Check flake
nix flake check

# Format
nix fmt
```

## Architecture
```
flake.nix                          # Entry point, all hosts defined here
├── modules/home-manager/ai/       # AI agent modules (bedrock, mcps, steering, skills)
├── home-manager/
│   ├── _mixins/console/           # CLI tools, editors, AI config
│   ├── _mixins/desktop/           # GUI apps
│   └── _mixins/users/             # Per-user overrides
├── nixos/
│   ├── _mixins/                   # Services, hardware, desktop
│   ├── workstation/               # Per-host configs (floki, meh)
│   └── server/                    # Server configs
├── darwin/                        # macOS-specific
├── pkgs/                          # Custom packages (memelord, etc.)
└── scripts/                       # Utility scripts
```

## AI Agent Modules (`modules/home-manager/ai/`)
- `bedrock.nix` — Amazon Bedrock provider config for Claude Code
- `mcps.nix` — MCP server deployment (GitHub, memelord, llms-docs) to Claude/Kiro/default
- `steering.nix` — Deploys steering files to ~/.kiro/steering/ and optionally maki
- `skills.nix` — Deploys skills to ~/.kiro/skills/ and ~/.claude/skills/

Enable in `home-manager/_mixins/console/ai/default.nix`.

## Hosts
| Host | Type | OS | Desktop |
|------|------|----|---------|
| floki | workstation | NixOS | GNOME |
| meh | workstation | NixOS | GNOME |
| arnold | workstation | NixOS | none |
| 80a99738d7e2 | laptop | macOS | — |

## Notes
- Secrets managed via sops-nix (`.sops.yaml`)
- Nix formatter: nixpkgs-fmt + statix + deadnix
- State versions are intentionally not uniform:
  - NixOS / Home Manager hosts: `25.11` (the `stateVersion` in `flake.nix`)
  - nix-darwin system (`aws`): `4` (nix-darwin uses its own integer series)
  - Darwin Home Manager: `24.11`, pinned deliberately because this host runs
    the HM 26.05 module against rolling (unstable) darwin pkgs; the release
    check is disabled (`home.enableNixpkgsReleaseCheck = false`) for that pairing.
  Do not "align" these; they track different upstreams.
