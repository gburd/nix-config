# Mac Pro "Trash Can" (Late 2013)
# Model: MacPro6,1
# CPU: Intel Xeon E5 (Ivy Bridge-EP)
# GPU: Dual AMD FirePro
# RAM: Up to 64GB DDR3 ECC

{ inputs, lib, pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../_mixins/desktop/ente.nix
    ../../_mixins/desktop/logseq.nix
    ../../_mixins/hardware/systemd-boot.nix
    ../../_mixins/hardware/disable-nm-wait.nix
    ../../_mixins/services/bluetooth.nix
    ../../_mixins/services/pipewire.nix
    ../../_mixins/virt

    # Optional: Enable comprehensive documentation and debug support
    ../../_mixins/features/documentation.nix
    ../../_mixins/features/debug-symbols.nix
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
  };

  console.keyMap = lib.mkForce "us";
  console.font = lib.mkForce "${pkgs.terminus_font}/share/consolefonts/ter-232n.psf.gz";
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=12
    xkb-layout=us
  '';
  services.xserver.xkb.layout = lib.mkForce "us";
  services.xserver.xkb.options = "ctrl:swapcaps";

  networking.hostName = "meh";

  # Enable 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "gburd" ];
  };

  # Enable core dumps in current directory with pattern core.<pid>
  systemd.coredump.extraConfig = ''
    Storage=none
  '';
  security.pam.loginLimits = [
    { domain = "*"; type = "-"; item = "core"; value = "unlimited"; }
  ];
  boot.kernel.sysctl = {
    "kernel.core_pattern" = "core.%p";
    "kernel.core_uses_pid" = 1;
  };

  # Mac Pro is a desktop, no power management needed
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

    # Disable all power-saving features
    logind = {
      lidSwitch = "ignore";
      lidSwitchDocked = "ignore";
      lidSwitchExternalPower = "ignore";
      extraConfig = ''
        HandlePowerKey=ignore
        HandleSuspendKey=ignore
        HandleHibernateKey=ignore
        HandleLidSwitch=ignore
        IdleAction=ignore
      '';
    };
  };

  virtualisation.docker.storageDriver = "overlay2";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Support for cross-platform NixOS builds
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];
}
