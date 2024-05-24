{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Needed to continue SD image initialization after installer removes its own unit.
    ./sd-image-init.nix
  ];

  # Create a swap file. Raspberry pi 3B has only 1G of ram, and nixos-rebuild takes a *lot* of ram to evaluate
  # the nixpgks store (someone even recommended me to evaluate the store on my laptop, either via binfmt to
  # emulate Aarch64 or to use the rasp as a remote builder to keep the evaluation locally). When the system runs
  # out of RAM, it freezes.
  swapDevices = [
    {
      device = "/swapfile";
      # create a smaller file on qemu, just to test
      size = if (config ? virtualisation.qemu) then 127 else 2048;
    }
  ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.consoleLogLevel = 7;

  # Apparently also needed for some parts of the pi to work.
  hardware.enableRedistributableFirmware = true;

  # Otherwise the hdmi disconnects during the boot and reconnect at the end
  # looks like it is still not enough...
  # Don't enable it with qemu
  boot.initrd.kernelModules = lib.mkIf (!(config ? virtualisation.qemu)) [ "vc4" "bcm2835_dma" "i2c_bcm2835" "ahci"];

  # K900 said that I should always try to stay as much as possible on mainline… which makes sense.
  # K900 also recommended to use kernel 6.0.2 (default is 5.*),
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # also get errors on rpi3 (can't boot, kernel error) and it will not work in qemu since it's arm
  # boot.kernelPackages = pkgs.linuxPackages_rpi3;

  # https://github.com/NixOS/nixpkgs/issues/154163#issuecomment-1008362877
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  boot.kernelParams = [ "cma=32M" "console=tty0,115200n8" ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
    initialPassword = "nixos";
  };
  services.mingetty.autologinUser = "nixos";

  # The installer starts with a "nixos" user to allow installation, so add the
  # SSH key to that user. Note that the key is, at the time of writing, put in
  # `/etc/ssh/authorized_keys.d`
  users.extraUsers.nixos.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSNy/vMr2Zk9pvfjQnxiU9F8CGQJwCiXDxPecKG9/q+ Greg Burd <greg@burd.me> - 2023-01-23"
  ];

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

  networking.wireless.enable = false;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.wlan0.useDHCP = true;

  # NTP time sync.
  services.timesyncd.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
