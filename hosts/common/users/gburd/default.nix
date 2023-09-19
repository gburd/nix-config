{ pkgs, config, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.mutableUsers = false;
  users.users.gburd = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "networkmanager"
    ] ++ ifTheyExist [
      "network"
      "wireshark"
      "i2c"
      "docker"
      "podman"
      "git"
      "libvirtd"
      "deluge"
    ];

    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../../../home/gburd/ssh.pub)
      (builtins.readFile ../../../../home/gburd/symas-ssh.pub)
    ];
    passwordFile = config.sops.secrets.gburd-password.path;
    packages = [ pkgs.home-manager ];
  };

  sops.secrets.gburd-password = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  home-manager.users.gburd = import ../../../../home/gburd/${config.networking.hostName}.nix;

  services.geoclue2.enable = true;
  security.pam.services = { swaylock = { }; };
}
