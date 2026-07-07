_:
# WezTerm — GPU-accelerated terminal + multiplexer. GUI hosts (floki, arnold).
# Appearance matched to what Alacritty ACTUALLY renders: the legacy
# alacritty.yml is dead (modern Alacritty reads alacritty.toml, which sets no
# colors/font), so Alacritty runs with its built-in DARK defaults + full
# window decorations. This config mirrors that: dark background (#1d1f21),
# light foreground, full titlebar/borders, FiraCode Nerd Font. tmux is the
# multiplexer (see console/tmux.nix).
#
# OOM protection: WezTerm is a SINGLE process (wezterm-gui) drawing ALL
# windows/tabs/panes (unlike Alacritty's process-per-window), so if the
# kernel OOM-kills wezterm-gui, EVERY window dies at once. The user systemd
# manager sets DefaultOOMScoreAdjust=200, so wezterm-gui + its children all
# start ~200 and wezterm-gui can be picked as the victim under pressure.
# Unprivileged processes can only RAISE oom_score_adj (never lower), so we
# can't protect wezterm directly from user space. Instead: run heavy jobs via
# the `heavy` wrapper (console/default.nix) — it raises the job's score to
# +900 so the kernel always reaps THAT process first, sparing the terminal.
# `agent-sandbox --mem` does the same (--oom=900) for agents/sandboxed work.
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
      -- Font: FiraCode Nerd Font primary, with an explicit fallback chain so
      -- codepoints FiraCode lacks (broad symbols, CJK, emoji) still render
      -- instead of logging "No glyph for U+XXXX". These fallback fonts are
      -- installed system-wide (see nixos/default.nix fonts).
      config.font = wezterm.font_with_fallback({
        "FiraCode Nerd Font",
        "Symbols Nerd Font Mono", -- full Nerd Font symbol/icon set
        "Noto Sans CJK JP",       -- CJK
        "Noto Color Emoji",       -- emoji
        "Noto Sans Mono",         -- broad Unicode mono fallback
      })
      config.font_size = 14.0
      -- Don't log a warning when a glyph is still missing after the fallback
      -- chain (rare now that the chain covers symbols/CJK/emoji).
      config.warn_about_missing_glyphs = false

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

      -- Window: ONE bar — WezTerm's fancy tab bar hosts the window buttons
      -- (min/maximize/close), Gnome-style. INTEGRATED_BUTTONS makes WezTerm
      -- draw its own buttons AND skip server-side decorations, so there's a
      -- single bar (no double titlebar) that still HAS the buttons. RESIZE
      -- keeps resize borders. The maximize bottom-row clip is handled by the
      -- bottom padding below, not by dropping decorations.
      config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
      config.integrated_title_button_style = "Gnome"
      config.window_background_opacity = 1.0
      -- Belt-and-suspenders against a partial last cell when maximized: pad
      -- the bottom by ~one line height (font 14 -> ~28px).
      config.window_padding = { left = 2, right = 2, top = 2, bottom = 28 }
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
