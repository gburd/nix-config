# Motherboard: LENOVO 21DE001EUS ver: SDK0T76528 WIN ssn: W1CG27P023B
# CPU:         12th Gen Intel(R) Core(TM) i9-12900H
# GPU:         NVIDIA GeForce GTX 1050 Ti Mobile with Max-Q Design
# RAM:         32GB DDR5
# SATA:        WD_BLACK SN850X 4TB (624331WD) SSD

{ inputs, lib, pkgs, config, ... }:
{
  imports = [
    (import ./disks.nix)
    #./hardware-configuration.nix

    # Common workstation configuration
    ../../_mixins/workstations/common.nix

    # Hardware-specific
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-extreme-gen4

    # Floki-specific
    ../../_mixins/desktop/daw.nix
    ../../_mixins/hardware/gtx-1050ti.nix
    ../../_mixins/hardware/roccat.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "i915"
        "nvme"
        "rtsx_pci_sdmmc"
        "sd_mod"
        "thunderbolt"
        "usb_storage"
        "xhci_pci"
      ];
    };

    kernelModules = [ "kvm-intel" "nvidia" "i915" ];
    #kernelPackages = pkgs.linuxPackages_latest;
    kernelPackages = pkgs.linuxPackages;
  };

  # https://nixos.wiki/wiki/Nvidia
  # Use offload mode for better battery life and Wayland compatibility
  # Apps can request NVIDIA with: __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia app
  hardware.nvidia.prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true; # provides nvidia-offload command
    sync.enable = false;
    # nix-shell -p lshw.out --run 'sudo lshw -c display'
    intelBusId = "PCI:0:2:0"; # pci@0000:00:02.0
    nvidiaBusId = "PCI:1:0:0"; # pci@0000:01:00.0
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
  ];

  networking.hostName = "floki";
  networking.hosts = {
    "192.168.1.185" = [ "meh" ];
  };

  # Laptop power management
  powerManagement.powertop.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";

  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "intel";
      package = pkgs.openrgb-with-all-plugins;
    };
    # Lid settings
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "lock";
    };
  };

  virtualisation.docker.storageDriver = "btrfs";
  #  virtualisation.podman.storageDriver = "btrfs";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Fingerprint reader: Synaptics 06cb:009a (NOT SUPPORTED by libfprint)
  # This device requires python-validity which is not packaged in nixpkgs
  # Leaving configuration commented out until support is available
  # services.fprintd.enable = true;
  # services.fprintd.tod.enable = true;
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix;

  # security.pam.services.login.fprintAuth = lib.mkForce true;
  # # similarly to how other distributions handle the fingerprinting login
  # security.pam.services.gdm-fingerprint = lib.mkIf config.services.fprintd.enable {
  #   text = ''
  #     auth       required                    pam_shells.so
  #     auth       requisite                   pam_nologin.so
  #     auth       requisite                   pam_faillock.so      preauth
  #     auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
  #     auth       optional                    pam_permit.so
  #     auth       required                    pam_env.so
  #     auth       [success=ok default=1]      ${pkgs.gdm}/lib/security/pam_gdm.so
  #     auth       optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
#
  #     account    include                     login
#
  #     password   required                    pam_deny.so
#
  #     session    include                     login
  #     session    optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
  #   '';
  # };
}
