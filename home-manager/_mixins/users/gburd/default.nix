{ lib, hostname, inputs, platform, pkgs, ... }:
let
  systemInfo = lib.splitString "-" platform;
  systemType = builtins.elemAt systemInfo 1;
in
{
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
    ../../cli
    ../../console
  ]
  ++ lib.optional (builtins.pathExists (./. + "/hosts/${hostname}.nix")) ./hosts/${hostname}.nix
  ++ lib.optional (builtins.pathExists (./. + "/hosts/${hostname}/default.nix")) ./hosts/${hostname}/default.nix
  ++ lib.optional (builtins.pathExists (./. + "/systems/${systemType}.nix")) ./systems/${systemType}.nix;

  home = {

    file.".config/alacritty/alacritty.yml".source = ./alacritty.yml;

    file."ws/devshells".source = inputs.devshells;

    file.".ssh/config".text = "
      Host github.com
        HostName github.com
        User git
    ";

    sessionVariables = {
      # ...
    };

    file.".config/nixpkgs/config.nix".text = ''
      {
        allowUnfree = true;
      }
    '';

    packages = with pkgs; [ ];
  };

  programs = {
    fish = {
      enable = true;
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
      userEmail = lib.mkDefault "greg@burd.me";
      userName = lib.mkDefault "Greg Burd";
    };
  };

  # To declaratively enable and configure, use of modules like home-manager you
  # are required to configure dconf settings. (HINT: use `dconf watch /` to
  # discover what to put here)
  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disabled-user-extensions = false; # enables user extensions (disabled by default)
        enabled-extensions = [
          "blur-my-shell@aunetx"
        ];
      };

      # Configure individual extensions
      "org/gnome/shell/extensions/blur-my-shell" = {
        brightness = 0.75;
        noise-amount = 0;
      };
    };
  };

}
