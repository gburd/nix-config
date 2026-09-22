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

      # ---- Prompt --------------------------------------------------------
      # Renders, matching the fish prompt:
      #   gburd@floki ~/w/nix-config (main)>
      #   user@host  cwd(abbrev)  git-branch  >   ("#" when root)
      # and on a failed command the exit code is shown in red:
      #   gburd@floki ~/w/nix-config (main) [1]>
      #
      # EFFICIENCY. Everything that bash can expand itself is left to bash --
      # \u \h \$ are builtins, and PROMPT_DIRTRIM gives cwd shortening with
      # zero processes. The only external work is git's own __git_ps1, and only
      # inside a repo. No subshell per component, no `git status` (that stats
      # the whole worktree -- painful in postgres-sized trees), and no
      # per-prompt fork like the powerline-go setup this replaces.
      #
      # __git_ps1 comes from git's contrib and understands worktrees, detached
      # HEAD, rebase/merge/bisect state. Guarded so a git without it degrades to
      # a branch-less prompt rather than erroring every prompt.
      if [ -r ${pkgs.git}/share/bash-completion/completions/git-prompt.sh ]; then
        . ${pkgs.git}/share/bash-completion/completions/git-prompt.sh
      fi

      # Shorten long paths to the last 3 components (bash-internal, no fork).
      # Note this differs slightly from fish's prompt_pwd, which abbreviates
      # intermediate components to one char instead of eliding them; matching
      # that exactly needed an awk call on every prompt, which isn't worth it.
      PROMPT_DIRTRIM=3

      # Colours via tput when the terminal supports them, empty strings when not
      # (so the prompt stays readable in dumb terminals and piped contexts).
      if [ -t 1 ] && [ "''${TERM:-dumb}" != "dumb" ] && command -v tput >/dev/null 2>&1; then
        __p_user=$(tput bold 2>/dev/null)
        __p_cwd=$(tput setaf 6 2>/dev/null)
        __p_git=$(tput setaf 3 2>/dev/null)
        __p_err=$(tput setaf 1 2>/dev/null)
        __p_off=$(tput sgr0 2>/dev/null)
      else
        __p_user= __p_cwd= __p_git= __p_err= __p_off=
      fi

      # Exit status, only when non-zero. Set by PROMPT_COMMAND because $? has to
      # be captured before anything else runs.
      __prompt_status() {
        local e=$?
        if [ "$e" -ne 0 ]; then __p_status=" [$e]"; else __p_status=""; fi
        return $e
      }
      case "''${PROMPT_COMMAND:-}" in
        *__prompt_status*) : ;;
        "") PROMPT_COMMAND=__prompt_status ;;
        *) PROMPT_COMMAND="__prompt_status;''${PROMPT_COMMAND}" ;;
      esac

      # __git_ps1 substitutes %s; the \[..\] wrappers keep readline's
      # line-length arithmetic correct so long lines wrap properly.
      if type -t __git_ps1 >/dev/null; then
        GIT_PS1_SHOWCOLORHINTS=
        PS1='\[$__p_user\]\u\[$__p_off\]@\h \[$__p_cwd\]\w\[$__p_off\]\[$__p_git\]$(__git_ps1 " (%s)")\[$__p_off\]\[$__p_err\]$__p_status\[$__p_off\]\$ '
      else
        PS1='\[$__p_user\]\u\[$__p_off\]@\h \[$__p_cwd\]\w\[$__p_off\]\[$__p_err\]$__p_status\[$__p_off\]\$ '
      fi
    '';

    historyControl = [ "erasedups" "ignorespace" ];
    historyIgnore = [ "ls" "cd" "exit" ];
    historySize = 10000;
    historyFileSize = 100000;
  };
}
