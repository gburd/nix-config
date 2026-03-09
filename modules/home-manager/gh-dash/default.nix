{ config, lib, pkgs, ... }:
let
  cfg = config.programs.gh-dash;

  presetFiles = {
    personal = import ./presets/personal.nix;
  };

  loadedPresets = map (name: presetFiles.${name}) cfg.presets;

  mergedSections = {
    prSections = lib.concatMap (p: p.prSections or [ ]) loadedPresets;
    issuesSections = lib.concatMap (p: p.issuesSections or [ ]) loadedPresets;
  };

  defaultConfig = {
    defaults = {
      view = "prs";
      prsLimit = 20;
      issuesLimit = 20;
      preview = {
        open = true;
        width = 70;
      };
    };
    pager = {
      diff = "delta";
    };
  };

  finalConfig = lib.recursiveUpdate (defaultConfig // mergedSections) cfg.extraConfig;
in
{
  options.programs.gh-dash = {
    enable = lib.mkEnableOption "gh-dash GitHub PR/issue dashboard";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gh-dash;
      description = "The gh-dash package to use";
    };

    presets = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (builtins.attrNames presetFiles));
      default = [ "personal" ];
      description = "List of gh-dash presets to compose. Sections are concatenated in order.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra gh-dash configuration merged on top of presets (keybindings, theme, repoPaths, etc.)";
    };

    generatedConfig = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = finalConfig;
      description = "The fully merged gh-dash configuration (read-only).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."gh-dash/config.yml" = lib.mkIf (cfg.presets != [ ]) {
      text = lib.generators.toYAML { } cfg.generatedConfig;
    };
  };
}
