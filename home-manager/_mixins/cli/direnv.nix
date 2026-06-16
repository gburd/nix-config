{ config, lib, ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # direnv stdlib extension: `use project_steering <domain>...` in a project's
  # .envrc layers the chosen domain steering bundles (postgresql / aws / rust)
  # ON TOP of the global universal steering, for every agent — so domain
  # context (e.g. the 15k-char PostgreSQL workflow) only loads in projects
  # that actually need it, instead of bloating every session's context window.
  #
  # Example .envrc:
  #   use flake
  #   use project_steering postgresql
  #
  # The heavy lifting is in the `project-steering` CLI
  # (modules/home-manager/ai/steering.nix), which writes the per-agent
  # project-context files (CLAUDE.md for Claude/Pi, AGENTS.md for
  # Codex/Maki/Pi, .kiro/steering for Kiro). This wrapper just exposes it as
  # a direnv `use_` function and re-triggers when those files change.
  home.file.".config/direnv/lib/project-steering.sh" = lib.mkIf config.programs.ai.steering.enable {
    text = ''
      use_project_steering() {
        if has project-steering; then
          project-steering "$@" >/dev/null 2>&1 || true
          watch_file .claude/CLAUDE.md AGENTS.md
        fi
      }
    '';
  };
}
