# Common configuration for all workstations (desktops/laptops)
{ lib, pkgs, ... }:
{
  imports = [
    ../desktop/ente.nix
    ../desktop/logseq.nix
    ../hardware/systemd-boot.nix
    ../hardware/disable-nm-wait.nix
    ../services/bluetooth.nix
    ../services/pipewire.nix
    ../virt

    # Optional: Enable comprehensive documentation and debug support
    ../features/documentation.nix
    ../features/debug-symbols.nix
  ];

  # Common console/keyboard settings
  console.keyMap = lib.mkForce "us";
  console.font = lib.mkForce "${pkgs.terminus_font}/share/consolefonts/ter-232n.psf.gz";
  services.kmscon.extraConfig = lib.mkForce ''
    font-size=12
    xkb-layout=us
  '';
  services.xserver.xkb.layout = lib.mkForce "us";
  services.xserver.xkb.options = "ctrl:swapcaps";

  # Enable 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "gburd" ];
  };

  # NextDNS with DNS-over-TLS
  services.resolved = {
    enable = true;
    dnsovertls = "true";
    fallbackDns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    extraConfig = ''
      DNS=45.90.28.0#362f8c.dns.nextdns.io
      DNS=2a07:a8c0::#362f8c.dns.nextdns.io
      DNS=45.90.30.0#362f8c.dns.nextdns.io
      DNS=2a07:a8c1::#362f8c.dns.nextdns.io
    '';
  };
  # Tell NetworkManager to use systemd-resolved
  networking.networkmanager.dns = "systemd-resolved";

  # Disable sudo lecture message and use_pty (fails in non-TTY contexts)
  security.sudo.extraConfig = ''
    Defaults lecture = never
    Defaults !use_pty
  '';

  # Make Nix tools available at traditional FHS paths
  # Provides /usr/bin/env, /bin/sh, and other standard paths
  services.envfs.enable = true;

  # Dynamic linker for non-NixOS binaries
  # Provides /lib64/ld-linux-x86-64.so.2 and other standard library paths
  programs.nix-ld.enable = true;

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

  # Support for cross-platform NixOS builds
  boot.binfmt.emulatedSystems = [ "armv7l-linux" "aarch64-linux" ];
}
