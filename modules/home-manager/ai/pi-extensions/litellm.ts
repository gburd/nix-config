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
const contextFor = (id: string) => {
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

  pi.registerProvider("litellm", {
    baseUrl: LITELLM_URL,
    // `!command` form: pi runs cat each time it needs the key, so a
    // rotated key file takes effect on the next request without a pi
    // restart. Cheap (cat is fast, file is mode 600).
    apiKey: `!cat ${KEY_FILE}`,
    api: "openai-completions",
    models: payload.data.map((m) => ({
      id: m.id,
      name: m.id,
      reasoning: isReasoning(m.id),
      input: supportsImage(m.id) ? ["text", "image"] : ["text"],
      // Cost is 0 because we pay AWS directly for Bedrock; the proxy is local.
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: contextFor(m.id),
      // Matches litellm.nix's max_tokens; LiteLLM clamps to model ceiling.
      maxTokens: 32_000,
    })),
  });

  pi.log?.(`litellm-extension: registered ${payload.data.length} models from ${LITELLM_URL}`);
}
