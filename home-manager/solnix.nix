{ lib, pkgs, username, stateVersion, ... }:
# The small command-line profile for gburd on a solnix (illumos) host.
#
# A solnix home is evaluated with solnix's own package set (lib/helpers.nix
# mkSolnixHome), not nixpkgs: nixpkgs' x86_64-solaris stdenv does not evaluate,
# and the console/ + cli/ mixins name ~200 packages (umami, eza, atuin, gcc14,
# qemu ...) of which solnix builds a handful. So this imports only the mixins
# that are pure configuration, and installs what pkgs.solnix provides.
#
# Shared with the Linux hosts, unchanged:
#   cli/bash.nix          prompt, history, aliases, ctrl-s off
#   cli/git-common.nix    identity, aliases, pull/push policy, ignores
#   cli/ssh.nix           per-host blocks (meh, net, burd.me, ...)
#   users/gburd/ssh.nix   multiplexing, keepalives, host-key policy
#   console/tmux.nix      C-a prefix, vi keys, splits, status bar
{
  imports = [
    ./_mixins/cli/bash.nix
    ./_mixins/cli/git-common.nix
    ./_mixins/cli/ssh.nix
    ./_mixins/users/gburd/ssh.nix
    ./_mixins/console/tmux.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    inherit stateVersion;

    # Installed only if this solnix revision builds them, so an older solnix pin
    # still evaluates (with fewer tools) instead of failing on a missing attr.
    packages = map (n: pkgs.${n}) (lib.filter (n: pkgs ? ${n}) [
      "vi"
      "less"
      "htop"
      "jq"
      "curl"
      "home-manager"
    ]);

    # vi/less, not the nvim/page of the Linux console mixin: those are what
    # solnix builds. git and tmux read these too.
    sessionVariables = {
      EDITOR = "vi";
      VISUAL = "vi";
      PAGER = "less";
    };
    sessionVariablesExtra = ''
      export PATH="$PATH''${PATH:+:}$HOME/.local/bin"
    '';
  };

  programs = {
    # bash-completion is not built for solnix; the bash module would source it.
    bash.enableCompletion = lib.mkForce false;
    git.settings.core.editor = "vi";
    # man is the base OS's (illumos mandoc, in the system profile), as
    # home-manager does on Darwin; nothing to install.
    man.package = null;
  };

  # The generated manual needs nixosOptionsDoc (python, pandoc); news is the
  # upstream changelog, silent as on every other host.
  manual.manpages.enable = false;
  news.display = "silent";

}
