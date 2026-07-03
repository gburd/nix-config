---
name: nix-agent-configs
description: >
  Hard-won lessons for working on the Nix-managed AI agent configs in
  modules/home-manager/ai/ (the Bedrock-backed agents pi, claude, maki, hermes,
  codex, plus kiro-cli, and the LiteLLM proxy). Use this skill ONLY when editing
  files under modules/home-manager/ai/ or debugging agent auth/telemetry/model
  routing. Covers: telemetry-off enforcement, thinking-effort ceilings, the two
  Bedrock auth paths (bearer vs SigV4), model-reachability verification, patching
  pipx/venv tools, and the CI expectations for this repo. Triggers on: editing
  modules/home-manager/ai, "LiteLLM proxy", "Bedrock auth", "agent telemetry",
  "thinking effort", "kiro-cli config".
---

# Lessons: Nix-managed AI Agent Configs

When working on `modules/home-manager/ai/` (Bedrock-backed agents: pi, claude,
maki, hermes, codex; plus kiro-cli):

- **Telemetry ships ON by default.** Disable it declaratively, don't assume:
  kiro-cli (`telemetry.enabled = false` in `~/.kiro/settings/cli.json`),
  Claude Code (`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=true` +
  `DISABLE_TELEMETRY/ERROR_REPORTING/BUG_COMMAND`), pi
  (`enableInstallTelemetry=false` and `PI_TELEMETRY=0`). For tools whose state
  file is mutable, enforce via a `home.activation` `jq` patch (create-if-missing).
- **"Ultra" thinking == pi's `xhigh`** (off/minimal/low/medium/high/xhigh).
  The env-var efforts (`CLAUDE_THINKING_EFFORT`, codex `model_reasoning_effort`,
  hermes `reasoning_effort`) top out at `high` — don't invent higher values.
- **Bedrock auth has two paths.** The bearer token (`AWS_BEARER_TOKEN_BEDROCK`)
  works for `InvokeModel`/Converse and Bedrock's HTTPS endpoint accepts
  `Authorization: Bearer <token>` directly. The Anthropic SDK's `AnthropicBedrock`
  client is **SigV4-only** and fails with "could not resolve credentials from
  session" on a bearer-only host. kiro-cli does **not** use Bedrock at all — it
  authenticates with its own subscription/credits.
- **Unset leaked `AWS_PROFILE`.** botocore prefers `AWS_PROFILE` over the bearer
  token; a stale/undefined profile leaked from the login session makes every
  Bedrock call 500 with `ProfileNotFound`. The LiteLLM start script unsets
  `AWS_PROFILE`/static creds so the bearer token is the sole auth path.
- **Verify model reachability before claiming it works.** A direct InvokeModel
  probe (or `curl` to `/model/<id>/invoke`) proving HTTP 200 does not prove a
  given agent's code path works — agents route through different SDKs.
- **Patching pipx/venv tools:** ship an idempotent Python patcher in-repo and run
  it from `home.activation` **after** the pipx install/upgrade (pipx upgrade can
  overwrite the venv). Guard with a sentinel marker, and locate code by parsing
  (e.g. balance parens to find a signature end) rather than matching exact lines,
  so the patch survives upstream version drift. Wrap the agent binary in a
  `writeShellScriptBin` shim that exports the bearer token, mirroring pi/maki.
- **Flakes only see git-tracked files.** A new file referenced by a module won't
  build until `git add`-ed.

## CI Expectations (this repo)

- `deadnix --fail .` and `statix check .` are blocking in the Lint workflow — no
  unused bindings/args (prefix intentionally-unused lambda args with `_`).
  `nix fmt -- --check .` (nix-formatter-pack) is what CI's Lint job runs — run it
  locally before pushing.
- Tag-only workflows must **skip gracefully** when a referenced flake attribute
  doesn't exist (e.g. the ISO build checks `nix eval ...drvPath` first), so a
  missing optional output never fails a release.
