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
    sessionPath = [ "$HOME/.local/bin" ];
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
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      # Avoid unwanted garbage collection when using nix-direnv
      keep-outputs = true;
      keep-derivations = true;
      warn-dirty = false;
    };
  };
}
