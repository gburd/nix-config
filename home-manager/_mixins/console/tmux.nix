_:
# tmux — terminal multiplexer, the session backbone for agentic work
# (persistent sessions that survive disconnects, splits for agent + editor +
# test-runner, detach/reattach for long-running agent tasks). Configured
# declaratively via programs.tmux (no TPM — plugins are Nix-managed) so it's
# reproducible across hosts.
#
# Style follows Kun Chen's "L8 Principal's Agentic Engineering Workflow"
# terminal-first setup: C-a prefix, vim pane navigation, mouse on, big
# scrollback, and fast escape so it doesn't fight (neo)vim.
{
  programs.tmux = {
    enable = true;
    prefix = "C-a"; # screen-style prefix, easier reach than C-b
    baseIndex = 1; # windows/panes start at 1 (matches keyboard layout)
    escapeTime = 10; # don't delay ESC in vim
    historyLimit = 100000; # deep scrollback for long agent output
    keyMode = "vi"; # vi copy-mode
    mouse = true; # click/scroll/resize
    terminal = "tmux-256color";

    extraConfig = ''
      # Report modified keys (Ctrl/Meta/Shift combos, e.g. a modified Enter)
      # to apps running inside tmux -- off by default, which is exactly the
      # "Warning: tmux extended-keys is off" pi/other TUIs print on
      # startup. Needed for agents that read raw modified-key sequences
      # (e.g. Shift+Enter for multi-line input).
      set -g extended-keys on

      # True color passthrough (WezTerm / modern terminals).
      set -ga terminal-overrides ",*256col*:Tc,xterm-256color:RGB"

      # Renumber windows when one closes so the list stays contiguous.
      set -g renumber-windows on

      # Focus events (so nvim autoread / autosave-on-focus-lost works).
      set -g focus-events on

      # --- Splits: intuitive | and - , open in the current path -----------
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # C-a C-a sends a literal C-a through to the pane (Emacs/readline
      # "start of line") -- otherwise the prefix eats every C-a, which
      # fights any Emacs-style muscle memory. Standard screen/tmux trick.
      bind C-a send-prefix

      # --- Vim-style pane navigation (prefix h/j/k/l) ----------------------
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Vim-style pane resize (repeatable with -r).
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Quick config reload.
      bind r source-file ~/.config/tmux/tmux.conf \; display "tmux config reloaded"

      # --- Copy mode: vim keys, y to yank ---------------------------------
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # --- Status bar: minimal, dark, readable ----------------------------
      set -g status-position top
      set -g status-interval 5
      set -g status-style "bg=#232136,fg=#e0def4"
      set -g status-left "#[bold] #S #[nobold]"
      set -g status-left-length 30
      set -g status-right "#[fg=#908caa] %Y-%m-%d %H:%M "
      set -g window-status-current-style "fg=#f6c177,bold"
      set -g pane-active-border-style "fg=#f6c177"
      set -g pane-border-style "fg=#393552"
    '';
  };
}
