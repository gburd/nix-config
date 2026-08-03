{ lib, pkgs, ... }:
# solnix — a headless illumos (Nix-on-illumos) host, x86_64-solaris.
#
# ⚠️ NOT YET FUNCTIONAL. This is the declarative target we are building toward:
# run this HM config on a solnix EC2 instance the same way `gburd@ec2` /
# `gburd@meh` are deployed on Linux. It is a starting-point scaffold, mirrored
# on the headless `ec2.nix` host (which is itself the headless subset of
# `meh.nix`), so the eventual solnix parity goal is "gburd@meh, minus the
# Linux-only pieces".
#
# What makes this non-functional TODAY (tracked in the solnix project, not here):
#
#   1. platform = "x86_64-solaris" is not a stock nixpkgs system. It is wired
#      into the solnix-pkgs fork (lib/systems patch 0001). To evaluate this
#      config, `inputs.nixpkgs` for the solnix platform must point at the fork
#      (or an overlay that adds x86_64-solaris). flake.nix's mkHome uses
#      `inputs.nixpkgs.legacyPackages.${platform}` — that attr does not exist
#      for x86_64-solaris on upstream nixpkgs. WIRING TODO in the fork/flake.
#
#   2. The pure x86_64-solaris stdenv (GATE 1b-PURE, proven in solnix) must be
#      the stdenv for these packages, and each package below must build as a
#      real hermetic derivation (solnix Phase-3 rebuild). Heavy ones
#      (emacs/erlang/elixir/python3/perl/tree-sitter) need Solaris portability
#      patches — in progress in solnix, package by package.
#
#   3. HM `services.*` emit systemd user units, which DO NOT EXIST on illumos.
#      meh's 6 services (borgmatic, vdirsyncer, protonmail-bridge, proton-drive,
#      keybase, syncthing) need an HM->SMF translation shim (solnix backlog) OR
#      to be dropped for the first cut. They are DELIBERATELY OMITTED here.
#
#   4. sops-nix secret activation on illumos is untested (age-via-ssh-key should
#      port). OMITTED here for the same reason ec2.nix omits it (fresh box, no
#      secrets file). Add once solnix has sops-on-illumos proven.
#
# So this file intentionally imports only the OS-agnostic HM core (home.packages
# profile + dotfiles + programs.* file generation) and drops everything
# Linux/systemd-specific. It is the "run my config on solnix" target, staged.
{
  imports = [
    # Opt-in AI CLI configuration (arch-neutral text/template generation).
    # litellm gateway is off (like ec2.nix) — reach a remote proxy via SSH
    # forward, don't run one on the illumos box.
    ../../../console/ai
  ];

  programs.ai.litellm.enable = lib.mkForce false;
  programs.ai.sandbox.enable = lib.mkForce false;

  # Same dev-CLI tooling target as the headless meh/ec2 subset. These are the
  # packages the solnix Phase-3 rebuild needs to produce as real hermetic
  # x86_64-solaris derivations before this host evaluates+activates. Kept in
  # lock-step with ec2.nix (the headless precedent); GUI apps and services
  # excluded (illumos-headless, no systemd).
  #
  # NOTE: several of these (emacs, erlang, elixir, python3, perl, tree-sitter,
  # luarocks) are heavy nixpkgs builds that need per-package Solaris patches in
  # the solnix fork. Until they build, this list will not fully realise — that
  # is the expected, tracked gap.
  home.packages = with pkgs; [
    # light CLI (build early / already reachable via solnix cache)
    file
    htop
    lsof
    m4
    openssl
    dig
    tree-sitter
    xclip
    # heavier language/tooling closures (later Phase-3 tranches)
    emacs
    erlang
    elixir
    rebar3
    python3
    perl
    luajitPackages.luarocks
    cfssl
    _1password-cli
    # headless parity extras from ec2.nix
    cmake
    # NOTE: plocate is Linux-only (locate DB / systemd path); OMITTED on illumos.
    # NOTE: minio-client (unstable) — add once the unstable channel is wired for
    #       x86_64-solaris in the fork.
  ];
}
