{ config, lib, ... }:
let
  cfg = config.programs.ai.skills;
  inherit (lib) mkEnableOption mkOption types;

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
in
{
  options.programs.ai.skills = {
    enable = mkEnableOption "Deploy AI agent skills (Rust, AWS, cross-monitoring)";

    targets = {
      kiro = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy skills to ~/.kiro/skills/";
      };
      claude = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy skills to ~/.claude/skills/";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mkMerge [
      (lib.mkIf cfg.targets.kiro kiroSkillFiles)
      (lib.mkIf cfg.targets.kiro kiroSkillDeepDirFiles)
      (lib.mkIf cfg.targets.claude claudeSkillFiles)
      (lib.mkIf cfg.targets.claude claudeSkillDirFiles)
    ];
  };
}
