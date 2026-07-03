{ ... }:
# WezTerm — GPU-accelerated terminal + multiplexer. GUI hosts (floki, arnold).
# Appearance matched to the Alacritty config
# (home-manager/_mixins/users/gburd/alacritty.yml): the "Tomorrow" (light)
# base16 palette, FiraCode Nerd Font Mono size 14, block cursor with custom
# colors, opaque background. tmux is the multiplexer (see console/tmux.nix),
# so WezTerm's own multiplexing keys stay at defaults — tmux owns splits/tabs.
{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require("wezterm")
      local config = wezterm.config_builder()

      -- Font: match Alacritty (FiraCode Nerd Font Mono, size 14).
      config.font = wezterm.font("FiraCode Nerd Font Mono")
      config.font_size = 14.0

      -- Colors: the "Tomorrow" (light) base16 scheme from alacritty.yml.
      config.colors = {
        foreground = "#4d4d4c",
        background = "#ffffff",
        cursor_fg = "#ffffff",
        cursor_bg = "#4d4d4c",
        cursor_border = "#4d4d4c",
        -- normal
        ansi = {
          "#ffffff", -- black
          "#c82829", -- red
          "#718c00", -- green
          "#eab700", -- yellow
          "#4271ae", -- blue
          "#8959a8", -- magenta
          "#3e999f", -- cyan
          "#4d4d4c", -- white
        },
        -- bright
        brights = {
          "#8e908c", -- black
          "#f5871f", -- red
          "#e0e0e0", -- green
          "#d6d6d6", -- yellow
          "#969896", -- blue
          "#282a2e", -- magenta
          "#a3685a", -- cyan
          "#1d1f21", -- white
        },
      }

      -- Cursor: block (Alacritty style = Block, no blink).
      config.default_cursor_style = "SteadyBlock"

      -- Window: opaque, native decorations (Alacritty opacity 1.0).
      config.window_background_opacity = 1.0
      config.window_decorations = "TITLE|RESIZE"
      config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
      config.audible_bell = "Disabled"

      -- fish is the interactive shell on these hosts.
      config.default_prog = { "fish", "-l" }

      -- Behavior.
      config.max_fps = 120
      config.scrollback_lines = 10000
      config.enable_scroll_bar = false
      config.hide_tab_bar_if_only_one_tab = true

      return config
    '';
  };
}
