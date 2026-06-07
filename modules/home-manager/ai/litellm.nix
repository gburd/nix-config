{ config, lib, pkgs, ... }:
let
  cfg = config.programs.ai.litellm;
  inherit (lib) mkEnableOption mkOption types;

  # ---------- pin --------------------------------------------------------
  # Match the SHA that gburd/postgres' .github/workflows/ocr-review.yml uses.
  # That commit lands the Anthropic 'output_config.effort' adaptive-thinking
  # mapping (incl. 'xhigh') for Claude Opus 4.8 and is not yet in any tagged
  # release on PyPI. Bump deliberately: verify with the OCR config first,
  # then this pin.
  litellmPin = "5be0797d24a2f26eb2123e13788f90055a59d91d";
  litellmSpec = "litellm[proxy] @ git+https://github.com/BerriAI/litellm.git@${litellmPin}";

  # ---------- model list -------------------------------------------------
  # Curated list of Bedrock cross-region inference profiles useful for our
  # agents. All Anthropic models go through the Converse API (most reliable
  # tool-use path) with `output_config.effort: xhigh` so adaptive-thinking
  # models (Opus 4.x) think at the model's ceiling by default; LiteLLM
  # silently clamps to whatever the model actually supports.
  defaultModels = [
    # Anthropic Claude — adaptive-thinking via Converse
    { name = "claude-opus-4-8";   bedrock = "us.anthropic.claude-opus-4-8";              converse = true; effort = "xhigh"; }
    { name = "claude-opus-4-7";   bedrock = "us.anthropic.claude-opus-4-7";              converse = true; effort = "xhigh"; }
    { name = "claude-opus-4-6";   bedrock = "us.anthropic.claude-opus-4-6-v1";           converse = true; effort = "xhigh"; }
    { name = "claude-opus-4-5";   bedrock = "us.anthropic.claude-opus-4-5-20251101-v1:0";converse = true; effort = "xhigh"; }
    { name = "claude-opus-4-1";   bedrock = "us.anthropic.claude-opus-4-1-20250805-v1:0";converse = true; effort = "xhigh"; }
    { name = "claude-sonnet-4-6"; bedrock = "us.anthropic.claude-sonnet-4-6";            converse = true; effort = "xhigh"; }
    { name = "claude-sonnet-4-5"; bedrock = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"; converse = true; effort = "xhigh"; }
    { name = "claude-sonnet-4";   bedrock = "us.anthropic.claude-sonnet-4-20250514-v1:0"; converse = true; effort = "xhigh"; }
    { name = "claude-haiku-4-5";  bedrock = "us.anthropic.claude-haiku-4-5-20251001-v1:0"; converse = true; effort = "xhigh"; }
    { name = "claude-haiku-3-5";  bedrock = "us.anthropic.claude-3-5-haiku-20241022-v1:0"; converse = true; effort = "xhigh"; }

    # DeepSeek
    { name = "deepseek-r1";       bedrock = "us.deepseek.r1-v1:0";                       converse = false; }

    # Meta Llama 3.x and 4.x
    { name = "llama3-3-70b";      bedrock = "us.meta.llama3-3-70b-instruct-v1:0";        converse = false; }
    { name = "llama4-maverick";   bedrock = "us.meta.llama4-maverick-17b-instruct-v1:0"; converse = false; }
    { name = "llama4-scout";      bedrock = "us.meta.llama4-scout-17b-instruct-v1:0";    converse = false; }

    # Amazon Nova
    { name = "nova-premier";      bedrock = "us.amazon.nova-premier-v1:0";               converse = false; }
    { name = "nova-pro";          bedrock = "us.amazon.nova-pro-v1:0";                   converse = false; }
    { name = "nova-lite";         bedrock = "us.amazon.nova-lite-v1:0";                  converse = false; }
    { name = "nova-micro";        bedrock = "us.amazon.nova-micro-v1:0";                 converse = false; }

    # Mistral
    { name = "mistral-pixtral-large"; bedrock = "us.mistral.pixtral-large-2502-v1:0";    converse = false; }
  ];

  # The actual config for LiteLLM's proxy. Built as an attrset and emitted
  # as JSON, which is valid YAML — bypasses the indent hazards of
  # multi-line indented-string Nix interpolation entirely.
  configJson = builtins.toJSON {
    model_list = map
      (m: {
        model_name = m.name;
        litellm_params = {
          model = (if m.converse then "bedrock/converse/" else "bedrock/") + m.bedrock;
          aws_region_name = "os.environ/AWS_REGION";
          max_tokens = 32000;
        } // (lib.optionalAttrs (m ? effort) {
          output_config = { inherit (m) effort; };
        });
      })
      cfg.models;

    litellm_settings = {
      drop_params = true;
      modify_params = true;
      request_timeout = 600;
    };

    general_settings = {
      # Master key is read at runtime from a per-host file via the
      # systemd ExecStart wrapper, not committed to the Nix store or sops.
      master_key = "os.environ/LITELLM_MASTER_KEY";
    };
  };

  # Wrapper script that reads the bearer token + master key at *runtime*
  # (not build time) and execs litellm. Lets us avoid baking secrets into
  # the systemd unit file. Also configures LD_LIBRARY_PATH so the pipx-
  # installed tokenizers C++ extension can find libstdc++ on NixOS — the
  # same nix-ld trick used by overlays/default.nix's bitnet wrapper.
  startWrapper = pkgs.writeShellScript "litellm-start" ''
    set -eu
    PIPX_BIN="$HOME/.local/bin/litellm"
    BEARER_FILE=${cfg.bearerTokenFile}
    MASTER_FILE=${cfg.masterKeyFile}
    CONFIG=${config.home.homeDirectory}/.config/litellm/config.yaml

    if [ ! -x "$PIPX_BIN" ]; then
      echo "litellm not installed at $PIPX_BIN; activation should have done this" >&2
      exit 78  # EX_CONFIG
    fi
    if [ ! -r "$BEARER_FILE" ]; then
      echo "AWS bearer token file $BEARER_FILE not readable" >&2
      exit 78
    fi
    if [ ! -r "$MASTER_FILE" ]; then
      echo "LiteLLM master key file $MASTER_FILE not readable" >&2
      exit 78
    fi

    # pipx-installed extensions (tokenizers, numpy, ...) need libstdc++.
    # Bake the Nix-store path at eval time so this works uniformly:
    #   - on NixOS the system has libstdc++ at /run/current-system/... too,
    #     but using the eval-time path avoids depending on it,
    #   - on non-NixOS (arnold, Fedora + Determinate Nix) the Nix-built
    #     pipx Python doesn't search /usr/lib64, so we MUST point at the
    #     Nix-store libstdc++ explicitly (the `if [ -d nix-ld ]` guard
    #     would otherwise leave LD_LIBRARY_PATH unset and tokenizers
    #     fails to import).
    export LD_LIBRARY_PATH="${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.zlib ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export AWS_BEARER_TOKEN_BEDROCK="$(${pkgs.coreutils}/bin/cat "$BEARER_FILE")"
    export AWS_REGION="${cfg.region}"
    export LITELLM_MASTER_KEY="$(${pkgs.coreutils}/bin/cat "$MASTER_FILE")"

    # No DB — keep it stateless on disk. Virtual keys are minted by the
    # mint-keys helper after the proxy is up and stored in
    # ~/.config/litellm/keys/<agent>.key (mode 600).
    exec "$PIPX_BIN" --config "$CONFIG" --host 127.0.0.1 --port ${toString cfg.port}
  '';

  # ExecStartPost: ensures every agent has a key at
  # ~/.config/litellm/keys/<agent>.key (mode 600). v1: copies the master
  # key (LiteLLM's /key/generate needs a DB backend, not yet wired up;
  # for a single-user loopback proxy with 6 agents the master-as-shared
  # key is functionally equivalent in security to per-agent virtual keys
  # since all agents are local processes belonging to the same user).
  # When we want per-agent budgets/rate-limits we'll add a sqlite/postgres
  # backend and switch this to /key/generate calls; the agent wrappers
  # already read from these stable per-agent paths so the migration is
  # a no-op on the consumer side.
  mintKeysScript = pkgs.writeShellScript "litellm-mint-keys" ''
    set -eu
    KEYS_DIR=${config.home.homeDirectory}/.config/litellm/keys
    MASTER_FILE=${cfg.masterKeyFile}
    CURL=${pkgs.curl}/bin/curl

    ${pkgs.coreutils}/bin/mkdir -p "$KEYS_DIR"
    ${pkgs.coreutils}/bin/chmod 700 "$KEYS_DIR"

    # Wait up to 60s for the proxy to become ready (idempotent on restart).
    for i in $(${pkgs.coreutils}/bin/seq 1 60); do
      if "$CURL" -sf "http://127.0.0.1:${toString cfg.port}/health/readiness" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    MASTER="$(${pkgs.coreutils}/bin/cat "$MASTER_FILE")"
    for agent in ${lib.concatStringsSep " " cfg.agents}; do
      KEY_FILE="$KEYS_DIR/$agent.key"
      if [ -s "$KEY_FILE" ]; then
        # Already provisioned. Don't churn timestamps; idempotent re-runs.
        continue
      fi
      printf '%s' "$MASTER" > "$KEY_FILE"
      ${pkgs.coreutils}/bin/chmod 600 "$KEY_FILE"
      echo "litellm-mint-keys: provisioned $KEY_FILE"
    done
  '';

  pipxBin = "${pkgs.pipx}/bin/pipx";
