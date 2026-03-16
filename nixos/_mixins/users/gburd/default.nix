{ config, desktop, lib, pkgs, sshMatrix, ... }:
let
  ifExists = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  # Only include desktop components if one is supplied.
  imports = lib.optional (builtins.isString desktop) ./desktop.nix;

  environment.systemPackages = with pkgs; [
    yadm # Terminal dot file manager
    neovim
    bubblewrap # Sandboxing for Claude Code
  ];

  users.users.gburd = {
    description = "Greg Burd";
    extraGroups = [
      "audio"
      "input"
      "networkmanager"
      "users"
      "video"
      "wheel"
    ]
    ++ ifExists [
      "docker"
      "podman"
      config.services.kubo.group
    ];

    # Password managed via SOPS secrets (generate with: mkpasswd -m sha-512)
    hashedPasswordFile = config.sops.secrets.gburd-password.path;
    homeMode = "0755";
    isNormalUser = true;
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
    packages = [ pkgs.home-manager ];
    shell = pkgs.fish;
  };

  sops.secrets.gburd-password = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  # https://github.com/Mic92/envfs
  services.envfs.enable = true;
  # https://wiki.nixos.org/wiki/IPFS
  #kubo.enable = true;
  # a location service `where-am-i`
  services.geoclue2.enable = true;
}
