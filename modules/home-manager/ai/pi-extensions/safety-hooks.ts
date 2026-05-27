/**
 * Safety Hooks Extension
 *
 * Replicates Claude Code's PreToolUse safety checks:
 * - Block rm -rf (suggest trash instead)
 * - Block force push
 * - Warn on sensitive directory edits
 * - Validate sub-agent dispatch model IDs against known-good
 *   Bedrock cross-region inference profiles
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

/**
 * Bedrock model IDs come in two flavors:
 *   - bare:                anthropic.claude-haiku-4-5-...
 *   - inference profile:   us.anthropic.claude-haiku-4-5-...
 *
 * On-demand throughput (the default for most users) is supported
 * ONLY by inference-profile IDs. Bare IDs require provisioned
 * throughput. Pi's fuzzy matcher ("sonnet", "haiku", ...) can
 * resolve to either form depending on what the resolver picks
 * first; if it lands on a bare ID, the sub-agent invocation
 * fails with:
 *
 *   Validation error: Invocation of model ID anthropic.claude-...
 *   with on-demand throughput isn't supported. Retry your request
 *   with the ID or ARN of an inference profile that contains
 *   this model.
 *
 * The sub-agent dies after ~1 second with no usable output and
 * the parent agent sees only "completed: 0 tool uses". This
 * intercept catches that footgun at dispatch time.
 */
const KNOWN_BAD_MODEL = /^anthropic\.claude-/;
const KNOWN_GOOD_MODEL = /^(us|eu|apac)\./;
const FUZZY_NAMES = new Set([
  "sonnet", "opus", "haiku",
  "claude-sonnet", "claude-opus", "claude-haiku",
]);
const DEFAULT_REGION_PREFIX = "us.";

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    // Block dangerous bash commands
    if (isToolCallEventType("bash", event)) {
      const { command } = event.input;

      // Block rm -rf
      if (/rm\s+-[^\s]*r[^\s]*f/.test(command)) {
        return {
          block: true,
          reason: "BLOCKED: Use trash instead of rm -rf. Add to allowed patterns if needed.",
        };
      }

      // Block direct push to main/master
      // REMOVED per user request; push to main/master is permitted.

      // Block force push
      if (/git\s+push.*--force/.test(command)) {
        return {
          block: true,
          reason: "BLOCKED: Never force push. Use git push --force-with-lease if absolutely necessary (after manual approval).",
        };
      }

      // Warn on sudo (but don't block)
      if (/^\s*sudo\s/.test(command)) {
        ctx.ui.notify("⚠️  Sudo detected - verify necessity", "warning");
      }
    }

    // Block writes to sensitive files
    if (isToolCallEventType("edit", event)) {
      const { path } = event.input;
      const sensitive = [
        /\.ssh\//,
        /\.aws\//,
        /\.env$/,
        /\.bashrc$/,
        /\.zshrc$/,
        /\.npmrc$/,
      ];

      for (const pattern of sensitive) {
        if (pattern.test(path)) {
          const ok = await ctx.ui.confirm(
            "Sensitive File",
            `Edit ${path}? This may break your environment.`,
          );
          if (!ok) {
            return { block: true, reason: "User declined sensitive file edit" };
          }
        }
      }
    }

    // Block writes to protected directories
    if (isToolCallEventType("write", event)) {
      const { path } = event.input;
      const protected_paths = [/\.git\//, /node_modules\//];

      for (const pattern of protected_paths) {
        if (pattern.test(path)) {
          return {
            block: true,
            reason: `BLOCKED: Cannot write to protected directory: ${path}`,
          };
        }
      }
    }

    // Validate sub-agent dispatch.
    //
    // The Agent tool accepts a `model` parameter as either
    // a fuzzy name ("sonnet") or an explicit Bedrock model ID.
    // Pi's resolver can hand the call a bare anthropic.* ID,
    // which Bedrock then rejects on-demand. Block bare IDs and
    // warn on fuzzy names so the operator either omits the
    // parameter (inherit parent's model -- best practice) or
    // passes a verified inference profile ID.
    if (isToolCallEventType("Agent", event)) {
      const model = (event.input as { model?: string }).model;
      if (typeof model === "string" && model.length > 0) {
        if (KNOWN_BAD_MODEL.test(model)) {
          return {
            block: true,
            reason: [
              `BLOCKED: Sub-agent dispatched with bare Bedrock model ID '${model}'.`,
              "On-demand throughput is not supported for bare model IDs.",
              "Use a cross-region inference profile (prefix 'us.', 'eu.',",
              "or 'apac.') OR omit the model parameter entirely so the",
              "sub-agent inherits the parent's working model.",
            ].join(" "),
          };
        }
        if (FUZZY_NAMES.has(model.toLowerCase())) {
          ctx.ui.notify(
            `Sub-agent model='${model}' is a fuzzy name; if dispatch fails ` +
              "with 'on-demand throughput not supported', omit the model " +
              "parameter and let the sub-agent inherit the parent's model.",
            "warning",
          );
        } else if (!KNOWN_GOOD_MODEL.test(model)) {
          // Unknown but not provably bad: pass through with a note.
          ctx.ui.notify(
            `Sub-agent model='${model}' does not match a known Bedrock ` +
              "inference-profile prefix (us./eu./apac.). Verify the model " +
              "is dispatchable before relying on this sub-agent.",
            "warning",
          );
        }
      }
    }
  });

  // Track session start for status
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setStatus("safety", "🛡️  Safety hooks active");
  });

  // Warn when the parent session selects a bare model ID.
  pi.on("model_select", async (event, ctx) => {
    const id = event.model.id;
    if (KNOWN_BAD_MODEL.test(id)) {
      ctx.ui.notify(
        `⚠️  Model '${id}' is a bare Bedrock ID (no inference profile prefix). ` +
          "On-demand invocations will fail. Use /model with a 'us.' prefixed ID " +
          "or let the default model from settings.json take effect.",
        "warning",
      );
    }
  });

  // Rewrite bare model IDs in the provider request payload before they
  // reach Bedrock. This catches cases where Pi's internal resolver lands
  // on a bare ID despite enabledModels containing only inference profiles.
  pi.on("before_provider_request", async (event) => {
    const payload = event.payload as Record<string, unknown> | undefined;
    if (!payload || typeof payload !== "object") return;
    const modelId = payload.modelId ?? payload.model;
    if (typeof modelId === "string" && KNOWN_BAD_MODEL.test(modelId)) {
      const fixed = DEFAULT_REGION_PREFIX + modelId;
      const key = "modelId" in payload ? "modelId" : "model";
      (payload as Record<string, unknown>)[key] = fixed;
      return payload;
    }
  });
}
