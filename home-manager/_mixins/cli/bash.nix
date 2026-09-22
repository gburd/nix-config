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

      # ---- Prompt: match the fish prompt -------------------------------
      # fish renders (fish's own default, wrapped by terax.fish):
      #   gburd@floki ~/w/nix-config (main)>
      # i.e. user@host, fish-style abbreviated cwd, git branch in parens, then
      # ">" ("#" for root). Reproduce that in bash.
      #
      # fish's prompt_pwd abbreviates every INTERMEDIATE component to its first
      # character (plus a leading dot for hidden dirs) and keeps the last
      # component whole: ~/ws/nix-config -> ~/w/nix-config. Done with awk so
      # there's no per-component subshell loop on every prompt.
      __prompt_pwd() {
        local p="$PWD"
        case "$p" in
          "$HOME") printf '~'; return ;;
          "$HOME"/*) p="~/''${p#"$HOME"/}" ;;
        esac
        printf '%s' "$p" | awk -F/ '{
          for (i = 1; i <= NF; i++) {
            if (i < NF && $i != "" && $i != "~") {
              # keep a leading dot on hidden dirs, then one char
              if (substr($i, 1, 1) == ".") $i = substr($i, 1, 2); else $i = substr($i, 1, 1)
            }
            printf "%s%s", $i, (i < NF ? "/" : "")
          }
        }'
      }

      # Git branch as " (name)", matching fish_vcs_prompt's plain form. Quiet
      # and cheap: one rev-parse, no status/dirty scan (that would stat the
      # whole worktree on every prompt in big repos like postgres).
      __prompt_vcs() {
        local b
        b=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
          || b=$(git rev-parse --short HEAD 2>/dev/null) \
          || return 0
        [ -n "$b" ] && printf ' (%s)' "$b"
      }

      __set_prompt() {
        local suffix='>'
        [ "$EUID" -eq 0 ] && suffix='#'
        # \[..\] wrappers keep readline's line-length math correct.
        # No space before the suffix: fish emits "... (main)> ", not "(main) > ".
        PS1="\[\e[97m\]\u\[\e[0m\]@\h \[\e[36m\]$(__prompt_pwd)\[\e[0m\]$(__prompt_vcs)$suffix "
      }
      # Preserve anything already in PROMPT_COMMAND (other modules append to it).
      case "''${PROMPT_COMMAND:-}" in
        *__set_prompt*) : ;;
        "") PROMPT_COMMAND=__set_prompt ;;
        *) PROMPT_COMMAND="__set_prompt;''${PROMPT_COMMAND}" ;;
      esac
    '';

    historyControl = [ "erasedups" "ignorespace" ];
    historyIgnore = [ "ls" "cd" "exit" ];
    historySize = 10000;
    historyFileSize = 100000;
  };
}
