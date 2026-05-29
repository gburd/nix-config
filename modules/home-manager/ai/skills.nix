{ config, lib, inputs, ... }:
let
  cfg = config.programs.ai.skills;
  inherit (lib) mkEnableOption mkOption types;

  ###
  # In-tree operator skills
  #
  # These are the skills curated and edited locally (drifted from any
  # upstream copy — for example the postgresq SKILL.md is now on the
  # pg.ddx.io URL while skills.git still uses postgr.esq).
  ###
  kiroSkillNames = [
    "btw" "checkpoint" "coccinelle" "dream"
    "flex-bison-to-lime" "maintain-docs" "memelord-init"
    "pg-numa-benchmark" "postgresq" "review-diff" "think-hard"
    "watchdog"
  ];

  # Kiro skills with nested reference directories (subdirs under references/)
  kiroSkillDeepDirs = {
    hegel = ./files/kiro-skills/hegel;
  };

  claudeSkillNames = [
    "btw" "checkpoint" "coccinelle" "dream" "maintain-docs"
    "memelord-init" "pg-numa-benchmark" "review-diff"
    "think-hard" "watchdog"
  ];

  # Claude skills deployed as directories (multiple files per skill)
  claudeSkillDirs = {
    hegel = ./files/claude-skills/hegel;
    postgresq = ./files/claude-skills/postgresq;
  };

  # Recursively collect all files from a directory tree
  collectFiles = prefix: dir:
    let
      entries = builtins.readDir dir;
      names = builtins.attrNames entries;
    in
    builtins.concatMap (name:
      if entries.${name} == "directory"
      then collectFiles "${prefix}/${name}" (dir + "/${name}")
      else [{ path = "${prefix}/${name}"; source = dir + "/${name}"; }]
    ) names;

  claudeSkillDirFiles = builtins.listToAttrs (builtins.concatMap (name:
    let files = collectFiles ".claude/skills/${name}" claudeSkillDirs.${name};
    in
    map (f: { name = f.path; value = { inherit (f) source; }; }) files
  ) (builtins.attrNames claudeSkillDirs));

  kiroSkillDeepDirFiles = builtins.listToAttrs (builtins.concatMap (name:
    let files = collectFiles ".kiro/skills/${name}" kiroSkillDeepDirs.${name};
    in
    map (f: { name = f.path; value = { inherit (f) source; }; }) files
  ) (builtins.attrNames kiroSkillDeepDirs));

  kiroSkillFiles = builtins.listToAttrs (builtins.concatMap (name:
    let
      skillDir = ./files/kiro-skills/${name};
      hasRefs = builtins.pathExists (skillDir + "/references");
      refFiles = if hasRefs
        then builtins.attrNames (builtins.readDir (skillDir + "/references"))
        else [];
    in
    [{ name = ".kiro/skills/${name}/SKILL.md";
       value = { source = skillDir + "/SKILL.md"; }; }]
    ++ map (ref: {
      name = ".kiro/skills/${name}/references/${ref}";
      value = { source = skillDir + "/references/${ref}"; };
    }) refFiles
  ) kiroSkillNames);

  claudeSkillFiles = builtins.listToAttrs (map (name: {
    name = ".claude/skills/${name}.md";
    value = { source = ./files/claude-skills/${name}.md; };
  }) claudeSkillNames);

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
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mkMerge [
      (lib.mkIf cfg.targets.kiro kiroSkillFiles)
      (lib.mkIf cfg.targets.kiro kiroSkillDeepDirFiles)
      (lib.mkIf cfg.targets.claude claudeSkillFiles)
      (lib.mkIf cfg.targets.claude claudeSkillDirFiles)
      (lib.mkIf cfg.skillsGit.enable skillsGitFiles)
    ];
  };
}
