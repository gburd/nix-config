{ pkgs, lib, config, ... }:
let
  inherit (lib) optionalString optionalAttrs;
  hasPackage = pname: lib.any (p: p ? pname && p.pname == pname) config.home.packages;
  hasRipgrep = hasPackage "ripgrep";
  hasEza = hasPackage "eza";
  hasNeovim = config.programs.neovim.enable;
  hasEmacs = config.programs.emacs.enable;
  hasNeomutt = config.programs.neomutt.enable;
  hasShellColor = if builtins.hasAttr "shellcolor" config.programs then config.programs.shellcolor.enable else false;
  hasKitty = config.programs.kitty.enable;
  shellcolor = "${pkgs.shellcolord}/bin/shellcolor";
in
{
  programs.bash = {
    enable = true;
    enableCompletion = true;

    # Port Fish abbreviations as Bash aliases
    shellAliases = {
      # Clear screen and scrollback (from Fish)
      clear = "printf '\\033[2J\\033[3J\\033[1;1H'";

      # jq with color and paging
      jqless = "jq -C | less -r";

      # Nix shortcuts
      n = "nix";
      nd = "nix develop -c $SHELL";
      ns = "nix shell";
      nsn = "nix shell nixpkgs#";
      nb = "nix build";
      nbn = "nix build nixpkgs#";
      nf = "nix flake";

      # NixOS shortcuts
      nr = "nixos-rebuild --flake .";
      nrs = "nixos-rebuild --flake . switch";
      snr = "sudo nixos-rebuild --flake .";
      snrs = "sudo nixos-rebuild --flake . switch";
      hm = "home-manager --flake .";
      hms = "home-manager -b bkup --flake .#gburd@$(hostname) switch";

      # Locate
      locate = "plocate";
    } // optionalAttrs hasEza {
      # Modern Unix tools
      ls = "eza";
      exa = "eza";
    } // optionalAttrs hasNeovim {
      # Editor shortcuts
      vim = "nvim";
      vi = "nvim";
      v = "nvim";
    } // optionalAttrs hasEmacs {
      e = "emacsclient -t";
    } // optionalAttrs hasNeomutt {
      # Mail shortcuts
      mutt = "neomutt";
      m = "neomutt";
    } // optionalAttrs hasKitty {
      # Kitty shortcuts
      cik = "clone-in-kitty --type os-window";
      ck = "clone-in-kitty --type os-window";
    };

    # Bash functions (porting Fish functions)
    bashrcExtra = ''
      # Disable ctrl-s/ctrl-q flow control (only in interactive terminals)
      if [ -t 0 ]; then
        stty -ixon 2>/dev/null || true
      fi

    '' + optionalString (hasNeovim && hasRipgrep) ''
      # Grep using ripgrep and pass to nvim (from Fish)
      nvimrg() {
        nvim -q <(rg --vimgrep "$@")
      }
      alias vrg=nvimrg

    '' + optionalString hasShellColor ''
      # Integrate ssh with shellcolord (from Fish)
      ssh() {
        ${shellcolor} disable $$
        if [ -n "$KITTY_PID" ] && [ -n "$KITTY_WINDOW_ID" ] && command -v kitty >/dev/null 2>&1; then
          command kitty +kitten ssh "$@"
        else
          command ssh "$@"
        fi
        ${shellcolor} enable $$
        ${shellcolor} apply $$
      }

    '' + ''
      export VISUAL="$EDITOR"
    '';

    historyControl = [ "erasedups" "ignorespace" ];
    historyIgnore = [ "ls" "cd" "exit" ];
    historySize = 10000;
    historyFileSize = 100000;
  };
}
