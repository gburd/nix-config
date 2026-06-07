# Mac Pro "Trash Can" (Late 2013)
# Model: MacPro6,1
# CPU: Intel Xeon E5 (Ivy Bridge-EP)
# GPU: Dual AMD FirePro
# RAM: Up to 64GB DDR3 ECC

{ inputs, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix

    # Common workstation configuration (already brings in tailscale.nix)
    ../../_mixins/workstations/common.nix

    # Auto-authenticate Tailscale via sops-nix-managed auth key.
    # Provision the key by editing nixos/_mixins/secrets.yaml.
    # See nixos/_mixins/services/tailscale-autoconnect.nix for the
    # full provisioning workflow.
    ../../_mixins/services/tailscale-autoconnect.nix

    # Hardware-specific
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    # Headless GPU compute (Mesa/Vulkan/OpenCL userspace) so the FirePros
    # are usable for Ollama / llama.cpp / OpenCL workloads without a
    # display server. desktop = null is passed in flake.nix so
    # _mixins/desktop/default.nix (which would otherwise enable
    # hardware.graphics) is NOT imported; this module fills that gap
    # for headless GPU compute.
    ../../_mixins/hardware/gpu-compute.nix
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

  # Firewall disabled. The `trustedInterfaces = [ "tailscale0" ]` setting
  # from nixos/_mixins/services/tailscale.nix should be enough in theory,
  # but in practice meh hits packet drops with the firewall on — likely
  # the `fwmark 0x80000 unreachable` rule (Tailscale's own outbound
  # routing) interacting with conntrack/nftables in a way that breaks
  # connections originating from QEMU slirp NAT and similar non-trivial
  # paths. Re-test with the firewall off whenever connectivity is
  # known-good and only re-enable here if you can confirm tailscale↔
  # peer flows survive (a `cargo nextest` distributed run between meh
  # and floki is the canonical regression test).
  networking.firewall.enable = lib.mkForce false;

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
