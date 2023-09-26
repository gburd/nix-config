{ config, desktop, hostname, inputs, lib, pkgs, ... }:
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

    homeMode = "0755";
    isNormalUser = true;
    # TODO
    hashedPassword = "$6$RDOZHdTwt.BuOR4C$fYDkyb3yppbgX0ewPbsKabS2u9W.wyrRJONQPtugrO/gBJCzsWkfVIVYOAj07Qar1yqeYJBlBkYSFAgGe5ssw.";
    #hashedPasswordFile = config.sops.secrets.gburd-password.path;
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../../../../home-manager/_mixins/users/gburd/ssh.pub)
      (builtins.readFile ../../../../home-manager/_mixins/users/gburd/symas-ssh.pub)
    ];
    packages = [ pkgs.home-manager ];
    shell = pkgs.fish;
  };

  sops.secrets.gburd-password = {
    sopsFile = ../../secrets.yaml;
    neededForUsers = true;
  };

  services.geoclue2.enable = true;
}
