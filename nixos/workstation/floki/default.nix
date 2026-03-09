# Motherboard: LENOVO 21DE001EUS ver: SDK0T76528 WIN ssn: W1CG27P023B
# CPU:         12th Gen Intel(R) Core(TM) i9-12900H
# GPU:         NVIDIA GeForce GTX 1050 Ti Mobile with Max-Q Design
# RAM:         32GB DDR5
# SATA:        WD_BLACK SN850X 4TB (624331WD) SSD

{ inputs, config, lib, pkgs, ... }:
{
  imports = [
    (import ./disks.nix)
    #./hardware-configuration.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-extreme-gen4

    ../../_mixins/desktop/daw.nix
    ../../_mixins/desktop/ente.nix
    ../../_mixins/desktop/logseq.nix
    ../../_mixins/hardware/systemd-boot.nix
    ../../_mixins/hardware/disable-nm-wait.nix
    #    ../../_mixins/hardware/intel.accelerated-video-playback.nix
    ../../_mixins/hardware/gtx-1050ti.nix
    ../../_mixins/hardware/roccat.nix
    ../../_mixins/services/bluetooth.nix
    ../../_mixins/services/pipewire.nix
    ../../_mixins/virt
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

  console.keyMap = lib.mkForce "us";
  console.font = lib.mkForce "${pkgs.terminus_font}/share/consolefonts/ter-232n.psf.gz";
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=12
    xkb-layout=us
  '';
  services.xserver.xkb.layout = lib.mkForce "us";
  services.xserver.xkb.options = "ctrl:swapcaps";

  environment.systemPackages = with pkgs; [
    nvtopPackages.full
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
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "lock";
    };
  };

  virtualisation.docker.storageDriver = "btrfs";
  #  virtualisation.podman.storageDriver = "btrfs";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # support for cross-platform NixOS builds
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];

  # setup and use the fingerprint reader (setup with fprintd-enroll)
  # services.fprintd.enable = true;
  # services.fprintd.tod.enable = true;
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix;

  # security.pam.services.login.fprintAuth = true;
  # # similarly to how other distributions handle the fingerprinting login
  # security.pam.services.gdm-fingerprint = lib.mkIf config.services.fprintd.enable {
  #   text = ''
  #     auth       required                    pam_shells.so
  #     auth       requisite                   pam_nologin.so
  #     auth       requisite                   pam_faillock.so      preauth
  #     auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
  #     auth       optional                    pam_permit.so
  #     auth       required                    pam_env.so
  #     auth       [success=ok default=1]      ${pkgs.gnome.gdm}/lib/security/pam_gdm.so
  #     auth       optional                    ${pkgs.gnome.gnome-keyring}/lib/security/pam_gnome_keyring.so

  #     account    include                     login

  #     password   required                    pam_deny.so

  #     session    include                     login
  #     session    optional                    ${pkgs.gnome.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
  #   '';
  # };
}
