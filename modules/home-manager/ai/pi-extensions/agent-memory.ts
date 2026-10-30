/**
 * Shared agent memory for Pi (mcp-memory-service on the tailnet).
 *
 * The memory_* TOOLS reach Pi as the `agent-memory` MCP server through
 * ~/.config/mcp/mcp.json + pi-mcp-adapter. This extension does what
 * memelord's session-start hook used to: on the first turn, pull the memories
 * most relevant to this project and this request and inject them, with the
 * instructions for using the tools, as one hidden message.
 *
 * Endpoint and key come from the environment (set by mcps.nix):
 *   AGENT_MEMORY_URL       e.g. http://meh.ts.burd.me:8765
 *   AGENT_MEMORY_KEY_FILE  sops-rendered file holding the API key
 * Any failure (service down, no key) skips injection; the tools still work
 * if the server comes back.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { relative } from "node:path";

type Hit = {
  memory: { content: string; content_hash: string; tags: string[]; memory_type?: string };
  similarity_score?: number;
};

const INSTRUCTIONS = `# Memory system instructions

You share one persistent memory service with every agent on every host
(MCP server \`agent-memory\`). Use it:

1. At the start of a task, call memory_search with the request (add the
   project tag below to narrow it). The memories above are only a first pass.
2. When you self-correct, when the user corrects you, or when you learn
   something durable about a codebase, call memory_store. Put the lesson in
   \`content\`, and in \`metadata\` set \`tags\` to include the project tag
   below plus a kind tag (\`kind:correction\`, \`kind:user\`, \`kind:insight\`),
   and \`type\` to one of user_correction, preference_signal, insight, finding.
   The user should never have to tell you the same thing twice.
3. If a memory above is wrong, fix it: memory_update with its content_hash,
   or memory_delete it, and store the correct version.
`;

// Measured 2026-10-30 against the shared store: topic-free prompts score
// 0.63-0.65 against unrelated memories; real matches score 0.73+.
export const MIN_SIMILARITY = 0.7;
export const MIN_QUERY_WORDS = 4;

export const wordCount = (s: string): number => s.trim().split(/\s+/).filter(Boolean).length;

// Is a memory from this project, or a parent/child of it (ws/postgres vs
// ws/postgres/xtc)? Those outrank an unrelated project at equal relevance.
const nearProject = (h: Hit, rel: string): boolean =>
  h.memory.tags.some((t) => {
    if (!t.startsWith("project:")) return false;
    const p = t.slice("project:".length);
    return p === rel || rel.startsWith(`${p}/`) || p.startsWith(`${rel}/`);
  });

// This project's own memories first (newest first, as by-tag returns them),
// then relevance hits above the threshold, near projects ahead of far ones,
// deduplicated, capped at `max`.
export function mergeHits(proj: Hit[], relevant: Hit[], rel: string, max: number): Hit[] {
  const ranked = relevant
    .filter((h) => (h.similarity_score ?? 1) >= MIN_SIMILARITY)
    .map((h, i) => ({ h, i, near: nearProject(h, rel) }))
    .sort((a, b) => Number(b.near) - Number(a.near) || a.i - b.i)
    .map((x) => x.h);
  const out: Hit[] = [];
  const seen = new Set<string>();
  for (const h of [...proj, ...ranked]) {
    if (seen.has(h.memory.content_hash)) continue;
    seen.add(h.memory.content_hash);
    out.push(h);
  }
  return out.slice(0, max);
}

export default async function (pi: ExtensionAPI) {
  let injected = false;

  pi.on("before_agent_start", async (event, ctx) => {
    if (injected) return;
    injected = true;
    // Defaults cover terminals opened before the switch that set these.
    const base = process.env.AGENT_MEMORY_URL ?? "http://meh.ts.burd.me:8765";
    const keyFile =
      process.env.AGENT_MEMORY_KEY_FILE ?? `${homedir()}/.config/sops-nix/secrets/agent-memory/api-key`;
    let key = "";
    try {
      key = readFileSync(keyFile, "utf8").trim();
    } catch {
      return;
    }
    const rel = relative(homedir(), ctx.cwd) || "home";
    const projectTag = `project:${rel}`;
    const prompt = event.messageType === "user" ? event.prompt : "";
    const post = async (path: string, body: unknown): Promise<Hit[]> => {
      const res = await fetch(base + path, {
        method: "POST",
        headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(8000),
      });
      if (!res.ok) return [];
      const data = (await res.json()) as { results?: Hit[] };
      return data.results ?? [];
    };
    let hits: Hit[] = [];
    try {
      const [proj, rel2] = await Promise.all([
        // this project's newest memories
        post("/api/search/by-tag", { tags: [projectTag], limit: 8 }),
        // the most relevant memories anywhere for this request. A short
        // prompt ("please continue") has no topic: every memory scores
        // ~0.63-0.65 against it, so skip the search rather than inject noise.
        wordCount(prompt) >= MIN_QUERY_WORDS
          ? post("/api/search", {
              query: prompt.slice(0, 2000),
              n_results: 12,
              similarity_threshold: MIN_SIMILARITY,
            })
          : Promise.resolve([]),
      ]);
      hits = mergeHits(proj, rel2, rel, 10);
    } catch {
      return; // service unreachable -> no injection
    }
    // Budget like memelord's injection: ~10 memories, ~14k chars.
    const parts: string[] = [];
    let used = 0;
    for (const h of hits) {
      let text = h.memory.content;
      if (text.length > 2000) text = `${text.slice(0, 2000)} [...]`;
      if (used + text.length > 14000) break;
      used += text.length;
      parts.push(`[${h.memory.memory_type ?? "note"}] (hash: ${h.memory.content_hash.slice(0, 12)})\n${text}`);
    }
    const body = parts.join("\n\n");
    const content =
      (body ? `# Memories from past sessions\n\n${body}\n\n` : "") +
      INSTRUCTIONS +
      `\nThis project's tag: \`${projectTag}\`\n`;
    return {
      message: { customType: "agent-memory", content, display: false },
    };
  });
}
