{ config, desktop, inputs, lib, pkgs, ... }:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports = [
    inputs.vscode-server.nixosModules.default
  ] ++ lib.optionals (desktop != null) [
    ../../desktop/chromium.nix
    ../../desktop/chromium-extensions.nix
    ../../desktop/vscode.nix
    ../../desktop/${desktop}-apps.nix
  ];

  environment.systemPackages = with pkgs; [
    curl
  ] ++ lib.optionals (desktop != null) [
    appimage-run
    authy
    chatterino2
    gimp-with-plugins
    gnome.gnome-clocks
    zoom-us

    # Fast moving apps use the unstable branch
    unstable.discord
    #unstable.google-chrome
  ];

  services = { };

  users.users.gburd = {
    extraGroups = [
      "audio"
      "input"
      "networkmanager"
      "users"
      "video"
      "wheel"
    ] ++ ifTheyExist [
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
    hashedPassword = "$6$RDOZHdTwt.BuOR4C$fYDkyb3yppbgX0ewPbsKabS2u9W.wyrRJONQPtugrO/gBJCzsWkfVIVYOAj07Qar1yqeYJBlBkYSFAgGe5ssw.";
    # TODO: hashedPasswordFile = config.sops.secrets.gburd-password.path;
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
