/**
 * LiteLLM Provider Extension for Pi
 *
 * Routes Pi through the local LiteLLM proxy (modules/home-manager/ai/litellm.nix)
 * instead of talking to AWS Bedrock directly. Auth is a per-host virtual key
 * minted at LiteLLM activation time and stored at ~/.config/litellm/keys/pi.key
 * (mode 600).
 *
 * Models are discovered dynamically by GET-ing the proxy's /v1/models so the
 * proxy stays the single source of truth for which models we expose. If the
 * proxy is unreachable at extension load time the registration is silently
 * skipped — Pi continues with its built-in providers.
 *
 * See modules/home-manager/ai/litellm.nix for the proxy + virtual-key setup,
 * and pi's docs/custom-provider.md for the registerProvider() schema.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";

const LITELLM_URL = "http://127.0.0.1:4000/v1";
const KEY_FILE = `${process.env.HOME}/.config/litellm/keys/pi.key`;

// Model-id heuristics. We avoid hard-coding a list to prevent drift between
// litellm.nix's model_list and the pi extension; the proxy is authoritative.
const isClaude = (id: string) =>
  id.includes("claude") || id.includes("anthropic");
const isReasoning = (id: string) =>
  isClaude(id) || id.includes("opus") || id.includes("r1") || id.includes("o1");
const supportsImage = (id: string) =>
  isClaude(id) ||
  id.includes("nova-pro") ||
  id.includes("nova-premier") ||
  id.includes("pixtral") ||
  id.includes("llama4");

// Legacy built-in amazon-bedrock model ids (full inference-profile
// strings) that the proxy also exposes as aliases for old-session
// restore. They always start with a region+vendor prefix like
// "us.anthropic.", "us.meta.", etc. — our normal aliases never contain
// dots, so a dot is a reliable discriminator.
const isLegacyBedrockId = (id: string) => id.includes(".");

// Fallback context/output sizes used only when the proxy's /model/info
// doesn't carry explicit values for a model. The proxy (litellm.nix) sets
// model_info.max_input_tokens / max_output_tokens for every model, so these
// are last-resort defaults to keep the extension from ever under-sizing.
const fallbackContextFor = (id: string) => {
  if (isClaude(id)) return 200_000;
  if (id.includes("nova")) return 300_000;
  if (id.includes("llama")) return 128_000;
  return 128_000;
};

export default async function (pi: ExtensionAPI) {
  let key: string;
  try {
    key = readFileSync(KEY_FILE, "utf8").trim();
  } catch (err) {
    // No virtual key yet — likely litellm.service hasn't run mint-keys
    // (first activation). Skip registration cleanly; user can re-launch
    // pi after the next switch.
    pi.log?.(`litellm-extension: ${KEY_FILE} not readable (${(err as Error).message}); skipping`);
    return;
  }

  let payload: { data: Array<{ id: string }> };
  try {
    const resp = await fetch(`${LITELLM_URL}/models`, {
      headers: { Authorization: `Bearer ${key}` },
    });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    payload = (await resp.json()) as { data: Array<{ id: string }> };
  } catch (err) {
    pi.log?.(`litellm-extension: ${LITELLM_URL}/models unreachable (${(err as Error).message}); skipping`);
    return;
  }

  // Pull the authoritative per-model context + output ceilings from the
  // proxy's /model/info (litellm.nix sets model_info.max_input_tokens /
  // max_output_tokens for every alias). /v1/models only lists ids, so we
  // join the two by model_name. If /model/info is unreachable we fall
  // back to the heuristic sizes below.
  const infoByName = new Map<
    string,
    { maxInput?: number; maxOutput?: number }
  >();
  try {
    const infoResp = await fetch(`${LITELLM_URL.replace(/\/v1$/, "")}/model/info`, {
      headers: { Authorization: `Bearer ${key}` },
    });
    if (infoResp.ok) {
      const infoJson = (await infoResp.json()) as {
        data?: Array<{
          model_name?: string;
          model_info?: { max_input_tokens?: number; max_output_tokens?: number };
        }>;
      };
      for (const row of infoJson.data ?? []) {
        if (row.model_name) {
          infoByName.set(row.model_name, {
            maxInput: row.model_info?.max_input_tokens,
            maxOutput: row.model_info?.max_output_tokens,
          });
        }
      }
    }
  } catch (err) {
    pi.log?.(`litellm-extension: /model/info unreachable (${(err as Error).message}); using heuristic context sizes`);
  }

  pi.registerProvider("litellm", {
    baseUrl: LITELLM_URL,
    // `!command` form: pi runs cat each time it needs the key, so a
    // rotated key file takes effect on the next request without a pi
    // restart. Cheap (cat is fast, file is mode 600).
    apiKey: `!cat ${KEY_FILE}`,
    api: "openai-completions",
    // Skip the legacy-id aliases (us.anthropic.*) the proxy also exposes
    // for old-session restore; they're surfaced under the amazon-bedrock
    // provider below instead so the litellm picker stays clean.
    models: payload.data
      .filter((m) => !isLegacyBedrockId(m.id))
      .map((m) => {
        const info = infoByName.get(m.id);
        return {
          id: m.id,
          name: m.id,
          reasoning: isReasoning(m.id),
          input: supportsImage(m.id) ? ["text", "image"] : ["text"],
          // Cost is 0 because we pay AWS directly for Bedrock; the proxy is local.
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
          // True context window from the proxy (1M for Opus/Sonnet 4.6+,
          // 200K for legacy Claude, etc.), falling back to a heuristic.
          contextWindow: info?.maxInput ?? fallbackContextFor(m.id),
          // Full output budget from the proxy; the proxy itself also caps
          // max_tokens per model, so this just lets pi plan accurately.
          maxTokens: info?.maxOutput ?? 32_000,
        };
      }),
  });

  // Compatibility shim for pre-migration sessions.
  //
  // Before everything moved behind the proxy, Pi used its built-in
  // `amazon-bedrock` provider and persisted model ids like
  // "amazon-bedrock/us.anthropic.claude-opus-4-8" into the session
  // JSONL. Resuming such a session now prints:
  //   "Could not restore model amazon-bedrock/us.anthropic.claude-opus-4-8.
  //    Using litellm/claude-opus-4-8"
  // because Pi's built-in bedrock provider needs direct AWS creds we no
  // longer supply. Override the amazon-bedrock provider to point at the
  // local proxy and expose exactly the legacy ids the proxy now aliases
  // (see litellm.nix's `aliases`), so the restore resolves silently.
  // The thinking-normalizer hook keys on these ids too, so thinking is
  // handled identically.
  const legacyModels = payload.data.filter((m) => isLegacyBedrockId(m.id));
  if (legacyModels.length > 0) {
    pi.registerProvider("amazon-bedrock", {
      baseUrl: LITELLM_URL,
      apiKey: `!cat ${KEY_FILE}`,
      api: "openai-completions",
      models: legacyModels.map((m) => {
        const info = infoByName.get(m.id);
        return {
          id: m.id,
          name: m.id,
          reasoning: isReasoning(m.id),
          input: supportsImage(m.id) ? ["text", "image"] : ["text"],
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
          contextWindow: info?.maxInput ?? fallbackContextFor(m.id),
          maxTokens: info?.maxOutput ?? 32_000,
        };
      }),
    });
    pi.log?.(`litellm-extension: amazon-bedrock compat shim for ${legacyModels.length} legacy id(s)`);
  }

  pi.log?.(`litellm-extension: registered ${payload.data.length} models from ${LITELLM_URL}`);
}
