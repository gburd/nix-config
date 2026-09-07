{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.programs.ai.skills;
  inherit (lib) mkEnableOption mkOption types;

  ###
  # Skill source trees that ponytail/asm/superpowers draw from. Each is a
  # pinned flake input.
  ###
  ponytailSrc = inputs.ponytail or null;
  superpowersSrc = inputs.superpowers or null;

  ###
  # In-tree operator skills
  #
  # These are the skills curated and edited locally (drifted from any
  # upstream copy — for example the postgresq SKILL.md is now on the
  # pg.ddx.io URL while skills.git still uses postgr.esq).
  ###
  kiroSkillNames = [
    "aws-benchmark"
    "btw"
    "checkpoint"
    "coccinelle"
    "dream"
    "flex-bison-to-lime"
    "maintain-docs"
    "memelord-init"
    "pg-numa-benchmark"
    "postgresq"
    "review-diff"
    "stop-slop"
    "think-hard"
    "watchdog"
    # workflow.md progressive-disclosure skills (conditional operational
    # knowledge moved out of always-on steering to cut global context).
    "release-tagging"
    "nix-agent-configs"
    "subagent-teams"
  ];

  # Kiro skills with nested reference directories (subdirs under references/)
  kiroSkillDeepDirs = {
    hegel = ./files/kiro-skills/hegel;
  };

  claudeSkillNames = [
    "btw"
    "checkpoint"
    "coccinelle"
    "dream"
    "maintain-docs"
    "memelord-init"
    "pg-numa-benchmark"
    "review-diff"
    "think-hard"
    "watchdog"
  ];

  # Claude skills deployed as directories (multiple files per skill)
  claudeSkillDirs = {
    aws-benchmark = ./files/claude-skills/aws-benchmark;
    hegel = ./files/claude-skills/hegel;
    postgresq = ./files/claude-skills/postgresq;
    stop-slop = ./files/claude-skills/stop-slop;
    # workflow.md progressive-disclosure skills (see kiroSkillNames).
    release-tagging = ./files/claude-skills/release-tagging;
    nix-agent-configs = ./files/claude-skills/nix-agent-configs;
    subagent-teams = ./files/claude-skills/subagent-teams;
  };

  # Recursively collect all files from a directory tree
  collectFiles = prefix: dir:
    let
      entries = builtins.readDir dir;
      names = builtins.attrNames entries;
    in
    builtins.concatMap
      (name:
        if entries.${name} == "directory"
        then collectFiles "${prefix}/${name}" (dir + "/${name}")
        else [{ path = "${prefix}/${name}"; source = dir + "/${name}"; }]
      )
      names;

  claudeSkillDirFiles = builtins.listToAttrs (builtins.concatMap
    (name:
      let files = collectFiles ".claude/skills/${name}" claudeSkillDirs.${name};
      in
      map (f: { name = f.path; value = { inherit (f) source; }; }) files
    )
    (builtins.attrNames claudeSkillDirs));

  kiroSkillDeepDirFiles = builtins.listToAttrs (builtins.concatMap
    (name:
      let files = collectFiles ".kiro/skills/${name}" kiroSkillDeepDirs.${name};
      in
      map (f: { name = f.path; value = { inherit (f) source; }; }) files
    )
    (builtins.attrNames kiroSkillDeepDirs));

  kiroSkillFiles = builtins.listToAttrs (builtins.concatMap
    (name:
      let
        skillDir = ./files/kiro-skills/${name};
        hasRefs = builtins.pathExists (skillDir + "/references");
        refFiles =
          if hasRefs
          then builtins.attrNames (builtins.readDir (skillDir + "/references"))
          else [ ];
      in
      [{
        name = ".kiro/skills/${name}/SKILL.md";
        value = { source = skillDir + "/SKILL.md"; };
      }]
      ++ map
        (ref: {
          name = ".kiro/skills/${name}/references/${ref}";
          value = { source = skillDir + "/references/${ref}"; };
        })
        refFiles
    )
    kiroSkillNames);

  claudeSkillFiles = builtins.listToAttrs (map
    (name: {
      name = ".claude/skills/${name}.md";
      value = { source = ./files/claude-skills/${name}.md; };
    })
    claudeSkillNames);

  ###
  # Upstream skills.git blend
  #
  # Each agent branch of https://codeberg.org/ddx/skills.git is a flake
  # input (see flake.nix). We deploy each branch as a single recursive
  # symlink under the corresponding agent skills dir, in a clearly-named
  # subdir so it can't collide with the in-tree operator skills above.
  #
  # The 13 SKILL.md files at each branch root land at depth 2
  # (e.g. ~/.kiro/skills/skills-git-kiro/btw/SKILL.md), so the agent
  # skill discoverers (which scan depth 1) won't surface them as
  # invokable skills. They're reference material, available to operator
  # skills that want to cite them.
  #
  # The shared content (community/, examples/, generic/) and per-agent
  # extras (claude/, pi/, kiro/, codex/, maki/) become available under
  # the skills-git-<branch>/ namespace.
  ###
  skillsGitDeployments = {
    claude = {
      input = inputs.postgresq-skills-claude or null;
      target = ".claude/skills/skills-git-claude";
    };
    pi = {
      input = inputs.postgresq-skills-pi or null;
      # Pi reads ~/.kiro/skills/ (see modules/home-manager/ai/pi.nix);
      # use a Pi-specific subdir to avoid colliding with the kiro branch.
      target = ".kiro/skills/skills-git-pi";
    };
    kiro = {
      input = inputs.postgresq-skills-kiro or null;
      target = ".kiro/skills/skills-git-kiro";
    };
    codex = {
      input = inputs.postgresq-skills-codex or null;
      target = ".codex/skills/skills-git-codex";
    };
    maki = {
      input = inputs.postgresq-skills-maki or null;
      target = ".maki/skills/skills-git-maki";
    };
  };

  enabledSkillsGitBranches = lib.filterAttrs
    (name: _: cfg.skillsGit.branches.${name}.enable)
    skillsGitDeployments;

  skillsGitFiles = lib.mapAttrs'
    (_name: spec: lib.nameValuePair spec.target {
      source = spec.input;
      recursive = false;
    })
    enabledSkillsGitBranches;

  ###
  # ponytail (Part 3) — cross-agent "lazy senior dev" skill/ruleset.
  #
  # The repo ships per-agent pieces; we deploy the ones our agents read:
  #   - skills/<name>/ → each agent's skills dir (claude/codex/maki + the
  #     kiro tree that Pi also reads)
  #   - .kiro/steering/ponytail.md → ~/.kiro/steering/ (kiro steering)
  #   - pi-extension/ → ~/.pi/agent/extensions/ponytail/ (Pi extension)
  # Mirrors how the skills.git branches are blended.
  ###
  # Deploy ponytail's skill set into one agent skills root as a recursive
  # symlink subdir (can't collide with operator skills).
  ponytailFilesFor = root:
    lib.optionalAttrs (cfg.ponytail.enable && ponytailSrc != null) {
      "${root}/ponytail".source = ponytailSrc + "/skills";
    };

  ponytailFiles = lib.mkMerge [
    (lib.mkIf (cfg.ponytail.enable && ponytailSrc != null && cfg.targets.claude)
      (ponytailFilesFor ".claude/skills"))
    (lib.mkIf (cfg.ponytail.enable && ponytailSrc != null && cfg.targets.kiro) (
      # kiro skills dir (also read by Pi) + kiro steering + Pi extension
      (ponytailFilesFor ".kiro/skills") // {
        ".kiro/steering/ponytail.md".source = ponytailSrc + "/.kiro/steering/ponytail.md";
        ".pi/agent/extensions/ponytail".source = ponytailSrc + "/pi-extension";
      }
    ))
    # codex + maki always get ponytail when enabled (no per-target toggle,
    # mirroring how the skills.git codex/maki branches deploy).
    (lib.mkIf (cfg.ponytail.enable && ponytailSrc != null)
      ((ponytailFilesFor ".codex/skills") // (ponytailFilesFor ".maki/skills")))
  ];

  ###
  # superpowers (obra/superpowers) — CURATED SUBSET.
  #
  # Upstream is a whole opinionated methodology (spec -> plan -> TDD ->
  # subagent-driven execution -> review -> merge) with its own doc-path
  # conventions (docs/superpowers/plans/, docs/superpowers/specs/) and a
  # dozen skills, several of which overlap or conflict with what we already
  # have (brainstorming vs. our own dream/checkpoint, subagent-driven-
  # development vs. subagent-teams). Rather than deploy the whole tree and
  # let it fight our existing skills, we symlink in just the FOUR that fill
  # a real gap: structured spec-writing, plan-writing, red/green TDD
  # enforcement, and parallel subagent dispatch. Each is deployed as its
  # own named subdir (not merged into one "superpowers" tree) so it reads
  # as an independent skill, same shape as our in-tree operator skills.
  #
  # brainstorming's scripts/ + visual-companion.md (an OPTIONAL local
  # webserver for browser-based mockup review, referenced conditionally in
  # SKILL.md -- not needed for the core text-based flow) are excluded: they
  # aren't used by the text-based flow, so there's no reason to deploy the
  # extra webserver scripts. (They also used to trip the since-removed
  # SkillSpector gate's heuristic scanner into a false-positive CRITICAL
  # verdict; the exclusion still stands on its own merit -- don't deploy
  # what isn't needed.)
  ###
  superpowersSkillNames = [
    "brainstorming"
    "writing-plans"
    "test-driven-development"
    "dispatching-parallel-agents"
  ];

  superpowersExcludePaths = {
    brainstorming = [ "scripts" "visual-companion.md" ];
  };

  superpowersSkillFiles = name:
    let
      excluded = superpowersExcludePaths.${name} or [ ];
      files = collectFiles "" (superpowersSrc + "/skills/${name}");
    in
    lib.filter
      (f: !(lib.any (ex: f.path == "/${ex}" || lib.hasPrefix "/${ex}/" f.path) excluded))
      files;

  superpowersFilesFor = root:
    lib.optionalAttrs (cfg.superpowers.enable && superpowersSrc != null) (
      builtins.listToAttrs (builtins.concatMap
        (name:
          map
            (f: {
              name = "${root}/superpowers-${name}${f.path}";
              value = { inherit (f) source; };
            })
            (superpowersSkillFiles name))
        superpowersSkillNames)
    );

  # Filtered copy of just the deployed subset (selected skills, minus
  # excluded paths applied at deployment (see superpowersFilesFor via
  # collectFiles, which honors superpowersExcludePaths per skill).
  superpowersFiles = lib.mkMerge [
    (lib.mkIf (cfg.superpowers.enable && superpowersSrc != null && cfg.targets.claude)
      (superpowersFilesFor ".claude/skills"))
    (lib.mkIf (cfg.superpowers.enable && superpowersSrc != null && cfg.targets.kiro)
      (superpowersFilesFor ".kiro/skills"))
    # codex + maki always get the subset when enabled, mirroring ponytail.
    (lib.mkIf (cfg.superpowers.enable && superpowersSrc != null)
      ((superpowersFilesFor ".codex/skills") // (superpowersFilesFor ".maki/skills")))
  ];

  ###
  # asm (Part 2) — agent-skill-manager as the cross-agent management layer.
  #
  # asm is installed as a CLI (npm wrapper, like memelord) and its config is
  # deployed declaratively. We point its providers at the SAME skill dirs Nix
  # deploys into, and add the two providers asm lacks/mis-points:
  #   - kiro (not a built-in asm provider) → ~/.kiro/skills
  #   - pi: built-in default is ~/.pi/skills, but our Pi reads ~/.kiro/skills
  #     (see pi.nix), so repoint it.
  # Nix remains the deployer of record; asm is for interactive curation,
  # search, audit, dedup, and `asm audit security` across all agents.
  ###
  asmWrapper = pkgs.writeShellApplication {
    name = "asm";
    runtimeInputs = [ pkgs.nodejs pkgs.git pkgs.gh ];
    text = ''
      export NPM_CONFIG_PREFIX="''${HOME}/.npm-global"
      mkdir -p "$NPM_CONFIG_PREFIX"
      exec npx -y agent-skill-manager@latest "$@"
    '';
  };

  asmConfig = {
    version = 1;
    providers = [
      { name = "claude"; label = "Claude Code"; global = "~/.claude/skills"; project = ".claude/skills"; enabled = cfg.targets.claude; }
      { name = "kiro"; label = "Kiro CLI"; global = "~/.kiro/skills"; project = ".kiro/skills"; enabled = cfg.targets.kiro; }
      # Pi reads ~/.kiro/skills (pi.nix), NOT asm's default ~/.pi/skills.
      { name = "pi"; label = "Pi"; global = "~/.kiro/skills"; project = ".kiro/skills"; enabled = true; }
      { name = "codex"; label = "Codex"; global = "~/.codex/skills"; project = ".codex/skills"; enabled = true; }
      { name = "maki"; label = "Maki"; global = "~/.maki/skills"; project = ".maki/skills"; enabled = true; }
    ];
    customPaths = [ ];
    preferences = {
      # Run a security audit before installing any skill.
      auditOnInstall = true;
    };
  };

  asmFiles = lib.optionalAttrs cfg.asm.enable {
    ".config/agent-skill-manager/config.json".text = builtins.toJSON asmConfig;
  };
in
{
  options.programs.ai.skills = {
    enable = mkEnableOption "Deploy AI agent skills (in-tree operator skills + skills.git blend)";

    targets = {
      kiro = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy in-tree operator skills to ~/.kiro/skills/";
      };
      claude = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy in-tree operator skills to ~/.claude/skills/";
      };
    };

    skillsGit = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Deploy upstream PostgreSQL community skills from
          https://codeberg.org/ddx/skills.git as a blend over the in-tree
          operator skills. Per-branch toggles below.
        '';
      };
      branches = {
        claude.enable = mkOption {
          type = types.bool;
          default = true;
          description = "Deploy skills.git claude branch to ~/.claude/skills/skills-git-claude/";
        };
        pi.enable = mkOption {
          type = types.bool;
          default = true;
          description = "Deploy skills.git pi branch to ~/.kiro/skills/skills-git-pi/ (Pi reads ~/.kiro/skills/)";
        };
        kiro.enable = mkOption {
          type = types.bool;
          default = true;
          description = "Deploy skills.git kiro branch to ~/.kiro/skills/skills-git-kiro/";
        };
        codex.enable = mkOption {
          type = types.bool;
          default = true;
          description = "Deploy skills.git codex branch to ~/.codex/skills/skills-git-codex/";
        };
        maki.enable = mkOption {
          type = types.bool;
          default = true;
          description = "Deploy skills.git maki branch to ~/.maki/skills/skills-git-maki/";
        };
      };
    };

    # Part 2: asm (agent-skill-manager) as the cross-agent management layer.
    asm = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Install the `asm` CLI (agent-skill-manager) and deploy its config
          (~/.config/agent-skill-manager/config.json) with providers pointed
          at our actual per-agent skill dirs (incl. a custom kiro provider
          and pi repointed to ~/.kiro/skills). asm is the interactive
          management/curation/audit layer; Nix remains the deployer.
        '';
      };
    };

    # Part 3: ponytail cross-agent ruleset/skill.
    ponytail = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Deploy the ponytail (DietrichGebert/ponytail) skill set + kiro
          steering file + Pi extension to all agents.
        '';
      };
    };

    # superpowers (obra/superpowers) — curated 4-skill subset.
    superpowers = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Deploy a curated subset of obra/superpowers (brainstorming,
          writing-plans, test-driven-development, dispatching-parallel-
          agents) to all agents, as superpowers-<name> subdirs alongside
          the in-tree operator skills. NOT the whole upstream methodology
          (its doc-path conventions and several overlapping/conflicting
          skills are deliberately excluded -- see skills.nix comment).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional cfg.asm.enable asmWrapper;

    home.file = lib.mkMerge [
      (lib.mkIf cfg.targets.kiro kiroSkillFiles)
      (lib.mkIf cfg.targets.kiro kiroSkillDeepDirFiles)
      (lib.mkIf cfg.targets.claude claudeSkillFiles)
      (lib.mkIf cfg.targets.claude claudeSkillDirFiles)
      (lib.mkIf cfg.skillsGit.enable skillsGitFiles)
      ponytailFiles
      superpowersFiles
      asmFiles
    ];
  };
}