in
{
  options.programs.ai.litellm = {
    enable = mkEnableOption "Local LiteLLM Bedrock proxy (per-host)";

    port = mkOption {
      type = types.port;
      default = 4000;
      description = "Loopback port the proxy listens on.";
    };

    region = mkOption {
      type = types.str;
      default = "us-east-1";
      description = "AWS region used by boto3 for Bedrock requests.";
    };

    bearerTokenFile = mkOption {
      type = types.path;
      default = "${config.home.homeDirectory}/.config/claude-code/.bearer_token";
      description = ''
        Path to the AWS Bedrock bearer token (sops-deployed). Read at
        service start; never written into the systemd unit file or the
        Nix store.
      '';
    };

    masterKeyFile = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/litellm/master.key";
      description = ''
        Path to the per-host LiteLLM admin master key. Generated on first
        activation if missing (32-byte random hex, mode 600); never
        leaves the host. Used only for /key/generate (minting per-agent
        virtual keys); agents never see this value.
      '';
    };

    models = mkOption {
      type = types.listOf (types.attrsOf types.anything);
      default = defaultModels;
      description = ''
        Curated list of {name, bedrock, converse?, effort?} entries that
        become LiteLLM model_list rows. By default we expose the full
        useful set of Bedrock cross-region inference profiles.
      '';
    };

    agents = mkOption {
      type = types.listOf types.str;
      default = [ "claude" "pi" "maki" "hermes" "codex" "terax" ];
      description = ''
        Agent identifiers. One virtual key per identifier is minted by
        the mint-keys helper and stored at
        ~/.config/litellm/keys/<agent>.key (mode 600).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.pipx ];

    # Activation: ensure config dir exists, master key exists, config.yaml
    # is up-to-date, litellm pipx install matches our pin.
    home.activation.setupLitellm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      DIR=${config.home.homeDirectory}/.config/litellm
      ${pkgs.coreutils}/bin/mkdir -p "$DIR" "$DIR/keys"
      ${pkgs.coreutils}/bin/chmod 700 "$DIR" "$DIR/keys"

      # Master key (per-host, never in sops, never in nix store).
      if [ ! -s "${cfg.masterKeyFile}" ]; then
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname ${cfg.masterKeyFile})"
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "${cfg.masterKeyFile}"
        ${pkgs.coreutils}/bin/chmod 600 "${cfg.masterKeyFile}"
        echo "litellm: generated new master key at ${cfg.masterKeyFile}"
      fi

      # config.yaml — generated, overwritten on every switch. JSON is
      # valid YAML, so we emit JSON to bypass any indent hazards.
      ${pkgs.coreutils}/bin/cat > "$DIR/config.yaml" <<'LITELLM_CONFIG'
