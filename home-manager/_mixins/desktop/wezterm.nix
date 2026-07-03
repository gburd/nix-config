{ ... }:
# WezTerm — GPU-accelerated terminal + multiplexer. GUI hosts (floki, arnold).
# Config adapted from Kun Chen's wezterm.lua (rose-pine-moon, integrated
# titlebar, inactive-pane dimming, opacity/blur) but tuned for this setup:
# FiraCode Nerd Font (the font actually installed system-wide here), fish as
# the default shell, and Linux-appropriate window settings. tmux is the
# multiplexer of choice (see console/tmux.nix), so WezTerm's own multiplexing
# keys are left at defaults — tmux owns splits/tabs.
{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require("wezterm")
      local config = wezterm.config_builder()

      -- Appearance (Kun's palette)
      config.color_scheme = "rose-pine-moon"
      config.max_fps = 120
      config.font = wezterm.font("FiraCode Nerd Font", { weight = "DemiBold" })
      config.font_size = 13.0
      config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
      config.window_frame = {
        font = wezterm.font("FiraCode Nerd Font", { weight = "Bold" }),
        font_size = 12.0,
      }
      -- Dim inactive panes so the focused one stands out (Kun's setting).
      config.inactive_pane_hsb = {
        saturation = 0.0,
        brightness = 0.5,
      }

      -- Slight transparency (Linux). Compositor-dependent; harmless if the WM
      -- ignores it.
      config.window_background_opacity = 0.95

      -- fish is the interactive shell on these hosts.
      config.default_prog = { "fish", "-l" }

      -- Scrollback + sane defaults.
      config.scrollback_lines = 10000
      config.enable_scroll_bar = false
      config.hide_tab_bar_if_only_one_tab = true
      config.audible_bell = "Disabled"

      return config
    '';
  };
}
