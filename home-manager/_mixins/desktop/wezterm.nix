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
  # systemd scope drop-in: every WezTerm window/tab launch gets an
  # app-gnome-org.wezfurlong.wezterm-<pid>.scope from gnome-shell. Systemd's
  # dash-truncation rule (systemd.unit(5)) means a drop-in at the truncated
  # name "...wezterm-.scope.d/" applies to ALL those scopes regardless of
  # PID. Without this, the default OOMPolicy (stop) means the kernel OOM
  # killer reaping ANY one child inside the scope (an agent, firejail, a
  # test binary someone ran in a pane) tears down the WHOLE scope — killing
  # wezterm-gui and every window/tab/pane along with it. That kill/respawn
  # is what shows up as edge "ghosting": the new Wayland surface's first
  # frame paints over stale compositor buffer content at the borders.
  # OOMPolicy=continue: log the child's death, keep the terminal running.
  # (We still can't LOWER wezterm-gui's own oom_score_adj from user space —
  # this instead stops one dead child from taking the whole terminal with
  # it, which is what was actually happening per `journalctl -k` history.)
  home.file.".config/systemd/user/app-gnome-org.wezfurlong.wezterm-.scope.d/oom-policy.conf".text = ''
    [Scope]
    OOMPolicy=continue
  '';

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
      -- keeps resize borders.
      config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
      config.integrated_title_button_style = "Gnome"
      config.window_background_opacity = 1.0
      -- Base padding. The bottom row clip when MAXIMIZED is fixed dynamically
      -- by the window-resized handler below (a fixed bottom pad can't cover it
      -- because the leftover pixels depend on the exact maximized height).
      config.window_padding = { left = 2, right = 2, top = 2, bottom = 2 }
      config.adjust_window_size_when_changing_font_size = false
      config.audible_bell = "Disabled"

      -- Last-row clip fix (maximized/tiled on Wayland+GNOME). When the window
      -- is maximized its height is NOT a multiple of the cell height, so the
      -- bottom row is partially clipped. Recompute bottom padding on every
      -- resize/reload: pad the bottom by the leftover pixels (window height
      -- minus the tab bar, modulo one cell) so a whole last row always fits.
      local function fix_bottom_padding(window)
        local ok, dims = pcall(function() return window:get_dimensions() end)
        if not ok or dims == nil then return end
        local overrides = window:get_config_overrides() or {}
        -- cell height in px; fall back to a sane value if unavailable.
        local cell_h = dims.pixel_height
          and dims.dpi
          and math.max(1, math.floor(14.0 * dims.dpi / 72))
          or 28
        -- leftover below the last full row, plus a 1px safety margin.
        local leftover = dims.pixel_height % cell_h
        local bottom = 2 + leftover
        local cur = overrides.window_padding and overrides.window_padding.bottom
        if cur == bottom then return end
        overrides.window_padding =
          { left = 2, right = 2, top = 2, bottom = bottom }
        window:set_config_overrides(overrides)
      end
      wezterm.on('window-resized', function(window, _) fix_bottom_padding(window) end)
      wezterm.on('window-config-reloaded', function(window) fix_bottom_padding(window) end)

      -- bash is the interactive shell on these hosts; -l so ~/.bash_profile runs.
      config.default_prog = { "bash", "-l" }

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