${configJson}
LITELLM_CONFIG
      ${pkgs.coreutils}/bin/chmod 600 "$DIR/config.yaml"

      # Install / upgrade litellm[proxy] via pipx, pinned to our commit.
      export PATH="${pkgs.pipx}/bin:${pkgs.coreutils}/bin:$HOME/.nix-profile/bin:$PATH"
      export PIPX_HOME="$HOME/.local/share/pipx"
      export PIPX_BIN_DIR="$HOME/.local/bin"
      ${pkgs.coreutils}/bin/mkdir -p "$PIPX_BIN_DIR" "$PIPX_HOME"

      INSTALLED_REF="$(${pipxBin} list --short 2>/dev/null | ${pkgs.gnugrep}/bin/grep '^litellm ' || true)"
      EXPECTED_REF="${litellmPin}"
      # We can't easily query the installed git ref; pipx upgrade is idempotent
      # and respects --pip-args. Force-reinstall when nothing's installed yet.
      if [ -z "$INSTALLED_REF" ]; then
        echo "litellm: installing pinned $EXPECTED_REF via pipx..."
        ${pipxBin} install --quiet "${litellmSpec}" || \
          echo "litellm: install failed — run 'pipx install \"${litellmSpec}\"' manually" >&2
      fi
    '';

    systemd.user.services.litellm = {
      Unit = {
        Description = "LiteLLM proxy (Bedrock bridge, loopback only)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${startWrapper}";
        # After the proxy is up, mint per-agent virtual keys (idempotent).
        ExecStartPost = "-${mintKeysScript}";
        Restart = "on-failure";
        RestartSec = 5;
        # Keep stderr/stdout in the journal under the user manager.
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install = {
        # Start with the user's session (default.target). Doesn't need a
        # graphical session; runs equally well headless (e.g. on meh).
        WantedBy = [ "default.target" ];
      };
    };

    # Expose convenience values for other modules that will consume the
    # proxy in v2 (claude/pi/maki/hermes/codex/terax wrappers).
    home.sessionVariables = {
      LITELLM_URL = "http://127.0.0.1:${toString cfg.port}/v1";
    };
  };
}
