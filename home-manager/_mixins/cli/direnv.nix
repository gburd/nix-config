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

      # Per-project HEAVY MCP servers (github/postgresq/context7/llms-docs)
      # are opt-in to keep the global session context small. In .envrc:
      #   use project_mcp github postgresq
      # writes ./.mcp.json which Claude + Pi read from the project dir.
      use_project_mcp() {
        if has project-mcp; then
          project-mcp "$@" >/dev/null 2>&1 || true
          watch_file .mcp.json
        fi
      }

      # Per-project git policy overrides. Global default (must-rules.md,
      # pi's safety-hooks.ts) is: never force-push without explicit
      # in-session approval. Some projects (e.g. a personal repo where you
      # own history and rebase workflows are the norm) genuinely need
      # --force-with-lease routinely. Rather than weaken the global rule
      # for every project, opt in per-project via .envrc:
      #   use git_policy allow-force-push
      # Exports PI_ALLOW_FORCE_PUSH=1 for the direnv-managed shell; pi's
      # safety-hooks.ts checks it and lets --force-with-lease through (still
      # blocks bare --force, which discards a concurrent remote change
      # instead of just checking for one). Scoped to direnv's shell env, so
      # it only applies inside this project's directory tree.
      use_git_policy() {
        for arg in "$@"; do
          case "$arg" in
            allow-force-push) export PI_ALLOW_FORCE_PUSH=1 ;;
            *) echo "use_git_policy: unknown policy '$arg' (known: allow-force-push)" >&2 ;;
          esac
        done
      }
    '';
  };
}
