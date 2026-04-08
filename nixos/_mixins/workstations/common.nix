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
