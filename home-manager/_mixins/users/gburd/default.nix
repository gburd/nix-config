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
    packages = with pkgs; [
      tig
    ];
  };

  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          # No global IdentityAgent: SSH auth + git signing now use the
          # sops-deployed on-disk keys (~/.ssh/id_auth_ed25519 /
          # id_signing_ed25519) via the standard ssh-agent
          # (modules/home-manager/ssh-management). 1Password's agent socket
          # required an unlocked, non-auto-locked GUI app to sign — unusable
          # headless/over-SSH — so it's no longer wired here.
          compression = true;
          extraOptions = {
            ConnectTimeout = "5";
            ControlMaster = "auto";
            ControlPath = "/tmp/ssh_mux_%h_%p_%r";
            ControlPersist = "10m";
            LogLevel = "QUIET";
            ServerAliveInterval = "60";
            ServerAliveCountMax = "2";
            TCPKeepAlive = "yes";
            # accept-new: trust a host on FIRST contact (no prompt) but
            # WARN+refuse if a known host's key later changes — i.e. keep
            # the MITM protection that StrictHostKeyChecking=no +
            # UserKnownHostsFile=/dev/null threw away. Real known_hosts so
            # changes are actually detected. forwardAgent/forwardX11 are
            # deliberately NOT set globally: they're scoped per-trusted-
            # host in cli/ssh.nix (net/trusted/meh/santorini blocks).
            StrictHostKeyChecking = "accept-new";
          };
        };
        # Throwaway / ephemeral local targets (quickemu VMs, freshly-imaged
        # boxes, link-local) where the host key churns and there's nothing
        # to MITM. Here — and ONLY here — skip verification.
        "192.168.122.* 10.0.2.* *.local quickemu vm-*" = {
          extraOptions = {
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };
        "github.com" = {
          hostname = "github.com";
          user = "git";
        };
      };
    };
    fish = {
      enable = false;
      interactiveShellInit = ''
        set fish_cursor_default block blink
        set fish_cursor_insert line blink
        set fish_cursor_replace_one underscore blink
        set fish_cursor_visual block
        set -U fish_color_autosuggestion brblack
        set -U fish_color_cancel -r
        set -U fish_color_command green
        set -U fish_color_comment brblack
        set -U fish_color_cwd brgreen
        set -U fish_color_cwd_root brred
        set -U fish_color_end brmagenta
        set -U fish_color_error red
        set -U fish_color_escape brcyan
        set -U fish_color_history_current --bold
        set -U fish_color_host normal
        set -U fish_color_match --background=brblue
        set -U fish_color_normal normal
        set -U fish_color_operator cyan
        set -U fish_color_param blue
        set -U fish_color_quote yellow
        set -U fish_color_redirection magenta
        set -U fish_color_search_match bryellow '--background=brblack'
        set -U fish_color_selection white --bold '--background=brblack'
        set -U fish_color_status red
        set -U fish_color_user brwhite
        set -U fish_color_valid_path --underline
        set -U fish_pager_color_completion normal
        set -U fish_pager_color_description yellow
        set -U fish_pager_color_prefix white --bold --underline
        set -U fish_pager_color_progress brwhite '--background=cyan'
      '';

      shellAliases =
        let
          # determines directory path of symbolic link
          devsh = target: "nix develop $(readlink -f ~/ws/devshells)#${target} --command \$SHELL";
        in
        {
          "devsh:c" = devsh "c";
          "devh:python" = devsh "python";
        };
    };

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
