{ ... }:
# WezTerm — GPU-accelerated terminal + multiplexer. GUI hosts (floki, arnold).
# Appearance matched to what Alacritty ACTUALLY renders: the legacy
# alacritty.yml is dead (modern Alacritty reads alacritty.toml, which sets no
# colors/font), so Alacritty runs with its built-in DARK defaults + full
# window decorations. This config mirrors that: dark background (#1d1f21),
# light foreground, full titlebar/borders, FiraCode Nerd Font. tmux is the
# multiplexer (see console/tmux.nix).
#
# NOTE: home-manager's programs.wezterm wraps extraConfig as:
#   local wezterm = require 'wezterm';
#   <extraConfig>
# so `wezterm` is already in scope; extraConfig just builds and returns config.
{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local config = wezterm.config_builder()

      -- Font: FiraCode Nerd Font (installed), size 14 to match prior setup.
      config.font = wezterm.font("FiraCode Nerd Font")
      config.font_size = 14.0

      -- Colors: dark, matching Alacritty's actual runtime look (its built-in
      -- dark defaults ~ base16 "Tomorrow Night").
      config.colors = {
        foreground = "#c5c8c6",
        background = "#1d1f21",
        cursor_fg = "#1d1f21",
        cursor_bg = "#c5c8c6",
        cursor_border = "#c5c8c6",
        selection_fg = "#1d1f21",
        selection_bg = "#c5c8c6",
        ansi = {
          "#1d1f21", -- black
          "#cc6666", -- red
          "#b5bd68", -- green
          "#f0c674", -- yellow
          "#81a2be", -- blue
          "#b294bb", -- magenta
          "#8abeb7", -- cyan
          "#c5c8c6", -- white
        },
        brights = {
          "#969896", -- black
          "#de935f", -- red
          "#b5bd68", -- green
          "#f0c674", -- yellow
          "#81a2be", -- blue
          "#b294bb", -- magenta
          "#8abeb7", -- cyan
          "#ffffff", -- white
        },
      }

      -- Cursor: steady block (Alacritty default is a block cursor).
      config.default_cursor_style = "SteadyBlock"

      -- Window: ONE title bar only — WezTerm's own fancy tab bar, which hosts
      -- the window controls (integrated buttons). "RESIZE" alone means no
      -- server-side (WM) titlebar, so GNOME/Wayland won't draw a SECOND bar
      -- on top; the integrated buttons in the tab bar are the title bar.
      -- (INTEGRATED_BUTTONS|RESIZE previously produced two bars because the
      -- WM still drew its own.)
      config.window_decorations = "RESIZE"
      config.integrated_title_button_style = "Gnome"
      config.window_background_opacity = 1.0
      -- Bottom clipping when maximized: on GNOME/Wayland CSD the maximized
      -- surface height isn't an exact multiple of the cell height, so the
      -- last text row is drawn past the visible edge and clipped. A larger
      -- bottom pad absorbs the partial cell so the last row stays visible.
      config.window_padding = { left = 2, right = 2, top = 2, bottom = 12 }
      -- Don't resize the window on font-size changes (avoids re-triggering
      -- the partial-cell mismatch).
      config.adjust_window_size_when_changing_font_size = false
      config.audible_bell = "Disabled"

      -- fish is the interactive shell on these hosts.
      config.default_prog = { "fish", "-l" }

      -- Behavior.
      config.max_fps = 120
      config.scrollback_lines = 10000
      config.enable_scroll_bar = false
      -- The fancy tab bar IS the title bar: keep it always visible and put
      -- the integrated window buttons (min/max/close) on it.
      config.enable_tab_bar = true
      config.hide_tab_bar_if_only_one_tab = false
      config.use_fancy_tab_bar = true
      config.show_close_tab_button_in_tabs = true
      config.tab_bar_at_bottom = false
      config.integrated_title_buttons = { "Hide", "Maximize", "Close" }

      return config
    '';
  };
}
