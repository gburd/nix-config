{ config, desktop, lib, pkgs, ... }:
let
  ifExists = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  # Only include desktop components if one is supplied.
  imports = lib.optional (builtins.isString desktop) ./desktop.nix;

  environment.systemPackages = [
    pkgs.yadm # Terminal dot file manager
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
    hashedPassword = "$6$1.WkO0Vt/wcBd4uy$X/3Uan97cxd7atvi1XN1.CL8E01eWpWiFp9O4Od6W5kKTx1m22RUv/MXaX3EvISKEdBd4mvVXMSgTVgQzA3Vl/";
    homeMode = "0755";
    isNormalUser = true;
    openssh.authorizedKeys.keys = sshMatrix.groups.privileged_users;
    packages = [ pkgs.home-manager ];
    shell = pkgs.bash;
  };
}
