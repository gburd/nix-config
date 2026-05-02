# Mac Pro "Trash Can" (Late 2013)
# Model: MacPro6,1
# CPU: Intel Xeon E5 (Ivy Bridge-EP)
# GPU: Dual AMD FirePro
# RAM: Up to 64GB DDR3 ECC

{ inputs, lib, pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix

    # Common workstation configuration
    ../../_mixins/workstations/common.nix

    # Hardware-specific
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
        "sdhci_pci"
      ];
    };

    kernelModules = [ "kvm-intel" ];
    kernelPackages = pkgs.linuxPackages;

    # Enable amdgpu for GCN 1.0 (Southern Islands / Tahiti) GPUs.
    # The R9 280X (Radeon HD 7970) uses "radeon" by default;
    # amdgpu is required for RADV Vulkan compute (needed by Ollama).
    kernelParams = [
      "amdgpu.si_support=1"
      "radeon.si_support=0"
    ];
  };

  networking.hostName = "meh";

  # Mac Pro is a desktop workstation - disable power management
  powerManagement.enable = false;

  # Disable suspend/sleep/hibernate
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  services = {
    hardware.openrgb = {
      enable = false;  # Mac Pro doesn't support OpenRGB
    };

    # Disable all power-saving features on desktop
    logind.settings.Login = {
      HandlePowerKey = "ignore";
      HandleSuspendKey = "ignore";
      HandleHibernateKey = "ignore";
      HandleLidSwitch = "ignore";
      IdleAction = "ignore";
      IdleActionSec = "0";  # Never trigger idle action
    };
  };

  virtualisation.docker.storageDriver = "overlay2";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
