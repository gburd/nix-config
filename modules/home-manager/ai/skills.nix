{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.programs.ai.skills;
  inherit (lib) mkEnableOption mkOption types;

  ###
  # Skill source trees that SkillSpector scans at switch time (Part 4) and
  # that ponytail/asm draw from. Each is a pinned flake input.
  ###
  ponytailSrc = inputs.ponytail or null;
  skillspectorSrc = inputs.skillspector or null;

  ###
  # In-tree operator skills
  #
  # These are the skills curated and edited locally (drifted from any
  # upstream copy — for example the postgresq SKILL.md is now on the
  # pg.ddx.io URL while skills.git still uses postgr.esq).
  ###
  kiroSkillNames = [
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
      # Run a security audit before installing any skill (defence in depth
      # alongside the SkillSpector switch-time gate).
      auditOnInstall = true;
    };
  };

  asmFiles = lib.optionalAttrs cfg.asm.enable {
    ".config/agent-skill-manager/config.json".text = builtins.toJSON asmConfig;
  };

  ###
  # SkillSpector gate (Part 4) — run NVIDIA SkillSpector in static (--no-llm)
  # mode against every skill source tree we're about to deploy, and FAIL the
  # `home-manager switch` (exit 1) if any scores HIGH/CRITICAL (risk > 50,
  # which is skillspector's own non-zero exit). Static mode is offline and
  # needs no API key, so it's safe to run on every switch.
  #
  # We scan the SOURCE trees in the nix store (the operator skills, the
  # skills.git branches, and ponytail) BEFORE home.file links them into the
  # agent dirs — a failing scan aborts activation before anything is linked.
  ###
  # Directories to scan. We separate TRUSTED in-tree operator skills (which
  # you authored — the static scanner false-positives on their legitimate
  # sudo/AWS/benchmark shell, so they're warned-but-not-blocked) from
  # UNTRUSTED external sources (ponytail + skills.git branches) which are the
  # actual supply-chain risk and DO block the switch on a finding.
  skillSpectorTrusted = [
    ./files/kiro-skills
    ./files/claude-skills
  ];
  skillSpectorUntrusted = lib.filter (p: p != null) (
    lib.optional (cfg.ponytail.enable && ponytailSrc != null) (ponytailSrc + "/skills")
    ++ map (spec: spec.input) (lib.attrValues enabledSkillsGitBranches)
  );

  # one scan loop, parameterised by whether findings block (untrusted) or
  # just warn (trusted in-tree). Paths are interpolated with ${} so Nix
  # preserves the store-path context (the writeShellScript then correctly
  # depends on the scanned source trees).
  scanLoop = block: roots: ''
    for tgt in ${lib.concatMapStringsSep " " (p: ''"${p}"'') roots}; do
      [ -e "$tgt" ] || continue
      for skill in "$tgt"/*; do
        [ -d "$skill" ] || continue
        if ! find "$skill" -name SKILL.md -print -quit | grep -q .; then continue; fi
        scanned=$((scanned+1))
        out=$(${pkgs.uv}/bin/uvx --python 3.13 --from "$SPEC_SRC" \
                skillspector scan "$skill" --no-llm --format json 2>/dev/null)
        rc=$?
        score=$(printf '%s' "$out" | ${pkgs.jq}/bin/jq -r '.risk_assessment.score // "?"' 2>/dev/null || echo '?')
        sev=$(printf '%s' "$out" | ${pkgs.jq}/bin/jq -r '.risk_assessment.severity // "?"' 2>/dev/null || echo '?')
        if [ "$rc" -ne 0 ]; then
          ${if block then ''
            echo "  skillspector: BLOCKED $skill — risk $score ($sev), rc=$rc" >&2
            fail=1
          '' else ''
            echo "  skillspector: WARN (trusted in-tree) $skill — risk $score ($sev), rc=$rc" >&2
          ''}
        fi
      done
    done
  '';

  skillSpectorScript = pkgs.writeShellScript "skillspector-gate" ''
    set -uo pipefail
    SPEC_SRC="${skillspectorSrc}"
    fail=0
    scanned=0
    # Pin Python 3.13: skillspector's yara-python dep has no cp314 wheel, so
    # letting uv pick 3.14 is a spurious build failure. Static (--no-llm)
    # mode is offline + needs no API key. EXIT CODE is the verdict:
    # 0 = pass, 1 = risk>50 (HIGH/CRITICAL), 2 = error.
    # --- trusted in-tree operator skills: warn only ---
    ${scanLoop false skillSpectorTrusted}
    # --- untrusted external skills (ponytail, skills.git): block ---
    ${scanLoop true skillSpectorUntrusted}
    if [ "$fail" -ne 0 ]; then
      echo "❌ SkillSpector flagged an EXTERNAL skill about to be installed; aborting switch." >&2
      exit 1
    fi
    echo "✓ SkillSpector: $scanned skill(s) scanned, no external skill flagged."
  '';
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

    # Part 4: SkillSpector switch-time security gate.
    skillSpector = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run NVIDIA SkillSpector (static, --no-llm) against every skill
          source tree about to be deployed on each home-manager switch, and
          FAIL the switch if SkillSpector flags any skill (its own exit code
          1 = risk score > 50 = HIGH/CRITICAL). Offline, no API key required.
          Python is pinned to 3.13 (the yara-python dep has no cp314 wheel).
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
      asmFiles
    ];

    # Part 4: gate the switch on SkillSpector. entryBefore writeBoundary so
    # the scan runs BEFORE any skill files are linked into the agent dirs;
    # a non-zero exit aborts activation, leaving the previous generation.
    home.activation.skillSpectorGate =
      lib.mkIf (cfg.skillSpector.enable && skillspectorSrc != null)
        (lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          echo "Running SkillSpector security gate on skills…"
          ${skillSpectorScript}
        '');
  };
}
