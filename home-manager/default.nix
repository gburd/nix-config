{ desktop, lib, inputs, outputs, pkgs, stateVersion, username, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
in
{
  # Only import desktop configuration if the host is desktop enabled
  # Only import user specific configuration if they have bespoke settings
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example
    inputs.sops-nix.homeManagerModules.sops
    ../modules/home-manager/ai
    # NOTE: gh-dash module removed - home-manager now has built-in gh-dash support
    # ../modules/home-manager/gh-dash

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    ./_mixins/console
  ]
  ++ lib.optional (builtins.isString desktop) ./_mixins/desktop
  ++ lib.optional (builtins.isPath (./. + "/_mixins/users/${username}")) ./_mixins/users/${username};

  home = {
    # activation.report-changes = if isDarwin then "" else config.lib.dag.entryAnywhere ''
    #   ${pkgs.nvd}/bin/nvd diff $oldGenPath $newGenPath
    # '';
    homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";
    # Note: do NOT use `sessionPath = [ "$HOME/.local/bin" ];` here — home-manager
    # always *prepends* sessionPath, which puts ~/.local/bin ahead of
    # ~/.nix-profile/bin and lets stale self-installer copies (e.g. an old
    # ~/.local/bin/claude) shadow nix-managed binaries. Append instead so
    # nix wins; user-installed binaries still resolve as a fallback.
    sessionVariablesExtra = ''
      export PATH="$PATH''${PATH:+:}$HOME/.local/bin"
    '';
    inherit stateVersion;
    inherit username;
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
      outputs.overlays.bitnet-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default
      inputs.agenix.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
      # Allow insecure packages for development tools
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };

  nix = {
    package = lib.mkDefault pkgs.unstable.nix;
    # Only non-restricted settings here. Restricted settings
    # (auto-optimise-store, keep-outputs, keep-derivations, sandbox) must be
    # configured at the daemon level and are set in nixos/default.nix for
    # NixOS hosts. On standalone home-manager hosts (e.g. arnold/Fedora) the
    # user must be added to /etc/nix/nix.conf `trusted-users` for those to
    # take effect; otherwise nix-daemon emits a warning on every invocation.
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
      # Binary caches for user-level nix commands (~/.config/nix/nix.conf).
      # On NixOS (floki/meh) the system-level /etc/nix/nix.conf already has
      # cache.nixos.org and (via nixos/default.nix) nix-community.cachix.org;
      # this `extra-*` adds them again at user scope so non-NixOS hosts
      # (arnold/Fedora, where the Determinate-installed system nix.conf only
      # carries FlakeHub + Determinate's substituters) also reach the same
      # caches without touching their system file.
      extra-substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
