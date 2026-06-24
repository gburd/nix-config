# santorini — NixOS running as a WSL2 distro on the Windows host "santorini".
# Managed by this flake: `mkWslHost { hostname = "santorini"; username = "gburd"; }`.
# Build/switch from inside the WSL distro:
#   sudo nixos-rebuild switch --flake ~/ws/nix-config#santorini
#
# Two interactive users can use it: gburd (primary; full home-manager via
# the gburd user mixin) and gregb (secondary login). Enter the distro as a
# given user from Windows with:  wsl -d NixOS --user gburd   (or gregb)
{ lib, pkgs, username, ... }:
{
  imports = [
    # No hardware-configuration.nix — the nixos-wsl module supplies the WSL
    # boot/interop layer. The gburd user + its home-manager come from
    # nixos/default.nix importing _mixins/users/${username}.
    ../../_mixins/services/tailscale-autoconnect.nix
  ];

  # WSL has no hardware-configuration.nix to set this; WSL2 is x86_64.
  nixpkgs.hostPlatform = "x86_64-linux";

  wsl = {
    enable = true;
    defaultUser = username; # `wsl -d NixOS` (no --user) lands here
    startMenuLaunchers = true;
    # Reuse the Windows host's Docker Desktop / interop if present.
    wslConf.interop.appendWindowsPath = false; # keep $PATH clean of Windows
    wslConf.network.generateResolvConf = true;
  };

  # Secondary interactive user. The primary (gburd) is created by the
  # _mixins/users/gburd mixin; gregb is a plain login user here so either
  # identity can `wsl -d NixOS --user gregb`.
  users.users.gregb = {
    isNormalUser = true;
    description = "Greg B (secondary WSL user)";
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
    # No password: WSL users log in without one (entered via `wsl --user`);
    # sudo is via wheel. Set a hashedPasswordFile here if you want a password.
  };

  # WSL is headless; no desktop. fish is the default shell (matches gburd).
  programs.fish.enable = true;

  # Keep the closure lean for a WSL distro: no GUI/display stack.
  # (systemType = "wsl" means nixos/default.nix imports no desktop mixin.)
  networking.hostName = lib.mkDefault "santorini";

  system.stateVersion = lib.mkDefault "25.11";
}
