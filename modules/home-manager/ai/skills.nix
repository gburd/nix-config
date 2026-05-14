{ config, lib, ... }:
let
  cfg = config.programs.ai.skills;
  inherit (lib) mkEnableOption mkOption types;

  kiroSkillNames = [
    "aws-ec2-lifecycle" "aws-isengard-auth" "aws-rds-aurora"
    "aws-s3-ops" "aws-serverless" "aws-terraform"
    "c-to-rust" "rust-idiomatic" "rust-testing"
    "rust-error-handling" "rust-async" "rust-traits"
    "rust-ownership" "review-diff" "watchdog"
    "maintain-docs" "pg-numa-benchmark"
  ];

  claudeSkillNames = [
    "aws-ec2-lifecycle" "aws-isengard-auth" "aws-rds-aurora"
    "aws-s3-ops" "aws-serverless" "aws-terraform"
    "review-diff" "watchdog" "maintain-docs" "pg-numa-benchmark"
  ];

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
    ];
  };
}
