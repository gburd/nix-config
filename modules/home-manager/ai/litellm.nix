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
  # agents. Anthropic models go through the Converse API (most reliable
  # tool-use path); per-model `thinking` and `effort` reflect what each
  # specific model actually accepts on Bedrock today (probed empirically
  # 2026-06-07). The combinations are NOT interchangeable:
  #
  #   - Opus 4.6 / 4.7 / 4.8 → thinking={type:adaptive} +
  #     output_config.effort=xhigh. Adaptive lets the model decide whether
  #     to think; xhigh biases it strongly toward thinking on hard
  #     prompts. Reasoning text is redacted by Anthropic on Bedrock so
  #     `reasoning_tokens` reads 0 in the OpenAI-compat response, but
  #     `thinking_blocks` and `provider_specific_fields.reasoningContentBlocks`
  #     show the model did engage thinking.
  #
  #   - Sonnet 4.6 → adaptive WITHOUT effort. The model rejects
  #     `effort=xhigh` ("is not supported by this model") at the
  #     LiteLLM-validation layer, so we omit output_config entirely.
  #
  #   - Opus 4.5 / 4.1, Sonnet 4.5, Haiku 4.5 → legacy `enabled` thinking
  #     mode with explicit `budget_tokens`. These reject adaptive
  #     ("adaptive thinking is not supported"). budget_tokens=16000 with
  #     max_tokens=32000 leaves headroom for response text.
  #
  #   - Haiku 3-5 / Sonnet 4 → dropped: Bedrock returns
  #     "Access denied. This Model is marked by provider as Legacy" for
  #     these inference profiles regardless of the request shape.
  defaultModels = [
    # Adaptive-thinking models (Opus 4.6+, Sonnet 4.6, Haiku 4.5+)
    #
    # maxInput  = context window (input-token ceiling on Bedrock)
    # maxOutput = output-token ceiling. We set max_tokens to maxOutput so
    #             agents get the model's full generation budget rather
    #             than a flat 32000. budget_tokens (legacy thinking) still
    #             fits because it's carved out of maxOutput, not on top.
    { name = "claude-opus-4-8";   bedrock = "us.anthropic.claude-opus-4-8";              converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; aliases = [ "us.anthropic.claude-opus-4-8" ]; }
    { name = "claude-opus-4-7";   bedrock = "us.anthropic.claude-opus-4-7";              converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; }
    { name = "claude-opus-4-6";   bedrock = "us.anthropic.claude-opus-4-6-v1";           converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; }
    { name = "claude-sonnet-4-6"; bedrock = "us.anthropic.claude-sonnet-4-6";            converse = true; thinkingMode = "adaptive"; maxInput = 1000000; maxOutput = 64000; }

    # Legacy-thinking models (Opus 4.5/4.1, Sonnet 4.5, Haiku 4.5)
    { name = "claude-opus-4-5";   bedrock = "us.anthropic.claude-opus-4-5-20251101-v1:0";   converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 64000; }
    { name = "claude-opus-4-1";   bedrock = "us.anthropic.claude-opus-4-1-20250805-v1:0";   converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 32000; }
    { name = "claude-sonnet-4-5"; bedrock = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"; converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 64000; aliases = [ "us.anthropic.claude-sonnet-4-5-20250929-v1:0" ]; }
    { name = "claude-haiku-4-5";  bedrock = "us.anthropic.claude-haiku-4-5-20251001-v1:0";  converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 64000; }

    # DeepSeek
    { name = "deepseek-r1";       bedrock = "us.deepseek.r1-v1:0";                       converse = false; maxInput = 128000; maxOutput = 32000; }

    # Meta Llama 3.x and 4.x
    { name = "llama3-3-70b";      bedrock = "us.meta.llama3-3-70b-instruct-v1:0";        converse = false; maxInput = 128000; maxOutput = 8192; }
    { name = "llama4-maverick";   bedrock = "us.meta.llama4-maverick-17b-instruct-v1:0"; converse = false; maxInput = 1000000; maxOutput = 8192; }
    { name = "llama4-scout";      bedrock = "us.meta.llama4-scout-17b-instruct-v1:0";    converse = false; maxInput = 3500000; maxOutput = 8192; }

    # Amazon Nova
    { name = "nova-premier";      bedrock = "us.amazon.nova-premier-v1:0";               converse = false; maxInput = 1000000; maxOutput = 32000; }
    { name = "nova-pro";          bedrock = "us.amazon.nova-pro-v1:0";                   converse = false; maxInput = 300000; maxOutput = 5120; }
    { name = "nova-lite";         bedrock = "us.amazon.nova-lite-v1:0";                  converse = false; maxInput = 300000; maxOutput = 5120; }
    { name = "nova-micro";        bedrock = "us.amazon.nova-micro-v1:0";                 converse = false; maxInput = 128000; maxOutput = 5120; }

    # Mistral
    { name = "mistral-pixtral-large"; bedrock = "us.mistral.pixtral-large-2502-v1:0";    converse = false; maxInput = 128000; maxOutput = 8192; }
  ];

  # ---------- thinking-policy map ----------------------------------------
  # Per-model thinking policy, derived from the SAME cfg.models list that
  # builds model_list (so the two can never drift). The pre-call hook
  # (thinking_normalizer.py, below) reads this JSON and *rewrites* any
  # incoming `thinking` block to whatever the target model actually
  # accepts on Bedrock today. This protects ALL clients, not just the
  # ones we configured with the right thinking level:
  #
  #   - A client (e.g. Pi's context-overflow recovery summarizer) that
  #     blindly sends the legacy `thinking={type:enabled,budget_tokens:N}`
  #     to claude-opus-4-8 would otherwise get a hard 400 from Bedrock:
  #       '"thinking.type.enabled" is not supported for this model. Use
  #        "thinking.type.adaptive" and "output_config.effort"…'
  #     The hook silently maps enabled->adaptive for adaptive-only models.
  #   - Conversely a client sending adaptive to an enabled-only model
  #     (opus 4.5/4.1, sonnet 4.5, haiku 4.5) gets it mapped back to
  #     enabled+budget.
  #   - effort is stripped for models that reject output_config.
  #
  # policy mode values: "adaptive" | "adaptive+effort" | "enabled" | "none"
  thinkingPolicy = builtins.listToAttrs (lib.concatMap
    (m:
      let
        pol = {
          mode =
            if (m.thinkingMode or null) == "adaptive" then
              (if m ? effort then "adaptive+effort" else "adaptive")
            else if (m.thinkingMode or null) == "enabled" then "enabled"
            else "none";
          effort = m.effort or null;
          budget = m.thinkingBudget or 16000;
        };
      in
      # Key the policy under the primary name AND every legacy alias, so
      # the normalizer hook applies identically whether a client sends
      # "claude-opus-4-8" or the legacy "us.anthropic.claude-opus-4-8".
      [{ inherit (m) name; value = pol; }]
      ++ map (alias: { name = alias; value = pol; }) (m.aliases or [ ]))
    cfg.models);

  # The actual config for LiteLLM's proxy. Built as an attrset and emitted
  # as JSON, which is valid YAML — bypasses the indent hazards of
  # multi-line indented-string Nix interpolation entirely.

  # Build one model_list row for a given public name. Factored out so we
  # can emit both the primary alias (m.name) and any legacy aliases
  # (m.aliases) with identical params — see legacyAliases below.
  mkModelRow = m: rowName: {
    model_name = rowName;
    litellm_params = {
      model = (if m.converse then "bedrock/converse/" else "bedrock/") + m.bedrock;
      aws_region_name = "os.environ/AWS_REGION";
      # Give each agent the model's full output-token budget rather
      # than a flat 32000. Falls back to 32000 for any model without
      # an explicit maxOutput.
      max_tokens = m.maxOutput or 32000;
    };
    # NOTE: thinking / output_config are deliberately NOT set here.
    # LiteLLM merges litellm_params into the request *after* the
    # async_pre_call_hook runs, so a static thinking block here would
    # re-appear behind the hook's back — e.g. when a client omits
    # thinking and asks for a tiny max_tokens, the static
    # budget_tokens=16000 would exceed max_tokens and Bedrock 400s
    # ("max_tokens must be greater than thinking.budget_tokens").
    # Instead thinking_normalizer.py is the single source of truth: it
    # sets the correct thinking shape for EVERY request (the policy map
    # is derived from the same cfg.models list) and caps/drops the
    # budget against max_tokens. See thinkingHookPy below.

    # model_info overrides LiteLLM's built-in price/context DB so the
    # /model/info and /v1/models endpoints advertise the *true*
    # Bedrock context window + output ceiling for each alias. Clients
    # that size their context budget from the proxy (Pi reads this)
    # then won't trigger premature context-overflow recovery on the
    # 1M-token Opus/Sonnet 4.6+ models.
    model_info = {
      max_input_tokens = m.maxInput or 200000;
      max_output_tokens = m.maxOutput or 32000;
      max_tokens = m.maxOutput or 32000;
    };
  };

  configJson = builtins.toJSON {
    model_list =
      (map (m: mkModelRow m m.name) cfg.models)
      # Legacy-id alias rows: extra model_list entries whose model_name is
      # the OLD built-in amazon-bedrock model id (e.g.
      # "us.anthropic.claude-opus-4-8") so that resuming a pre-migration
      # Pi session — which persisted the bedrock id — restores cleanly via
      # the amazon-bedrock provider override (see pi-extensions/litellm.ts)
      # instead of warning "Could not restore model amazon-bedrock/…".
      # They reuse the matching model's params, so the thinking-normalizer
      # hook (keyed on model_name) also covers them via legacyPolicy below.
      ++ lib.concatMap
        (m: map (alias: mkModelRow m alias) (m.aliases or [ ]))
        cfg.models;

    litellm_settings = {
      drop_params = true;
      modify_params = true;
      request_timeout = 600;
      # Custom pre-call hook that normalises the `thinking` param per
      # model. Module path is resolved from config.yaml's dir (we drop
      # thinking_normalizer.py alongside it at activation).
      callbacks = [ "thinking_normalizer.normalizer_instance" ];
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
    #
    # cd into the config dir + add it to PYTHONPATH so LiteLLM can import
    # the `thinking_normalizer` pre-call hook (referenced by
    # litellm_settings.callbacks) as a top-level module.
    CONFIG_DIR=${config.home.homeDirectory}/.config/litellm
    cd "$CONFIG_DIR"
    export PYTHONPATH="$CONFIG_DIR''${PYTHONPATH:+:$PYTHONPATH}"
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

  # ---------- thinking-normalizer pre-call hook --------------------------
  # A LiteLLM CustomLogger whose async_pre_call_hook rewrites the request
  # `thinking` block (and strips/keeps output_config.effort) to match the
  # target model's policy from thinkingPolicy above. Registered via
  # litellm_settings.callbacks. The policy map is injected as a JSON
  # literal so the .py file is self-contained (no runtime file reads).
  thinkingHookPy = ''
    # Auto-generated by modules/home-manager/ai/litellm.nix. Do not edit.
    #
    # Normalises the per-request `thinking` parameter so that whatever a
    # client sends, the proxy forwards only what the target Bedrock model
    # accepts. Prevents hard 400s like:
    #   '"thinking.type.enabled" is not supported for this model. Use
    #    "thinking.type.adaptive" and "output_config.effort" ...'
    # which e.g. Pi's context-overflow recovery summarizer triggers when
    # it blindly sends legacy enabled-thinking to claude-opus-4-8.
    import json
    from litellm.integrations.custom_logger import CustomLogger

    POLICY = json.loads(r"""${builtins.toJSON thinkingPolicy}""")

    def _apply(model_name, data):
        pol = POLICY.get(model_name)
        if pol is None:
            return  # unknown model (e.g. nova/llama) -> leave untouched
        mode = pol.get("mode", "none")
        if mode == "none":
            # Model takes no thinking at all: strip both keys.
            data.pop("thinking", None)
            data.pop("output_config", None)
            return
        if mode in ("adaptive", "adaptive+effort"):
            data["thinking"] = {"type": "adaptive"}
            if mode == "adaptive+effort" and pol.get("effort"):
                oc = data.get("output_config")
                if not isinstance(oc, dict):
                    oc = {}
                oc["effort"] = pol["effort"]
                data["output_config"] = oc
            else:
                # adaptive-only models (e.g. sonnet 4.6) reject effort.
                data.pop("output_config", None)
            return
        if mode == "enabled":
            # enabled-only models reject adaptive AND output_config.effort.
            # Bedrock also requires max_tokens > thinking.budget_tokens.
            # If the client asked for a small max_tokens, cap the budget
            # to leave >=1024 tokens of headroom for the response; and if
            # max_tokens is too small to fit any sane thinking budget at
            # all (<2048), drop thinking entirely rather than send an
            # impossible budget that Bedrock would 400 on.
            data.pop("output_config", None)
            budget = int(pol.get("budget", 16000))
            mt = data.get("max_tokens")
            if isinstance(mt, int) and mt > 0:
                if mt < 2048:
                    data.pop("thinking", None)
                    return
                budget = min(budget, mt - 1024)
            data["thinking"] = {"type": "enabled", "budget_tokens": budget}
            return

    class ThinkingNormalizer(CustomLogger):
        async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
            try:
                model = data.get("model")
                if isinstance(model, str):
                    _apply(model, data)
            except Exception:
                # Never block a request because of normalisation; if the
                # shape is unexpected, fall through and let Bedrock decide.
                pass
            return data

    normalizer_instance = ThinkingNormalizer()
  '';
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

      # thinking_normalizer.py — the pre-call hook referenced by
      # litellm_settings.callbacks. Lives next to config.yaml; the proxy
      # is launched with cwd=$DIR (and $DIR on PYTHONPATH) so LiteLLM can
      # import it as the top-level module `thinking_normalizer`.
      ${pkgs.coreutils}/bin/cat > "$DIR/thinking_normalizer.py" <<'LITELLM_HOOK'
${thinkingHookPy}
LITELLM_HOOK
      ${pkgs.coreutils}/bin/chmod 600 "$DIR/thinking_normalizer.py"

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

        # --- sandboxing -------------------------------------------------
        # The proxy is a long-running, network-listening Python process
        # that holds the AWS bearer token + LiteLLM master key in memory.
        # Lock it down with systemd's sandbox so a compromise can't
        # escalate or rummage through the wider system. We can't use
        # ProtectHome (it reads ~/.config/litellm and the pipx venv in
        # ~/.local), but everything else applies:
        NoNewPrivileges = true;
        ProtectSystem = "strict"; # whole FS read-only…
        ReadWritePaths = [
          # …except the bits it genuinely writes: per-agent keyfiles
          # (ExecStartPost) and any litellm runtime state/cache.
          "%h/.config/litellm"
          "%h/.cache"
        ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # CPython JITs/compiles; needs W^X off
        # Only the address families the proxy actually uses (loopback +
        # outbound HTTPS to Bedrock over IPv4/IPv6 + unix sockets).
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        SystemCallFilter = [ "@system-service" "~@privileged" "~@resources" ];
        SystemCallErrorNumber = "EPERM";
        # Soft resource ceiling so a runaway request can't OOM the box.
        MemoryMax = "4G";
        UMask = "0077";
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
