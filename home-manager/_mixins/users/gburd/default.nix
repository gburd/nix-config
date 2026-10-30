{ lib, hostname, inputs, platform, config, pkgs, desktop ? null, ... }:
let
  systemInfo = lib.splitString "-" platform;
  systemType = builtins.elemAt systemInfo 1;
in
{
  imports = [
    # NOTE: impermanence removed - not compatible with standalone home-manager
    # inputs.impermanence.homeManagerModules.default
    ../../cli
    ../../console
    ./ssh.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/hosts/${hostname}.nix")) ./hosts/${hostname}.nix
  ++ lib.optional (builtins.pathExists (./. + "/hosts/${hostname}/default.nix")) ./hosts/${hostname}/default.nix
  ++ lib.optional (builtins.pathExists (./. + "/systems/${systemType}.nix")) ./systems/${systemType}.nix;

  home.file = {

    "ws/devshells".source = inputs.devshells;

    "${config.xdg.configHome}/alacritty/alacritty.yml".source = ./alacritty.yml;

    "${config.xdg.configHome}/nixpkgs/config.nix".text = ''
      {
        allowUnfree = true;
      }
    '';

  };

  home = {
    # Shared CLI/dev packages wanted on ALL of gburd's Linux hosts
    # (floki/meh/arnold). Hoisted here to remove per-host duplication
    # (was repeated verbatim in each host file). Host-unique packages
    # (GUI apps, kiro-cli/lmstudio/terax-ai/pan on floki, etc.) stay in the
    # per-host files; CLI basics already in console/default.nix are NOT
    # repeated here.
    # Wrapped in lib/evaluates.nix: packages that cannot evaluate on this
    # platform (riscv64 has no GHC, no Chromium, no qtwebengine) drop out
    # instead of failing the generation. A no-op on x86_64/aarch64.
    packages = import ../../../../lib/evaluates.nix (with pkgs; [
      _1password-cli
      # uutils coreutils (Rust reimplementation of GNU coreutils) for gburd on
      # Linux. -noprefix installs ls/cp/mv/... under their plain names so they
      # take PATH precedence over the GNU coreutils from the system/profile.
      # Scoped to this Linux-only shared list (floki/meh/arnold); not on
      # darwin, which doesn't import this file. Being tested on meh first.
      uutils-coreutils-noprefix
      cfssl
      dig
      elixir
      emacs
      erlang
      file
      htop
      lsof
      luajitPackages.luarocks
      m4
      openssl
      perl
      python3
      rebar3
      tree-sitter
      xclip
    ]);
  };

  programs = {
    git = {
      settings.user = {
        email = lib.mkDefault "greg@burd.me";
        name = lib.mkDefault "Greg Burd";
      };
    };
  };

  # To declaratively enable and configure, use of modules like home-manager you
  # are required to configure dconf settings. (HINT: use `dconf watch /` to
  # discover what to put here)
  #
  # Only enable on desktop hosts — on headless hosts (meh, servers) the
  # session bus that activates ca.desrt.dconf doesn't exist and home-manager's
  # `dconfSettings` activation step would abort the entire activate run
  # mid-way (silently dropping every step after it: setupLitellm,
  # installHermesAgent, sops-nix, …). Guard with the `desktop` specialArg.
  dconf = lib.mkIf (builtins.isString desktop) {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disabled-user-extensions = false; # enables user extensions (disabled by default)
        # blur-my-shell removed: on GNOME 49 / new Mutter its blur actors
        # don't get damage/repaint events, leaving semi-transparent ghost
        # content around screen edges after a window closes.
        enabled-extensions = [ ];
      };
    };
  };

}
