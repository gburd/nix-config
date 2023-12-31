{ inputs, lib, pkgs, platform, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    #inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    (import ./disks.nix)
    ../_mixins/hardware/gpu.nix

    ../_mixins/hardware/systemd-boot.nix
    ../_mixins/services/bluetooth.nix
    ../_mixins/services/pipewire.nix
    ../_mixins/virt
    ../_mixins/virt/docker.nix
    ../_mixins/virt/podman.nix
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

    kernelModules = [ "kvm-intel" ]; # TODO: "nvidia"
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

  documentation.nixos.enable = true;
  documentation.doc.enable = false;
  documentation.info.enable = true;
  documentation.dev.enable = true;
  documentation.man.generateCaches = true;

  # Lid settings
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock";
  };

  virtualisation.docker.storageDriver = "btrfs";
#  virtualisation.podman.storageDriver = "btrfs";

  nixpkgs.hostPlatform = lib.mkDefault "${platform}";

}
