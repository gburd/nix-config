# Motherboard: LENOVO 21DE001EUS ver: SDK0T76528 WIN ssn: W1CG27P023B
# CPU:         12th Gen Intel(R) Core(TM) i9-12900H
# GPU:         NVIDIA GeForce RTX 3080 Ti
# RAM:         32GB DDR5
# SATA:        WD_BLACK SN850X 4TB (624331WD) SSD

{ inputs, lib, pkgs, ... }:
{
  imports = [
    (import ./disks.nix)
    #./hardware-configuration.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../_mixins/desktop/daw.nix
    ../../_mixins/desktop/ente.nix
    ../../_mixins/desktop/logseq.nix
    ../../_mixins/hardware/systemd-boot.nix
    ../../_mixins/hardware/disable-nm-wait.nix
    ../../_mixins/hardware/rtx-3080ti.nix
    ../../_mixins/hardware/roccat.nix
    ../../_mixins/services/bluetooth.nix
    ../../_mixins/services/pipewire.nix
    ../../_mixins/virt
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "rtsx_pci_sdmmc"
        "sd_mod"
        "thunderbolt"
        "usb_storage"
        "xhci_pci"
      ];
    };

    kernelModules = [ "kvm-intel" "nvidia" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };

  console.keyMap = lib.mkForce "us";
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=12
    xkb-layout=us
  '';
  services.xserver.layout = lib.mkForce "us";
  services.xserver.xkbOptions = "ctrl:swapcaps";

  environment.systemPackages = with pkgs; [
    nvtop-amd
    man-pages
    man-pages-posix
  ];

  networking.hostName = "floki";
  powerManagement.powertop.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  documentation.nixos.enable = lib.mkForce true;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.dev.enable = true;
  documentation.man.generateCaches = true;

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "intel";
      package = pkgs.openrgb-with-all-plugins;
    };
    # Lid settings
    logind = {
      lidSwitch = "suspend";
      lidSwitchExternalPower = "lock";
    };
  };

  virtualisation.docker.storageDriver = "btrfs";
  #  virtualisation.podman.storageDriver = "btrfs";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # support for cross-platform NixOS builds
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];
}
