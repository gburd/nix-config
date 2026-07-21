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
    # Gen-5 Anthropic. Sonnet 5 + Fable 5 are the newest usable Anthropic
    # models on Bedrock (adaptive thinking + effort, like Opus 4.6+;
    # cross-region INFERENCE_PROFILE us.anthropic.claude-{sonnet,fable}-5).
    # NOTE: Opus 5 does NOT exist on Bedrock (line tops out at opus-4-8).
    # Fable 5 previously 400'd ("data retention mode 'default' is not
    # available") until the account's data-retention/AI-opt-out posture was
    # set; verified working 2026-07-02.
    { name = "claude-sonnet-5"; bedrock = "us.anthropic.claude-sonnet-5"; converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; aliases = [ "us.anthropic.claude-sonnet-5" ]; }
    { name = "claude-fable-5"; bedrock = "us.anthropic.claude-fable-5"; converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; aliases = [ "us.anthropic.claude-fable-5" ]; }

    # Adaptive-thinking models (Opus 4.6+, Sonnet 4.6, Haiku 4.5+)
    #
    # maxInput  = context window (input-token ceiling on Bedrock)
    # maxOutput = output-token ceiling. We set max_tokens to maxOutput so
    #             agents get the model's full generation budget rather
    #             than a flat 32000. budget_tokens (legacy thinking) still
    #             fits because it's carved out of maxOutput, not on top.
    { name = "claude-opus-4-8"; bedrock = "us.anthropic.claude-opus-4-8"; converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; aliases = [ "us.anthropic.claude-opus-4-8" ]; }
    { name = "claude-opus-4-7"; bedrock = "us.anthropic.claude-opus-4-7"; converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; }
    { name = "claude-opus-4-6"; bedrock = "us.anthropic.claude-opus-4-6-v1"; converse = true; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; }
    { name = "claude-sonnet-4-6"; bedrock = "us.anthropic.claude-sonnet-4-6"; converse = true; thinkingMode = "adaptive"; maxInput = 1000000; maxOutput = 64000; }

    # Legacy-thinking models (Opus 4.5/4.1, Sonnet 4.5, Haiku 4.5)
    { name = "claude-opus-4-5"; bedrock = "us.anthropic.claude-opus-4-5-20251101-v1:0"; converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 64000; }
    { name = "claude-opus-4-1"; bedrock = "us.anthropic.claude-opus-4-1-20250805-v1:0"; converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 32000; }
    { name = "claude-sonnet-4-5"; bedrock = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"; converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 64000; aliases = [ "us.anthropic.claude-sonnet-4-5-20250929-v1:0" ]; }
    { name = "claude-haiku-4-5"; bedrock = "us.anthropic.claude-haiku-4-5-20251001-v1:0"; converse = true; thinkingMode = "enabled"; thinkingBudget = 16000; maxInput = 200000; maxOutput = 64000; aliases = [ "claude-haiku-4-5-20251001" "claude-haiku-4-5-20251001-v1" "us.anthropic.claude-haiku-4-5-20251001-v1:0" ]; }

    # DeepSeek
    { name = "deepseek-r1"; bedrock = "us.deepseek.r1-v1:0"; converse = false; maxInput = 128000; maxOutput = 32000; }
    # V3.2 / V3.1 are ON_DEMAND (no us. cross-region profile yet), so we
    # invoke the bare modelId region-pinned. V3.2 is in us-east-1 +
    # us-west-2; V3.1 (deepseek.v3-v1:0) is us-west-2 only.
    { name = "deepseek-v3-2"; bedrock = "deepseek.v3.2"; converse = false; maxInput = 128000; maxOutput = 32000; }
    { name = "deepseek-v3-1"; bedrock = "deepseek.v3-v1:0"; converse = false; region = "us-west-2"; maxInput = 128000; maxOutput = 32000; }

    # Meta Llama 3.x and 4.x
    { name = "llama3-3-70b"; bedrock = "us.meta.llama3-3-70b-instruct-v1:0"; converse = false; maxInput = 128000; maxOutput = 8192; }
    { name = "llama4-maverick"; bedrock = "us.meta.llama4-maverick-17b-instruct-v1:0"; converse = false; maxInput = 1000000; maxOutput = 8192; }
    { name = "llama4-scout"; bedrock = "us.meta.llama4-scout-17b-instruct-v1:0"; converse = false; maxInput = 3500000; maxOutput = 8192; }

    # Amazon Nova
    { name = "nova-premier"; bedrock = "us.amazon.nova-premier-v1:0"; converse = false; maxInput = 1000000; maxOutput = 32000; }
    { name = "nova-pro"; bedrock = "us.amazon.nova-pro-v1:0"; converse = false; maxInput = 300000; maxOutput = 5120; }
    { name = "nova-lite"; bedrock = "us.amazon.nova-lite-v1:0"; converse = false; maxInput = 300000; maxOutput = 5120; }
    { name = "nova-micro"; bedrock = "us.amazon.nova-micro-v1:0"; converse = false; maxInput = 128000; maxOutput = 5120; }

    # Mistral
    { name = "mistral-pixtral-large"; bedrock = "us.mistral.pixtral-large-2502-v1:0"; converse = false; maxInput = 128000; maxOutput = 8192; }
    # Devstral 2 is Mistral's agentic-coding model; Large 3 is the flagship.
    { name = "mistral-devstral-2"; bedrock = "mistral.devstral-2-123b"; converse = false; maxInput = 256000; maxOutput = 8192; }
    { name = "mistral-large-3"; bedrock = "mistral.mistral-large-3-675b-instruct"; converse = false; maxInput = 256000; maxOutput = 8192; }

    # Qwen3 (Alibaba). Coder variants are code-specialized. The 480B coder
    # and 235B flagship are us-west-2 ONLY on Bedrock, so region-pin them.
    { name = "qwen3-coder-480b"; bedrock = "qwen.qwen3-coder-480b-a35b-v1:0"; converse = false; region = "us-west-2"; maxInput = 256000; maxOutput = 32000; }
    { name = "qwen3-coder-30b"; bedrock = "qwen.qwen3-coder-30b-a3b-v1:0"; converse = false; maxInput = 256000; maxOutput = 32000; }
    { name = "qwen3-coder-next"; bedrock = "qwen.qwen3-coder-next"; converse = false; maxInput = 256000; maxOutput = 32000; }
    { name = "qwen3-235b"; bedrock = "qwen.qwen3-235b-a22b-2507-v1:0"; converse = false; region = "us-west-2"; maxInput = 256000; maxOutput = 32000; }
    { name = "qwen3-next-80b"; bedrock = "qwen.qwen3-next-80b-a3b"; converse = false; maxInput = 256000; maxOutput = 32000; }

    # OpenAI open-weight (gpt-oss). ON_DEMAND, multi-region.
    { name = "gpt-oss-120b"; bedrock = "openai.gpt-oss-120b-1:0"; converse = false; maxInput = 128000; maxOutput = 32000; }
    { name = "gpt-oss-20b"; bedrock = "openai.gpt-oss-20b-1:0"; converse = false; maxInput = 128000; maxOutput = 32000; }

    # Google Gemma 3 (open weights; largest is 27B).
    { name = "gemma-3-27b"; bedrock = "google.gemma-3-27b-it"; converse = false; maxInput = 128000; maxOutput = 8192; }

    # Moonshot Kimi (strong agentic/coding MoE).
    { name = "kimi-k2-5"; bedrock = "moonshotai.kimi-k2.5"; converse = false; maxInput = 256000; maxOutput = 32000; }
    { name = "kimi-k2-thinking"; bedrock = "moonshot.kimi-k2-thinking"; converse = false; maxInput = 256000; maxOutput = 32000; }

    # Zhipu GLM (flagship GLM-5; strong coding/agentic).
    { name = "glm-5"; bedrock = "zai.glm-5"; converse = false; maxInput = 128000; maxOutput = 32000; }
    { name = "glm-4-7"; bedrock = "zai.glm-4.7"; converse = false; maxInput = 128000; maxOutput = 32000; }

    # MiniMax M2.x (agentic/coding).
    { name = "minimax-m2-5"; bedrock = "minimax.minimax-m2.5"; converse = false; maxInput = 200000; maxOutput = 32000; }

    # NVIDIA Nemotron (largest reasoning model).
    { name = "nemotron-super-120b"; bedrock = "nvidia.nemotron-super-3-120b"; converse = false; maxInput = 128000; maxOutput = 32000; }

    # Writer Palmyra X5 (enterprise; has a us. inference profile).
    { name = "palmyra-x5"; bedrock = "us.writer.palmyra-x5-v1:0"; converse = false; maxInput = 1000000; maxOutput = 8192; }

    # Claude Max/Pro subscription, direct Anthropic API (NOT Bedrock). Set
    # programs.ai.litellm.anthropicAuthTokenFile to a sops-deployed file
    # holding the sk-ant-oat... token from `claude setup-token` to enable.
    # Distinct model_name (claude-max-*) so agents opt in explicitly — it
    # never shadows the Bedrock claude-opus-4-8 etc. rows. maxInput/maxOutput
    # match each model's own advertised limits (confirmed live via
    # api.anthropic.com/v1/models: 1000000/128000 for both sonnet-5 and
    # fable-5, same as their Bedrock rows above) -- NOT a claim that the
    # Max/Pro plan can actually reach fable-5/sonnet-5 today; that's
    # unconfirmed (every live probe hit an account-wide 429, including the
    # already-working opus-4-8 control, so it was inconclusive either way).
    # These rows just make the models CALLABLE through this account once/if
    # access is confirmed -- default routing is untouched, nothing selects
    # these unless explicitly asked for by name.
    { name = "claude-max-opus-4-8"; provider = "anthropic"; anthropicModel = "claude-opus-4-8"; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 200000; maxOutput = 32000; }
    { name = "claude-max-sonnet-5"; provider = "anthropic"; anthropicModel = "claude-sonnet-5"; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; }
    { name = "claude-max-fable-5"; provider = "anthropic"; anthropicModel = "claude-fable-5"; thinkingMode = "adaptive"; effort = "xhigh"; maxInput = 1000000; maxOutput = 128000; }
  ];

  # Anthropic-direct (Claude Max/Pro subscription) rows are only wired in
  # when a token file is actually configured — otherwise the proxy would
  # advertise a model whose api_key env var is never set, and every call
  # to it would 401. Filtered once here; every consumer below reads
  # usableModels instead of cfg.models.
  usableModels = lib.filter
    (m: (m.provider or "bedrock") != "anthropic" || cfg.anthropicAuthTokenFile != null)
    cfg.models;

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
    usableModels);

  # The actual config for LiteLLM's proxy. Built as an attrset and emitted
  # as JSON, which is valid YAML — bypasses the indent hazards of
  # multi-line indented-string Nix interpolation entirely.

  # Build one model_list row for a given public name. Factored out so we
  # can emit both the primary alias (m.name) and any legacy aliases
  # (m.aliases) with identical params — see legacyAliases below.
  mkModelRow = m: rowName:
    let
      isAnthropicDirect = (m.provider or "bedrock") == "anthropic";
    in
    {
      model_name = rowName;
      litellm_params =
        if isAnthropicDirect then {
          # Direct Anthropic API via a Claude subscription (Max/Pro) OAuth
          # token, NOT Bedrock. `claude setup-token` mints a long-lived
          # sk-ant-oat... token; LiteLLM's anthropic provider auto-detects
          # that prefix and swaps in the OAuth Authorization header (see
          # optionally_handle_anthropic_oauth in litellm's anthropic
          # common_utils.py) instead of the normal x-api-key header. No AWS
          # region/creds involved — this bypasses Bedrock entirely.
          model = "anthropic/" + m.anthropicModel;
          api_key = "os.environ/ANTHROPIC_AUTH_TOKEN";
          max_tokens = m.maxOutput or 32000;
        } else {
          model = (if m.converse then "bedrock/converse/" else "bedrock/") + m.bedrock;
          # Per-model region override (some models are single-region on
          # Bedrock, e.g. Qwen3-Coder-480B is us-west-2 only). Falls back to
          # the proxy-wide AWS_REGION for the (majority) multi-region models.
          aws_region_name = m.region or "os.environ/AWS_REGION";
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
      (map (m: mkModelRow m m.name) usableModels)
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
        usableModels;

    litellm_settings = {
      drop_params = true;
      modify_params = true;
      request_timeout = 600;
      # Resilience against transient Bedrock 503s ("Bedrock is unable to
      # process your request" / "system encountered an unexpected error").
      # Retry the SAME model a few times with exponential backoff — a 503 is
      # usually a momentary AWS capacity blip that clears within a second or
      # two. We deliberately do NOT configure cross-model `fallbacks`: a
      # sustained outage should fail LOUDLY with the 503 rather than
      # silently downgrading e.g. opus-4-8 -> a weaker model behind the
      # user's back. (There's also no same-quality fallback to add: the
      # `us.` inference profiles already load-balance across us-east/west,
      # so a 503 means AWS's whole us fleet for that model is unavailable.)
      num_retries = 3;
      # Custom pre-call hook that normalises the `thinking` param per
      # model. Module path is resolved from config.yaml's dir (we drop
      # thinking_normalizer.py alongside it at activation).
      callbacks = [ "thinking_normalizer.normalizer_instance" ];
      # litellm module attr (getattr(litellm, ...)): when a custom_auth
      # function returns a UserAPIKeyAuth, also run the post-auth checks
      # (expiry + key-level model allowlist). Paired with
      # general_settings.custom_auth_run_common_checks to enforce the
      # per-agent .models scoping our custom_auth stamps on.
      enable_post_custom_auth_checks = true;
    };

    general_settings = {
      # Master key is read at runtime from a per-host file via the
      # systemd ExecStart wrapper, not committed to the Nix store or sops.
      master_key = "os.environ/LITELLM_MASTER_KEY";
      # DB-free per-agent key validation + model scoping. custom_auth.py
      # (dropped next to config.yaml at activation) reads the live
      # per-agent keyfiles, validates the presented key, and returns a
      # UserAPIKeyAuth carrying that agent's allowed-model list so
      # LiteLLM's can_key_call_model enforces scoping natively — no
      # PostgreSQL/Prisma needed.
      custom_auth = "custom_auth.user_auth";
      # Run LiteLLM's post-auth checks (incl. key-level model allowlist)
      # on the object our custom_auth returns, so per-key .models scoping
      # is enforced via can_key_call_model. NOTE: the trigger flag
      # `enable_post_custom_auth_checks` is a litellm MODULE attribute
      # (read via getattr(litellm, ...)), so it lives in litellm_settings
      # below — NOT here. This general_settings flag turns on the
      # model-access check (_enforce_key_and_fallback_model_access)
      # inside that post-auth path.
      custom_auth_run_common_checks = true;
    };
  };

  # Wrapper script that reads the bearer token + master key at *runtime*
  # (not build time) and execs litellm. Lets us avoid baking secrets into
  # the systemd unit file. Also configures LD_LIBRARY_PATH so the pipx-
  # installed tokenizers C++ extension can find libstdc++ on NixOS via the
  # nix-ld library path.
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
    ${lib.optionalString (cfg.anthropicAuthTokenFile != null) ''
      # Claude Max/Pro subscription token (claude-max-* model rows). Direct
      # Anthropic API, entirely separate from the Bedrock bearer token above.
      if [ ! -r "${cfg.anthropicAuthTokenFile}" ]; then
        echo "Anthropic auth token file ${cfg.anthropicAuthTokenFile} not readable" >&2
        exit 78
      fi
      export ANTHROPIC_AUTH_TOKEN="$(${pkgs.coreutils}/bin/cat "${cfg.anthropicAuthTokenFile}")"
    ''}
    # Bearer token is the ONLY intended auth path. Clear any AWS_PROFILE /
    # static-credential env that leaks in from the login session (e.g.
    # arnold's systemd --user manager imports AWS_PROFILE=asbxbedrock from
    # a shell profile). botocore prefers AWS_PROFILE over the bearer token,
    # so a stale/undefined profile makes every Bedrock call 500 with
    # ProfileNotFound. Unsetting these guarantees the bearer token wins on
    # every host regardless of what the session environment carries.
    unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_DEFAULT_PROFILE
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

  # ExecStartPost: wait for the proxy to be ready, then self-test that
  # each agent's distinct key authenticates (and is correctly scoped).
  # Keys themselves are provisioned at *activation* (see
  # home.activation.setupLitellm) — DB-free, validated by custom_auth.py.
  # This just surfaces breakage in the journal; it never blocks startup.
  mintKeysScript = pkgs.writeShellScript "litellm-verify-keys" ''
    set -eu
    KEYS_DIR=${config.home.homeDirectory}/.config/litellm/keys
    CURL=${pkgs.curl}/bin/curl
    BASE="http://127.0.0.1:${toString cfg.port}"

    # Wait up to 60s for the proxy to become ready.
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      if "$CURL" -sf "$BASE/health/readiness" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    for agent in ${lib.concatStringsSep " " cfg.agents}; do
      KEY_FILE="$KEYS_DIR/$agent.key"
      if [ ! -s "$KEY_FILE" ]; then
        echo "litellm-verify-keys: WARN no key for $agent at $KEY_FILE" >&2
        continue
      fi
      KEY="$(${pkgs.coreutils}/bin/cat "$KEY_FILE")"
      # /v1/models is auth-gated; a 200 proves the key is accepted by
      # custom_auth. (Model-scoping is enforced per-request by LiteLLM.)
      if "$CURL" -sf "$BASE/v1/models" -H "Authorization: Bearer $KEY" >/dev/null 2>&1; then
        echo "litellm-verify-keys: $agent key OK"
      else
        echo "litellm-verify-keys: WARN $agent key REJECTED by proxy" >&2
      fi
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
        # Fields some clients send that Bedrock's Converse API rejects
        # with "Extra inputs are not permitted" (validation runs AFTER
        # LiteLLM's OpenAI->Anthropic translation, so drop_params can't
        # catch them). codex >= 0.135 sends client_metadata on every
        # /v1/responses request; strip these unconditionally so we can
        # track the latest codex without Bedrock 400s.
        _STRIP_FIELDS = ("client_metadata",)

        async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
            try:
                for f in self._STRIP_FIELDS:
                    data.pop(f, None)
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

  # ---------- DB-free per-agent auth + model scoping ---------------------
  # LiteLLM only natively authenticates the single master key when no DB
  # is configured. To get DISTINCT per-agent keys (each scoped to a set
  # of models) WITHOUT standing up PostgreSQL/Prisma, we register a
  # custom_auth function (general_settings.custom_auth). LiteLLM calls it
  # with (request, api_key); we look the key up in a map and return a
  # UserAPIKeyAuth carrying that agent's allowed `models`. LiteLLM's
  # can_key_call_model check then enforces scoping for us.
  #
  # The key *values* are NOT baked into the Nix store: the function reads
  # the live per-agent keyfiles (~/.config/litellm/keys/<agent>.key) at
  # import time. Only the agent->models policy (model NAMES, not secrets)
  # is embedded. The master key still authenticates as full admin.
  keysDir = "${config.home.homeDirectory}/.config/litellm/keys";
  # agent -> [models] (empty list / absent => all models allowed)
  authPolicyJson = builtins.toJSON (lib.listToAttrs (map
    (a: lib.nameValuePair a (cfg.perAgentModels.${a} or [ ]))
    cfg.agents));
  customAuthPy = ''
    # Auto-generated by modules/home-manager/ai/litellm.nix. Do not edit.
    # DB-free per-agent key auth + model scoping. Registered via
    # general_settings.custom_auth = "custom_auth.user_auth".
    import json, os
    from litellm.proxy._types import UserAPIKeyAuth

    KEYS_DIR = ${builtins.toJSON keysDir}
    AGENTS = json.loads(r"""${builtins.toJSON cfg.agents}""")
    POLICY = json.loads(r"""${authPolicyJson}""")
    MASTER = os.environ.get("LITELLM_MASTER_KEY", "")

    def _read(path):
        try:
            with open(path, "r") as fh:
                return fh.read().strip()
        except Exception:
            return None

    def _resolve(api_key):
        """Return (agent_name, [allowed_models]) for a presented key, or
        None if the key is unknown. Keyfiles are read fresh each call so
        re-provisioned keys take effect without a proxy restart."""
        if not api_key:
            return None
        # Master key => admin, all models.
        if MASTER and api_key == MASTER:
            return ("admin", [])
        for agent in AGENTS:
            kf = os.path.join(KEYS_DIR, agent + ".key")
            if _read(kf) == api_key:
                models = POLICY.get(agent) or []
                return (agent, models)
        return None

    async def user_auth(request, api_key):
        # LiteLLM may pass "Bearer sk-..."; normalise.
        if isinstance(api_key, str) and api_key.lower().startswith("bearer "):
            api_key = api_key[7:].strip()
        resolved = _resolve(api_key)
        if resolved is None:
            raise Exception("Invalid LiteLLM API key")
        agent, models = resolved
        kwargs = {
            "api_key": api_key,
            "key_alias": "agent-" + agent,
            "metadata": {"agent": agent, "managed_by": "nix-config litellm.nix"},
        }
        # Empty list => unrestricted (don't set .models so no scoping).
        if models:
            kwargs["models"] = models
        return UserAPIKeyAuth(**kwargs)
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

    anthropicAuthTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional path to a Claude subscription (Max/Pro) long-lived OAuth
        token (the sk-ant-oat... value from `claude setup-token`),
        sops-deployed like bearerTokenFile. When set, the proxy exposes
        model rows that call the direct Anthropic API through this
        subscription instead of Bedrock (see defaultModels' provider =
        "anthropic" rows). Read at service start; never written into the
        systemd unit file or the Nix store. Leave null to skip those
        model rows are then omitted entirely (the token is required, not
        optional, at the API layer).
      '';
    };

    masterKeyFile = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/litellm/master.key";
      description = ''
        Path to the per-host LiteLLM admin master key. Generated on first
        activation if missing (32-byte random hex, mode 600); never
        leaves the host. Authenticates as full admin (all models). Agents
        use their own distinct per-agent keys, not this value.
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
      default = [ "claude" "pi" "maki" "hermes" "codex" "terax" "zed" ];
      description = ''
        Agent identifiers. Each gets a DISTINCT API key at
        ~/.config/litellm/keys/<agent>.key (mode 600). Those keys are
        validated DB-free by a custom_auth hook (custom_auth.py) that
        also stamps each key's allowed-model list (perAgentModels) onto
        the request, so LiteLLM enforces per-agent model scoping
        natively — no PostgreSQL/Prisma required.
      '';
    };

    perAgentModels = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = { };
      description = ''
        Optional per-agent model allow-list. Maps an agent identifier to
        the model_name values its key may call. Agents absent here (or
        mapped to [ ]) may call ALL models. Enforced by the custom_auth
        hook + LiteLLM's can_key_call_model check.
      '';
    };

    sopsKeyFiles = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = lib.literalExpression ''
        {
          pi = config.sops.secrets."litellm/pi".path;
          claude = config.sops.secrets."litellm/claude".path;
        }
      '';
      description = ''
        Optional map of agent -> path of a sops-managed file containing
        that agent's API key. When an agent appears here, its keyfile is
        populated from the sops secret at activation instead of being
        generated locally. Agents NOT listed get a locally-generated
        random key (openssl rand). Either way the value never enters the
        Nix store: the custom_auth hook reads the live keyfiles at
        request time.
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

            # Per-agent keys. Each agent gets a DISTINCT key at
            # $DIR/keys/<agent>.key. Sops-backed agents (sopsKeyFiles) copy the
            # decrypted secret; everyone else gets a locally-generated random
            # token. Generated once and left stable across switches so we don't
            # churn agent configs. The custom_auth hook validates these at
            # request time and applies per-agent model scoping.
            ${lib.concatMapStringsSep "\n" (agent:
              let sops = cfg.sopsKeyFiles.${agent} or null; in
              if sops != null then ''
                # ${agent}: seed from sops secret (refresh on every switch so
                # rotating the sops value propagates).
                if [ -r "${sops}" ]; then
                  ${pkgs.coreutils}/bin/install -m600 /dev/null "$DIR/keys/${agent}.key"
                  ${pkgs.coreutils}/bin/cat "${sops}" | ${pkgs.coreutils}/bin/tr -d '\n' > "$DIR/keys/${agent}.key"
                elif [ ! -s "$DIR/keys/${agent}.key" ]; then
                  echo "litellm: WARN sops key for ${agent} (${sops}) not readable; generating local key" >&2
                  ${pkgs.openssl}/bin/openssl rand -hex 32 > "$DIR/keys/${agent}.key"
                  ${pkgs.coreutils}/bin/chmod 600 "$DIR/keys/${agent}.key"
                fi
              '' else ''
                # ${agent}: locally-generated random key (sk- prefixed so it
                # reads like an API key, and so we can detect+migrate the
                # legacy shared-master-key copies which had no prefix).
                # (Re)generate if missing, empty, or not yet in sk- form.
                if [ ! -s "$DIR/keys/${agent}.key" ] || \
                   ! ${pkgs.gnugrep}/bin/grep -q '^sk-' "$DIR/keys/${agent}.key"; then
                  ${pkgs.coreutils}/bin/printf 'sk-%s' "$(${pkgs.openssl}/bin/openssl rand -hex 24)" > "$DIR/keys/${agent}.key"
                  ${pkgs.coreutils}/bin/chmod 600 "$DIR/keys/${agent}.key"
                  echo "litellm: generated distinct key for ${agent}"
                fi
              '') cfg.agents}

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

            # custom_auth.py — DB-free per-agent key validation + model
            # scoping, referenced by general_settings.custom_auth. Reads the
            # live per-agent keyfiles at request time (values never enter the
            # Nix store). Imported as top-level module `custom_auth` (cwd=$DIR
            # + $DIR on PYTHONPATH, same as the thinking hook).
            ${pkgs.coreutils}/bin/cat > "$DIR/custom_auth.py" <<'LITELLM_AUTH'
      ${customAuthPy}
      LITELLM_AUTH
            ${pkgs.coreutils}/bin/chmod 600 "$DIR/custom_auth.py"

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

            # home-manager's own reloadSystemd activation step runs BEFORE
            # this one (entryAfter linkGeneration, vs our entryAfter
            # writeBoundary) — so if it restarts litellm.service, that
            # restart reads the OLD config.yaml, and our rewrite above lands
            # too late for the process that's already running. Explicitly
            # restart here, after config.yaml/keys/hooks are all on disk, so
            # the proxy that ends up running always matches what we just
            # wrote. No-op if the unit isn't loaded yet (first-ever switch;
            # reloadSystemd's own systemctl start handles that case).
            if ${pkgs.systemd}/bin/systemctl --user is-enabled --quiet litellm.service 2>/dev/null; then
              ${pkgs.systemd}/bin/systemctl --user restart litellm.service || true
            fi
    '';

    systemd.user.services.litellm = {
      Unit = {
        Description = "LiteLLM proxy (Bedrock bridge, loopback only)";
        # sops-nix.service decrypts the bearer token + anthropic OAuth token
        # symlink targets. Without this ordering, a home-manager switch that
        # restarts BOTH units can start litellm before sops-nix finishes
        # writing secrets, so the startup script's readability check fails
        # ("... not readable", exit 78/CONFIG) and the proxy is down until
        # systemd's Restart=on-failure retries a few seconds later — a real
        # outage window every switch, not just a hypothetical.
        After = [ "network-online.target" "sops-nix.service" ];
        Wants = [ "network-online.target" "sops-nix.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${startWrapper}";
        # After the proxy is up, self-test that each agent key authenticates.
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
