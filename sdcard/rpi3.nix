{ config, pkgs, ... }: {
  nixpkgs.hostPlatform.system = "aarch64-linux";
  nixpkgs.buildPlatform.system = "x86_64-linux";

  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
    ./sd-image-init.nix
  ];

  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # bzip2 compression takes loads of time with emulation, skip it. Enable this
  # if you're low on space.
  sdImage.compressImage = false;

  sdImage.populateRootCommands = ''
    mkdir -p ./files/etc/sd-image-metadata/
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel}/sd-image/configuration.nix -d ./fies/etc/sd-image-metadata
    #cp /configuration.nix ./files/etc/sd-image-metadata/configuration.nix
    #cp /sd-image-init.nix ./files/etc/sd-image-metadata/sd-image-init.nix
  '';

  # OpenSSH is forced to have an empty `wantedBy` on the installer system[1],
  # this won't allow it to be automatically started. Override it with the normal
  # value.
  # [1] https://github.com/NixOS/nixpkgs/blob/9e5aa25/nixos/modules/profiles/installation-device.nix#L76
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  # Use a default root SSH login.
  services.openssh.settings.PermitRootLogin = "yes";
  users.users.root = {
    initialHashedPassword = "$6$xO61wiVZ3tg9Wryx$lBTmF6N7ed7gpeJdVK8vzExdDecDWiLAvYxNazW72LQST3iMaYQck071V9ACCMgeFrjSXt7G/w5UjlpOF1F6q.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSNy/vMr2Zk9pvfjQnxiU9F8CGQJwCiXDxPecKG9/q+ Greg Burd <greg@burd.me> - 2023-01-23"
    ];
  };

  # NTP time sync.
  services.timesyncd.enable = true;

  # Since the latest kernel can't boot on RPI 3B+
  boot.kernelPackages = pkgs.linuxPackages_rpi3;

  hardware.enableRedistributableFirmware = true;
  networking.wireless.enable = false;
  networking.useDHCP = true;
  hardware.bluetooth.powerOnBoot = false;

  environment.systemPackages = with pkgs; [ git gnupg neovim ];

  system.stateVersion = "23.05";
}
