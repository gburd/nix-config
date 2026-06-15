{ config, lib, pkgs, ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # direnv stdlib extension: `use claude_steering <domain>...` in a project's
  # .envrc generates that project's .claude/CLAUDE.md @importing the chosen
  # domain steering bundles (postgresql / aws / rust) ON TOP of the global
  # universal steering — so domain context (e.g. the 15k-char PostgreSQL
  # workflow) only loads in projects that actually need it, instead of
  # bloating every Claude Code session's context window.
  #
  # Example .envrc:
  #   use flake
  #   use claude_steering postgresql
  #
  # The heavy lifting is in the `claude-steering` CLI
  # (modules/home-manager/ai/steering.nix); this wrapper just exposes it as
  # a direnv `use_` function and re-triggers when .claude/CLAUDE.md changes.
  home.file.".config/direnv/lib/claude-steering.sh" = lib.mkIf config.programs.ai.steering.enable {
    text = ''
      use_claude_steering() {
        if has claude-steering; then
          claude-steering "$@" >/dev/null 2>&1 || true
          watch_file .claude/CLAUDE.md
        fi
      }
    '';
  };
}
