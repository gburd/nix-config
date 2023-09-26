{ pkgs, lib, config, ... }:
let
  inherit (lib) mkIf;
  hasPackage = pname: lib.any (p: p ? pname && p.pname == pname) config.home.packages;
  hasRipgrep = hasPackage "ripgrep";
  hasExa = hasPackage "eza";
  hasNeovim = config.programs.neovim.enable;
  hasEmacs = config.programs.emacs.enable;
  hasNeomutt = config.programs.neomutt.enable;
  hasShellColor = if builtins.hasAttr "shellcolor" config.programs then config.programs.shellcolor.enable else false;
  hasKitty = config.programs.kitty.enable;
  shellcolor = "${pkgs.shellcolord}/bin/shellcolor";
in
{
  programs.fish = {
    enable = true;
    shellAbbrs = rec {
      jqless = "jq -C | less -r";

      n = "nix";
      nd = "nix develop -c $SHELL";
      ns = "nix shell";
      nsn = "nix shell nixpkgs#";
      nb = "nix build";
      nbn = "nix build nixpkgs#";
      nf = "nix flake";

      nr = "nixos-rebuild --flake .";
      nrs = "nixos-rebuild --flake . switch";
      snr = "sudo nixos-rebuild --flake .";
      snrs = "sudo nixos-rebuild --flake . switch";
      hm = "home-manager --flake .";
      hms = "home-manager --flake . switch";

      ls = mkIf hasExa "eza";
      exa = mkIf hasExa "eza";

      e = mkIf hasEmacs "emacsclient -t";

      vrg = mkIf (hasNeomutt && hasRipgrep) "nvimrg";
      vim = mkIf hasNeovim "nvim";
      vi = vim;
      v = vim;

      mutt = mkIf hasNeomutt "neomutt";
      m = mutt;

      cik = mkIf hasKitty "clone-in-kitty --type os-window";
      ck = cik;
    };
    shellAliases = {
      # Clear screen and scrollback
      clear = "printf '\\033[2J\\033[3J\\033[1;1H'";
    };
    functions = {
      # Disable greeting
      fish_greeting = "";
      # Grep using ripgrep and pass to nvim
      nvimrg = mkIf (hasNeomutt && hasRipgrep) "nvim -q (rg --vimgrep $argv | psub)";
      # Integrate ssh with shellcolord
      ssh = mkIf hasShellColor ''
        ${shellcolor} disable $fish_pid
        # Check if kitty is available
        if set -q KITTY_PID && set -q KITTY_WINDOW_ID && type -q -f kitty
          kitty +kitten ssh $argv
        else
          command ssh $argv
        end
        ${shellcolor} enable $fish_pid
        ${shellcolor} apply $fish_pid
      '';
    };
    interactiveShellInit =
      # Open command buffer in vim when alt+e is pressed
      ''
        bind \ee edit_command_buffer
      '' +
      # kitty integration
      ''
        set --global KITTY_INSTALLATION_DIR "${pkgs.kitty}/lib/kitty"
        set --global KITTY_SHELL_INTEGRATION enabled
        source "$KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_conf.d/kitty-shell-integration.fish"
        set --prepend fish_complete_path "$KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_completions.d"
      '' +
      # Use Emacs bindings and cursors
      # https://gist.githubusercontent.com/zuigon/8852793/raw/770d705897112a870adc2b27d056a61892aa3a9a/keybindings.fish
      ''
        function fish_default_key_bindings -d "Default (Emacs-like) key bindings for fish"

        	# Clear earlier bindings, if any
        	bind --erase --all

        	# This is the default binding, i.e. the one used if no other binding matches
        	bind "" self-insert

        	bind \n execute

        	bind \ck kill-line
        	bind \cy yank
        	bind \t complete

        	bind \e\n "commandline -i \n"

        	bind \e\[A up-or-search
        	bind \e\[B down-or-search
        	bind -k down down-or-search
        	bind -k up up-or-search

        	bind \e\[C forward-char
        	bind \e\[D backward-char
        	bind -k right forward-char
        	bind -k left backward-char

        	bind -k dc delete-char
        	bind -k backspace backward-delete-char
        	bind \x7f backward-delete-char

        	bind \e\[H beginning-of-line
        	bind \e\[F end-of-line

        	# for PuTTY
        	# https://github.com/fish-shell/fish-shell/issues/180
        	bind \e\[1~ beginning-of-line
        	bind \e\[3~ delete-char
        	bind \e\[4~ end-of-line

        	# OS X SnowLeopard doesn't have these keys. Don't show an annoying error message.
        	bind -k home beginning-of-line 2> /dev/null
        	bind -k end end-of-line 2> /dev/null
        	bind \e\[3\;2~ backward-delete-char # Mavericks Terminal.app shift-delete

        	bind \e\eOC nextd-or-forward-word
        	bind \e\eOD prevd-or-backward-word
        	bind \e\e\[C nextd-or-forward-word
        	bind \e\e\[D prevd-or-backward-word
        	bind \eO3C nextd-or-forward-word
        	bind \eO3D prevd-or-backward-word
        	bind \e\[3C nextd-or-forward-word
        	bind \e\[3D prevd-or-backward-word
        	bind \e\[1\;3C nextd-or-forward-word
        	bind \e\[1\;3D prevd-or-backward-word

        	bind \e\eOA history-token-search-backward
        	bind \e\eOB history-token-search-forward
        	bind \e\e\[A history-token-search-backward
        	bind \e\e\[B history-token-search-forward
        	bind \eO3A history-token-search-backward
        	bind \eO3B history-token-search-forward
        	bind \e\[3A history-token-search-backward
        	bind \e\[3B history-token-search-forward
        	bind \e\[1\;3A history-token-search-backward
        	bind \e\[1\;3B history-token-search-forward

        	bind \ca beginning-of-line
        	bind \ce end-of-line
        	bind \ey yank-pop
        	bind \ch backward-delete-char
        	bind \cw backward-kill-word
        	bind \cp history-search-backward
        	bind \cn history-search-forward
        	bind \cf forward-char
        	bind \cb backward-char
        	bind \ct transpose-chars
        	bind \et transpose-words
        	bind \eu upcase-word
        	# This clashes with __fish_list_current_token
        	# bind \el downcase-word
        	bind \ec capitalize-word
        	bind \e\x7f backward-kill-word
        	bind \eb backward-word
        	bind \ef forward-word
        	bind \e\[1\;5C forward-word
        	bind \e\[1\;5D backward-word
        	bind \e\[1\;9A history-token-search-backward # iTerm2
        	bind \e\[1\;9B history-token-search-forward # iTerm2
        	bind \e\[1\;9C forward-word #iTerm2
        	bind \e\[1\;9D backward-word #iTerm2
        	# Bash compatibility
        	# https://github.com/fish-shell/fish-shell/issues/89
        	bind \e. history-token-search-backward
        	bind \ed forward-kill-word
        	bind -k ppage beginning-of-history
        	bind -k npage end-of-history
        	bind \e\< beginning-of-buffer
        	bind \e\> end-of-buffer

        	bind \el __fish_list_current_token
        	bind \ew 'set tok (commandline -pt); if test $tok[1]; echo; whatis $tok[1]; commandline -f repaint; end'
        	bind \cl 'clear; commandline -f repaint'
        	bind \cc 'commandline ""'
        	bind \cu backward-kill-line
        	bind \ed kill-word
        	bind \cw backward-kill-path-component
        	bind \ed 'set -l cmd (commandline); if test -z "$cmd"; echo; dirh; commandline -f repaint; else; commandline -f kill-word; end'
        	bind \cd delete-or-exit

        	# Allow reading manpages by pressing F1
        	bind -k f1 'man (basename (commandline -po; echo))[1] ^/dev/null; or echo -n \a'

        	# This will make sure the output of the current command is paged using the less pager when you press Meta-p
        	bind \ep '__fish_paginate'

        	# shift-tab does a tab complete followed by a search
        	bind --key btab complete-and-search

        	# escape cancels stuff
        	bind \e cancel

        	# term-specific special bindings
        	switch "$TERM"
        		case 'rxvt*'
        			bind \e\[8~ end-of-line
        			bind \eOc forward-word
        			bind \eOd backward-word
        	end
        end
        fish_default_key_bindings
      '' +
      # Use vim bindings and cursors
      ''
        function fish_enable_vi_key_bindings -d "Default (Emacs-like) key bindings for fish"

        	# Clear earlier bindings, if any
        	bind --erase --all
          fish_vi_key_bindings
          set fish_cursor_default     block      blink
          set fish_cursor_insert      line       blink
          set fish_cursor_replace_one underscore blink
          set fish_cursor_visual      block
        end
      '' +
      # Use terminal colors
      ''
        set -U fish_color_autosuggestion      brblack
        set -U fish_color_cancel              -r
        set -U fish_color_command             brgreen
        set -U fish_color_comment             brmagenta
        set -U fish_color_cwd                 green
        set -U fish_color_cwd_root            red
        set -U fish_color_end                 brmagenta
        set -U fish_color_error               brred
        set -U fish_color_escape              brcyan
        set -U fish_color_history_current     --bold
        set -U fish_color_host                normal
        set -U fish_color_match               --background=brblue
        set -U fish_color_normal              normal
        set -U fish_color_operator            cyan
        set -U fish_color_param               brblue
        set -U fish_color_quote               yellow
        set -U fish_color_redirection         bryellow
        set -U fish_color_search_match        'bryellow' '--background=brblack'
        set -U fish_color_selection           'white' '--bold' '--background=brblack'
        set -U fish_color_status              red
        set -U fish_color_user                brgreen
        set -U fish_color_valid_path          --underline
        set -U fish_pager_color_completion    normal
        set -U fish_pager_color_description   yellow
        set -U fish_pager_color_prefix        'white' '--bold' '--underline'
        set -U fish_pager_color_progress      'brwhite' '--background=cyan'
      '';
  };
}
