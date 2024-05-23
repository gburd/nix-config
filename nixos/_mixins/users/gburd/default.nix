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
    ];

    # mkpasswd -m sha-512
    # TODO: hashedPasswordFile = config.sops.secrets.gburd-password.path;
    hashedPassword = "$6$RDOZHdTwt.BuOR4C$fYDkyb3yppbgX0ewPbsKabS2u9W.wyrRJONQPtugrO/gBJCzsWkfVIVYOAj07Qar1yqeYJBlBkYSFAgGe5ssw.";
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

  services.geoclue2.enable = true;
}
