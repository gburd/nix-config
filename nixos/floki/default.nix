{ inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    #inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    #(import ./disks.nix { })

    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/filesystems/encrypted-root.nix
    ../_mixins/filesystems/btrfs.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
    #    ../_mixins/services/zerotier.nix
    ../_mixins/virt

    #    ../_mixins/global
    #    ../_mixins/users/gburd
  ];

  fileSystems."/swap" =
    {
      device = "/dev/disk/by-uuid/bf75af76-49b0-41fa-a4e5-9a52a6a0a667";
      fsType = "btrfs";
      options = [ "subvol=swap" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/3D04-3716";
      fsType = "vfat";
    };

  # fileSystems = {
  #   "/boot" = {
  #     device = "/dev/disk/by-label/ESP";
  #     fsType = "vfat";
  #   };
  # };

  swapDevices = [{
    device = "/swap/swapfile";
    size = 8196;
  }];

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "rtsx_pci_sdmmc"
        "sd_mod"
        "sdhci_pci"
        "uas"
        "usbhid"
        "usb_storage"
        "xhci_pci"
      ];

      luks.devices."enc".device = "/dev/disk/by-uuid/470152b6-16cc-4dcf-b1e9-c684c1589e33";
    };

    kernelModules = [ "kvm-intel" ]; # TODO: "nvidia" 
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # My GPD MicroPC has a US keyboard layout
  console.keyMap = lib.mkForce "us";
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=14
    xkb-layout=us
  '';
  services.xserver.layout = lib.mkForce "us";
  services.xserver.xkbOptions = "ctrl:swapcaps";

  environment.systemPackages = with pkgs; [
    nvtop-amd
  ];

  networking.hostName = "floki";
  powerManagement.powertop.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  # Lid settings
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

}
