# Motherboard: LENOVO 21DECTO1WW (ThinkPad X1 Extreme Gen 5 / P1 Gen 5)
# CPU:         Intel Core i7-12800H (Alder Lake-P, 6P+8E cores, 20 threads)
# iGPU:        Intel Iris Xe Graphics (Alder Lake-P GT2) — i915 driver
# dGPU:        NVIDIA GeForce RTX 3070 Ti Laptop (GA104) — proprietary nvidia, PRIME offload
# RAM:         SODIMM DDR5 (2 slots)
# NVMe:        WD_BLACK SN850X 4TB (PCIe Gen 4) — the SSD migrated from the X1 Carbon Gen13
# WiFi:        Intel Alder Lake-P CNVi (AX211)
#
# HARDWARE MIGRATION 2026-10-28: the SSD was moved from the X1 Carbon Gen13
# (Lunar Lake, Arc 140V iGPU, Intel NPU, xe driver) into this X1 Extreme Gen5.
# The disk/LUKS/btrfs layout (disks.nix) is unchanged — same physical SSD. What
# changed is the GPU stack: Lunar Lake used `xe` and blacklisted `i915`; Alder
# Lake's Iris Xe uses `i915` (so the old i915 blacklist is REMOVED, or the
# display breaks), plus there is now an NVIDIA dGPU (PRIME offload below). The
# NPU (intel_vpu) and its OpenVINO/NPU tooling are gone (Alder Lake has none).

{ inputs, lib, pkgs, config, ... }:
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
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia

    # Floki-specific
    ../../_mixins/desktop/daw.nix
    ../../_mixins/hardware/intel.accelerated-video-playback.nix
    ../../_mixins/hardware/roccat.nix
    ../../_mixins/services/flatpak.nix
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

    kernelModules = [ "kvm-intel" ];

    # Default (stable LTS) kernel. Alder Lake-P is fully supported on any
    # recent kernel, and the NVIDIA proprietary module must build against the
    # running kernel -- linuxPackages_latest (7.2.x) outran the driver and the
    # nvidia kernel module failed to compile, so do NOT use _latest here.
    kernelPackages = pkgs.linuxPackages;

    # Keep US regdom for the AX211 Wi-Fi.
    extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom=US
    '';
  };

  # --- GPU: Intel Iris Xe (iGPU, primary display) + NVIDIA RTX 3070 Ti (PRIME
  # offload). The iGPU drives everything by default; apps that want the dGPU
  # run under `nvidia-offload <cmd>` (the helper script enabled by
  # prime.offload below). This keeps battery life sane (the dGPU powers down
  # when idle) while making the 3070 Ti available on demand.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware = {
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      # Turing+ (Ampere GA104) supports runtime D3 power management, so let the
      # dGPU fully power off when unused (the point of a hybrid laptop).
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      open = false; # GA104 works with either; proprietary is the safe default
      nvidiaSettings = true;
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true; # provides the `nvidia-offload` wrapper
        # Bus IDs from lspci: Intel iGPU 00:02.0, NVIDIA dGPU 01:00.0.
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
    graphics.enable = true;
  };

  environment.systemPackages = with pkgs; [
    intel-gpu-tools # intel_gpu_top, intel_reg (iGPU diagnostics)
    libva-utils # vainfo — VA-API codec diagnostics
    nvtopPackages.full # GPU monitor (both Intel + NVIDIA)
    vulkan-tools # vulkaninfo / vkcube for verifying both GPUs
  ];

  networking.hostName = "floki";

  # Laptop power management
  # power-profiles-daemon integrates with GNOME Shell to switch between
  # Power Saver / Balanced / Performance based on AC vs battery automatically.
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
