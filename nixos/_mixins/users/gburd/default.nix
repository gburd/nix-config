{ config, desktop, hostname, lib, pkgs, ... }:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports = [
    inputs.vscode-server.nixosModules.default
  ] ++ lib.optionals (desktop != null) [
    ../../desktop/chromium.nix
    ../../desktop/chromium-extensions.nix
    ../../desktop/obs-studio.nix
    ../../desktop/vscode.nix
    ../../desktop/${desktop}-apps.nix
  ];

  environment.systemPackages = with pkgs; [
    aria2
    croc
    rclone
    curl
    #yadm # Terminal dot file manager
    zsync
  ] ++ lib.optionals (desktop != null) [
    appimage-run
    authy
    chatterino2
    gimp-with-plugins
    gnome.gnome-clocks
    irccloud
    inkscape
    #libreoffice
    pick-colour-picker
    wmctrl
    xdotool
    ydotool
    zoom-us

    # Fast moving apps use the unstable branch
    unstable.discord
    unstable.google-chrome
    unstable.vivaldi
    unstable.vivaldi-ffmpeg-codecs
  ];

  services = {
    aria2 = {
      enable = true;
      openPorts = true;
      rpcSecret = "${hostname}";
    };
    croc = {
      enable = true;
      pass = "${hostname}";
      openFirewall = true;
    };
  };

  users.users.gburd = {
    extraGroups = [
      "audio"
      "input"
      "networkmanager"
      "users"
      "video"
      "wheel"
    ] ++ ifTheyExist [
      "deluge"
      "docker"
      "git"
      "i2c"
      "libvirtd"
      "network"
      "podman"
      "wireshark"
    ];

    hashedPasswordFile = config.sops.secrets.gburd-password.path;
    homeMode = "0755";
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../../../home/gburd/ssh.pub)
      (builtins.readFile ../../../../home/gburd/symas-ssh.pub)
    ];
    packages = [ pkgs.home-manager ];
    shell = pkgs.fish;
  };

  sops.secrets.gburd-password = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  home-manager.users.gburd = import ../../../../home/gburd/${config.networking.hostName}.nix;

  services.geoclue2.enable = true;
}
