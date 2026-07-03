{ config, lib, pkgs, ... }:
# agent-sandbox — run a coding agent (or any command) in an isolated
# environment so a rogue/confused agent can't touch things it shouldn't
# (SSH keys, sops secrets, ~/.aws, the Bedrock bearer token, other projects,
# the rest of $HOME) and a runaway process it spawns is memory-capped and
# killed in isolation (not cascading to your terminal windows).
#
# Three tiers, pick with --tier (default: bwrap):
#   bwrap    (default) — bubblewrap namespace sandbox. Near-zero overhead.
#            Binds ONLY: cwd (rw), the agent's config read-only, loopback for
#            the LiteLLM gateway. $HOME/.ssh, secrets, ~/.aws, ~/ws siblings
#            are NOT visible. Wrapped in a memory-capped systemd scope.
#   docker   — run inside a container (stronger namespace isolation; needs a
#            base image with the toolchain). For untrusted work.
#   microvm  — full QEMU microVM (hardware-virtualised kernel isolation);
#            heaviest, for maximum paranoia. Requires microvm.nix (documented,
#            not auto-enabled).
#
# Usage:
#   agent-sandbox claude              # bwrap-isolated claude in $PWD
#   agent-sandbox --tier docker pi    # docker-isolated pi
#   agent-sandbox --mem 8G codex      # cap the sandbox at 8G RAM
#   agent-sandbox -- bash             # isolated shell to inspect the sandbox
let
  cfg = config.programs.ai.sandbox;
  inherit (lib) mkEnableOption mkOption mkIf types;

  # The bubblewrap sandbox launcher. Everything the agent legitimately needs
  # is bound; everything sensitive is omitted. A memory-capped transient
  # systemd scope wraps it so a runaway child is confined + killed alone.
  agent-sandbox = pkgs.writeShellApplication {
    name = "agent-sandbox";
    runtimeInputs = [ pkgs.bubblewrap pkgs.systemd pkgs.coreutils pkgs.docker_29 ];
    text = ''
      set -euo pipefail
      TIER=bwrap
      MEM="${cfg.defaultMemMax}"
      while [ $# -gt 0 ]; do
        case "$1" in
          --tier) TIER="$2"; shift 2 ;;
          --mem)  MEM="$2"; shift 2 ;;
          --)     shift; break ;;
          -*)     echo "agent-sandbox: unknown flag $1" >&2; exit 2 ;;
          *)      break ;;
        esac
      done
      [ $# -gt 0 ] || { echo "usage: agent-sandbox [--tier bwrap|docker|microvm] [--mem 8G] <cmd> [args...]" >&2; exit 2; }

      PROJECT="$PWD"
      HOME_DIR="''${HOME}"

      case "$TIER" in
        bwrap)
          # Memory-capped transient scope: a runaway process inside is killed
          # alone by the kernel (MemoryMax breach), never pressuring the
          # session / sibling terminals.
          exec systemd-run --user --scope --quiet \
            -p "MemoryMax=$MEM" -p "MemorySwapMax=$MEM" \
            -- bwrap \
              --unshare-all --share-net \
              --die-with-parent \
              --proc /proc --dev /dev --tmpfs /tmp \
              --ro-bind /nix /nix \
              --ro-bind /etc /etc \
              --ro-bind /run/current-system /run/current-system \
              --bind "$PROJECT" "$PROJECT" \
              --chdir "$PROJECT" \
              `# Agent config: read-only so the agent reads steering/skills/keys` \
              --ro-bind-try "$HOME_DIR/.claude" "$HOME_DIR/.claude" \
              --ro-bind-try "$HOME_DIR/.kiro" "$HOME_DIR/.kiro" \
              --ro-bind-try "$HOME_DIR/.codex" "$HOME_DIR/.codex" \
              --ro-bind-try "$HOME_DIR/.config/mcp" "$HOME_DIR/.config/mcp" \
              --ro-bind-try "$HOME_DIR/.config/litellm/keys" "$HOME_DIR/.config/litellm/keys" \
              --ro-bind-try "$HOME_DIR/.config/fish" "$HOME_DIR/.config/fish" \
              --ro-bind-try "$HOME_DIR/.gitconfig" "$HOME_DIR/.gitconfig" \
              `# EXPLICITLY NOT bound: ~/.ssh, ~/.aws, ~/.config/sops*, the` \
              `# bearer token, ~/.gnupg, other ~/ws projects.` \
              --setenv HOME "$HOME_DIR" \
              --setenv TERM "''${TERM:-xterm-256color}" \
              --setenv PATH "$PATH" \
              "$@"
          ;;
        docker)
          # Stronger isolation. Mount only the project; give loopback access
          # to the host LiteLLM gateway via host networking, but nothing else
          # from $HOME. Uses the configured base image.
          exec docker run --rm -it \
            --network host \
            --memory "$MEM" \
            -v "$PROJECT":"$PROJECT":rw \
            -v "$HOME_DIR/.config/litellm/keys":/keys:ro \
            -w "$PROJECT" \
            -e HOME="$PROJECT" \
            "${cfg.dockerImage}" "$@"
          ;;
        microvm)
          echo "agent-sandbox: microvm tier is documented but not auto-provisioned." >&2
          echo "See modules/home-manager/ai/agent-sandbox.nix header + docs for the" >&2
          echo "microvm.nix setup (full QEMU/Firecracker kernel isolation)." >&2
          exit 3
          ;;
        *) echo "agent-sandbox: unknown tier '$TIER'" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  options.programs.ai.sandbox = {
    enable = mkEnableOption "agent-sandbox: run agents isolated (bwrap/docker/microvm)";
    defaultMemMax = mkOption {
      type = types.str;
      default = "12G";
      description = "Default MemoryMax for the sandbox scope (kernel kills a runaway inside it, alone).";
    };
    dockerImage = mkOption {
      type = types.str;
      default = "nixos/nix:latest";
      description = "Base image for the docker tier (must carry git + a shell + the agent, or mount them).";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ agent-sandbox ];
  };
}
