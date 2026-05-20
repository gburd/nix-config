{ config, lib, ... }:
let
  cfg = config.programs.ai.skills;
  inherit (lib) mkEnableOption mkOption types;

  kiroSkillNames = [
    "aws-ec2-lifecycle" "aws-isengard-auth" "aws-rds-aurora"
    "aws-s3-ops" "aws-serverless" "aws-terraform"
    "btw" "c-to-rust" "checkpoint" "coccinelle" "dream"
    "flex-bison-to-lime" "maintain-docs" "memelord-init"
    "pg-numa-benchmark" "postgresq" "review-diff" "think-hard"
    "rust-async" "rust-error-handling" "rust-idiomatic"
    "rust-ownership" "rust-testing" "rust-traits"
    "watchdog"
  ];

  claudeSkillNames = [
    "aws-ec2-lifecycle" "aws-isengard-auth" "aws-rds-aurora"
    "aws-s3-ops" "aws-serverless" "aws-terraform"
    "btw" "checkpoint" "coccinelle" "dream" "maintain-docs"
    "memelord-init" "pg-numa-benchmark" "review-diff"
    "think-hard" "watchdog"
  ];

  # Claude skills deployed as directories (multiple files per skill)
  claudeSkillDirs = {
    postgresq = ./files/claude-skills/postgresq;
  };

  claudeSkillDirFiles = builtins.listToAttrs (builtins.concatMap (name:
    let
      dir = claudeSkillDirs.${name};
      files = builtins.attrNames (builtins.readDir dir);
    in
    map (f: {
      name = ".claude/skills/${name}/${f}";
      value = { source = dir + "/${f}"; };
    }) files
  ) (builtins.attrNames claudeSkillDirs));

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
      (lib.mkIf cfg.targets.claude claudeSkillFiles)
      (lib.mkIf cfg.targets.claude claudeSkillDirFiles)
    ];
  };
}
