{ config, lib, pkgs, inputs, platform, ... }:
# Kun Chen's agentic-engineering tools (from the "L8 Principal's Agentic
# Engineering Workflow" video). These are opt-in helpers layered on top of
# the CLI agents (claude/codex/pi/maki). Terminal + tmux + treehouse are
# configured elsewhere; this module adds the workflow tools.
#
# Packaging choices:
#   - gnhf / gh-axi / lavish-axi are npm CLIs that update frequently and are
#     used on-demand -> thin `npx -y <pkg>` wrapper shims (always latest, no
#     npmDepsHash churn). Needs nodejs on PATH (present via console).
#   - no-mistakes is a Go binary + background daemon -> real derivation
#     (buildGoModule from the pinned flake input).
#   - firstmate is a clone-and-run repo (no binary) -> a launcher that
#     clones/updates it under ~/.firstmate and drops you into an agent there.
let
  cfg = config.programs.ai.kunTools;
  inherit (lib) mkEnableOption mkOption mkIf types optionals;

  # npx-wrapper: run an npm CLI on demand, pinned to a version, cached by npm.
  npxTool = name: pkg: pkgs.writeShellScriptBin name ''
    exec ${pkgs.nodejs}/bin/npx -y ${pkg} "$@"
  '';

  gnhf = npxTool "gnhf" "gnhf@latest";
  gh-axi = npxTool "gh-axi" "gh-axi@latest";
  lavish = npxTool "lavish-axi" "lavish-axi@latest";

  # no-mistakes: Go binary from the flake input (buildGoModule). The daemon
  # is started on demand by the binary itself; we don't run it as a service.
  no-mistakes =
    let src = inputs.no-mistakes or null;
    in
    if src == null then null else
    pkgs.buildGoModule {
      pname = "no-mistakes";
      version = "1.31.2";
      inherit src;
      vendorHash = cfg.noMistakesVendorHash;
      subPackages = [ "cmd/no-mistakes" ];
      # git + gh are runtime deps; the binary shells out to them.
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postInstall = ''
        wrapProgram $out/bin/no-mistakes \
          --prefix PATH : ${lib.makeBinPath [ pkgs.git pkgs.gh ]}
      '';
      doCheck = false;
      meta.description = "git push no-mistakes — AI validation pipeline to clean PR";
    };

  # firstmate launcher: clone-or-update the repo under ~/.firstmate, then run
  # the chosen agent inside it (firstmate IS the repo you run an agent in).
  firstmate = pkgs.writeShellScriptBin "firstmate" ''
    set -euo pipefail
    FM_HOME="''${FIRSTMATE_HOME:-$HOME/.firstmate}"
    AGENT="''${FIRSTMATE_AGENT:-${cfg.firstmateAgent}}"
    if [ ! -d "$FM_HOME/.git" ]; then
      echo "firstmate: cloning into $FM_HOME ..." >&2
      ${pkgs.git}/bin/git clone --depth 1 https://github.com/kunchenguid/firstmate "$FM_HOME"
    else
      ${pkgs.git}/bin/git -C "$FM_HOME" pull --ff-only 2>/dev/null || true
    fi
    cd "$FM_HOME"
    echo "firstmate: launching '$AGENT' in $FM_HOME (deps: tmux, treehouse, no-mistakes)" >&2
    exec "$AGENT" "$@"
  '';
in
{
  options.programs.ai.kunTools = {
    enable = mkEnableOption "Kun Chen's agentic-engineering CLI tools";
    firstmateAgent = mkOption {
      type = types.str;
      default = "claude";
      description = "Agent CLI firstmate launches in its repo (claude/codex/pi/...).";
    };
    noMistakesVendorHash = mkOption {
      type = types.str;
      default = "sha256-NZOYxNYvt4192uqKBdKRxdgrKFvWx3585psdCnRdPSM=";
      description = "buildGoModule vendorHash for no-mistakes.";
    };
    enableNoMistakes = mkEnableOption "no-mistakes (Go binary + daemon)" // { default = true; };
    enableFirstmate = mkEnableOption "firstmate launcher" // { default = true; };
  };

  config = mkIf cfg.enable {
    home.packages =
      [ gnhf gh-axi lavish ]
      ++ optionals (cfg.enableNoMistakes && no-mistakes != null) [ no-mistakes ]
      ++ optionals cfg.enableFirstmate [ firstmate ];
  };
}
