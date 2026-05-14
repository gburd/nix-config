# Motherboard: LENOVO 21MKCTO1WW (ThinkPad X1 Carbon Gen 13 Aura Edition)
# CPU:         Intel Core Ultra 7 258V (Lunar Lake, 4P+4E cores, 8 threads, 4.8GHz)
# GPU:         Intel Arc 140V (Xe2/Battlemage, 8 Xe2 cores, ~67 TOPS)
# NPU:         Intel AI Boost NPU (~48 TOPS, intel_vpu driver, /dev/accel/accel0)
# RAM:         32GB LPDDR5X (on-package)
# NVMe:        WD_BLACK SN850X 4TB (PCIe Gen 4)
# WiFi:        Intel BE201 (Wi-Fi 7, 320MHz)

{ inputs, lib, pkgs, ... }:
{
  imports = [
    (import ./disks.nix)
    #./hardware-configuration.nix

    # Common workstation configuration
    ../../_mixins/workstations/common.nix

    # Hardware-specific
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd

    # Floki-specific
    ../../_mixins/desktop/daw.nix
    ../../_mixins/hardware/intel.accelerated-video-playback.nix
    ../../_mixins/hardware/roccat.nix
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
        "xe"
        "xhci_pci"
      ];
    };

    kernelModules = [
      "kvm-intel"
      "intel_vpu" # Intel NPU (Neural Processing Unit) — /dev/accel/accel0
    ];

    # i915 is unused on Lunar Lake (xe driver handles Arc 140V entirely)
    blacklistedKernelModules = [ "i915" ];

    # Use latest kernel for best Lunar Lake (Core Ultra 200V) + Arc Xe2 support
    kernelPackages = pkgs.linuxPackages_latest;

    # Enable full 320MHz channels for Intel BE201 Wi-Fi 7 when connected to capable AP
    extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom=US
    '';
  };

  environment.systemPackages = with pkgs; [
    intel-gpu-tools            # intel_gpu_top, intel_reg, etc.
    intel-npu-driver           # Level Zero backend for NPU inference
    libva-utils                # vainfo — VA-API codec diagnostics
    nvtopPackages.intel
    openvino                   # OpenVINO runtime with CPU/GPU/NPU plugins
  ];

  networking.hostName = "floki";

  # Laptop power management
  # power-profiles-daemon integrates with GNOME Shell to switch between
  # Power Saver / Balanced / Performance based on AC vs battery automatically.
  # Replaces static cpuFreqGovernor + powertop.enable (which applied battery
  # tuning unconditionally at boot regardless of power source).
  services.power-profiles-daemon.enable = true;

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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Fingerprint reader: Synaptics 06cb:0123 — NOT supported by libfprint or python-validity
  # No packaged NixOS driver exists for this device; blocked on upstream support
  # services.fprintd.enable = true;
}
