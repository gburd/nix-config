{ config, lib, pkgs, ... }:
let
  cfg = config.services.onepassword-agent;
  inherit (lib) mkEnableOption mkOption mkIf types;
in
{
  options.services.onepassword-agent = {
    enable = mkEnableOption "1Password SSH and GPG agent integration";

    enableSSH = mkOption {
      type = types.bool;
      default = true;
      description = "Enable 1Password SSH agent";
    };

    enableGPG = mkOption {
      type = types.bool;
      default = true;
      description = "Enable 1Password GPG signing";
    };
  };

  config = mkIf cfg.enable {
    # Configure SSH to use 1Password agent
    programs.ssh = mkIf cfg.enableSSH {
      enable = true;
      matchBlocks."*".identityAgent = "~/.1password/agent.sock";
    };


    services.gpg-agent = mkIf cfg.enableSSH {
      # When 1Password handles SSH, GPG agent must not also handle SSH
      enableSshSupport = lib.mkForce false;
    };

    # Set environment variables for 1Password integration
    home.sessionVariables = mkIf cfg.enableSSH {
      SSH_AUTH_SOCK = "~/.1password/agent.sock";
    };

    # Git configuration to use SSH-based commit signing via 1Password
    programs.git = mkIf cfg.enableGPG {
      settings = {
        gpg.format = "ssh";
        commit.gpgsign = true;
        # User must set their signing key in their personal git config:
        # git config --global user.signingkey "ssh-ed25519 AAAAC3N... (from 1Password)"
      };
    };
  };
}
