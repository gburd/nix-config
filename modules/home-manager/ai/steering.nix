{ config, lib, ... }:
let
  cfg = config.programs.ai.steering;
  inherit (lib) mkEnableOption mkOption types;

  steeringFiles = {
    "coding-standards.md" = ./files/steering/coding-standards.md;
    "rust-conventions.md" = ./files/steering/rust-conventions.md;
    "workflow.md" = ./files/steering/workflow.md;
    "tools.md" = ./files/steering/tools.md;
    "aws-builder.md" = ./files/steering/aws-builder.md;
    "mcp-config.md" = ./files/steering/mcp-config.md;
  };
in
{
  options.programs.ai.steering = {
    enable = mkEnableOption "Deploy shared steering/instruction files for AI agents";

    targets = {
      kiro = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy to ~/.kiro/steering/";
      };
      claude = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy CLAUDE.md redirect to ~/.claude/CLAUDE.md";
      };
      maki = mkOption {
        type = types.bool;
        default = false;
        description = "Deploy to ~/.config/maki/instructions.md";
      };
    };

    extraFiles = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = "Additional steering files to deploy (name -> path)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mkMerge [
      # Kiro steering files
      (lib.mkIf cfg.targets.kiro (
        lib.mapAttrs'
          (name: path: lib.nameValuePair ".kiro/steering/${name}" { source = path; })
          (steeringFiles // cfg.extraFiles)
      ))

      # Claude global CLAUDE.md (thin redirect to AGENTS.md)
      (lib.mkIf cfg.targets.claude {
        ".claude/CLAUDE.md".text = ''
          See AGENTS.md for all project instructions.
          These standards apply equally in Claude Code and Kiro CLI.
        '';
      })

      # Maki global instructions (consolidated from steering files)
      (lib.mkIf cfg.targets.maki {
        ".config/maki/instructions.md".source = ./files/maki-instructions.md;
      })
    ];
  };
}
