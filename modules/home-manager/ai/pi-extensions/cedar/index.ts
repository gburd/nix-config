/**
 * Cedar permissions for Pi, the same model maki uses (maki-cedar):
 *
 *   principal Agent::"pi", action Action::"invoke", resource Tool::"<key>",
 *   context { tool, scope }
 *
 * Tool keys and scopes match maki's, so one policy set (nix-config
 * modules/home-manager/ai/cedar-policies.nix, served by cedar-store on meh)
 * governs both agents:
 *   bash   -> "bash",  one check per simple command of the line
 *   edit   -> "edit",  scope = absolute path
 *   write  -> "write", scope = absolute path
 *   read   -> "read",  scope = absolute path
 *   MCP    -> "<server>.<tool>", scope "*"   (pi-mcp-adapter's mcp__<server>)
 * A forbid blocks the call (naming the policy), a permit or no match lets it
 * run: Cedar only adds explicit denies here, Pi's default stays "allow".
 *
 * Policies are fetched from the store and evaluated in process with the
 * official Cedar 4 WASM build, so a tool call never waits on the network.
 * The last good set is cached on disk and used when the store is down; with
 * no set at all the extension allows (and says so once).
 *
 * env: CEDAR_STORE_URL (default http://meh.ts.burd.me:8180),
 *      CEDAR_SYNC_SECS (default 300), CEDAR_DISABLE=1 to turn it off.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

type Policy = { id: string; content: string };
type Cedar = {
  isAuthorized(call: unknown): {
    type: "success" | "failure";
    response?: { decision: "allow" | "deny"; diagnostics: { reason: string[] } };
    errors?: { message: string }[];
  };
};

const STORE = process.env.CEDAR_STORE_URL ?? "http://meh.ts.burd.me:8180";
const SYNC_MS = Number(process.env.CEDAR_SYNC_SECS ?? 300) * 1000;
const CACHE = join(homedir(), ".cache", "pi-cedar", "policies.json");
const HOME = homedir();

const here = dirname(fileURLToPath(import.meta.url));
const cedar = createRequire(join(here, "index.ts"))("@cedar-policy/cedar-wasm/nodejs") as Cedar;

/** maki stores `~/...` scopes; tools send absolute paths. Expand at load. */
function expandHome(src: string): string {
  return src.replaceAll('like "~/', `like "${HOME.replace(/\/$/, "")}/`);
}

/**
 * context.project, spelled as maki_cedar::project_of spells it: the cwd
 * relative to $HOME, "~" at $HOME, the absolute path outside it.
 */
export function projectOf(cwd: string, home: string = HOME): string {
  const rel = relative(home, cwd);
  if (rel === "") return "~";
  if (rel.startsWith("..") || isAbsolute(rel)) return cwd;
  return rel.split(sep).join("/");
}

/** Policies keyed by store id: Cedar then reports that id as the deny reason. */
function toSet(policies: Policy[]): Record<string, string> {
  const set: Record<string, string> = {};
  for (const p of policies) set[p.id] = expandHome(p.content);
  return set;
}

/**
 * Split a bash line into the simple commands maki would check. Chains
 * (&&, ||, ;, |, newline) split; quotes are respected. Anything harder to
 * reason about (subshells, $(...), backticks, heredocs) is checked whole,
 * which only matters for forbids written against the whole line.
 */
export function bashScopes(line: string): string[] {
  if (/\$\(|`|<<|\(\s*[^)]*\)\s*$/.test(line)) return [line.trim()];
  const out: string[] = [];
  let cur = "";
  let q: string | null = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (q) {
      if (c === q) q = null;
      cur += c;
      continue;
    }
    if (c === "'" || c === '"') {
      q = c;
      cur += c;
      continue;
    }
    const two = line.slice(i, i + 2);
    if (two === "&&" || two === "||") {
      out.push(cur);
      cur = "";
      i++;
      continue;
    }
    if (c === ";" || c === "|" || c === "\n") {
      out.push(cur);
      cur = "";
      continue;
    }
    cur += c;
  }
  out.push(cur);
  return out.map((s) => s.trim()).filter((s) => s.length > 0);
}

/** Map a sanitized prefix back to the configured server name when it differs. */
let mcpNames: string[] | null = null;
function mcpServerName(prefix: string): string {
  if (mcpNames === null) {
    try {
      const j = JSON.parse(readFileSync(join(HOME, ".config", "mcp", "mcp.json"), "utf8"));
      mcpNames = Object.keys(j.mcpServers ?? {});
    } catch {
      mcpNames = [];
    }
  }
  if (mcpNames.includes(prefix)) return prefix;
  const norm = (s: string) => s.replace(/[^A-Za-z0-9]/g, "").toLowerCase();
  return mcpNames.find((n) => norm(n) === norm(prefix)) ?? prefix;
}

export default function (pi: ExtensionAPI) {
  if (process.env.CEDAR_DISABLE === "1") return;

  let policies: Record<string, string> | null = null;
  let lastSync = 0;
  let warnedEmpty = false;

  const load = (list: Policy[]) => {
    policies = toSet(list);
  };
  try {
    load(JSON.parse(readFileSync(CACHE, "utf8")) as Policy[]);
  } catch {
    /* no cache yet */
  }

  const sync = async () => {
    lastSync = Date.now();
    try {
      const res = await fetch(`${STORE}/v1/policies`, { signal: AbortSignal.timeout(5000) });
      if (!res.ok) return;
      const list = (await res.json()) as Policy[];
      load(list);
      mkdirSync(dirname(CACHE), { recursive: true });
      writeFileSync(`${CACHE}.tmp`, JSON.stringify(list));
      renameSync(`${CACHE}.tmp`, CACHE);
    } catch {
      /* store unreachable: keep the cached set */
    }
  };

  pi.on("session_start", async () => {
    await sync();
  });

  const decide = (tool: string, scope: string, project: string): { deny: string } | null => {
    if (!policies) return null;
    const r = cedar.isAuthorized({
      principal: { type: "Agent", id: "pi" },
      action: { type: "Action", id: "invoke" },
      resource: { type: "Tool", id: tool },
      context: { tool, scope, project },
      policies: { staticPolicies: policies },
      entities: [{ uid: { type: "Tool", id: tool }, attrs: { name: tool }, parents: [] }],
    });
    if (r.type !== "success" || !r.response) return null; // evaluation error: defer
    const reasons = r.response.diagnostics.reason;
    if (r.response.decision === "deny" && reasons.length > 0) return { deny: reasons.join(", ") };
    return null; // permit, or no policy matched: Pi's default (allow)
  };

  pi.on("tool_call", async (event, ctx) => {
    if (Date.now() - lastSync > SYNC_MS) void sync();
    if (!policies) {
      if (!warnedEmpty) {
        warnedEmpty = true;
        ctx.ui?.notify?.(`cedar: no policy set from ${STORE} yet; tools run unchecked`, "warning");
      }
      return;
    }
    const abs = (p: string) => (isAbsolute(p) ? p : resolve(ctx.cwd, p.replace(/^~(?=\/)/, HOME)));
    let checks: [string, string][] = [];
    if (isToolCallEventType("bash", event)) {
      checks = bashScopes(event.input.command).map((s) => ["bash", s]);
    } else if (isToolCallEventType("edit", event)) {
      checks = [["edit", abs(event.input.path)]];
    } else if (isToolCallEventType("write", event)) {
      checks = [["write", abs(event.input.path)]];
    } else if (isToolCallEventType("read", event)) {
      checks = [["read", abs(event.input.path)]];
    } else if (event.toolName.startsWith("mcp__")) {
      // pi-mcp-adapter names the proxy tool mcp__<server> (keeping `-`), and
      // the real tool is in input.tool. The server key must be the name in
      // mcp.json, which is what maki and the policies use.
      const server = mcpServerName(event.toolName.slice(5));
      const tool = (event.input as { tool?: string }).tool;
      if (tool) checks = [[`${server}.${tool}`, "*"]];
    }
    for (const [tool, scope] of checks) {
      const d = decide(tool, scope, projectOf(ctx.cwd));
      if (d) {
        return {
          block: true,
          reason: `Permission denied for \`${tool}\` (${scope}): denied by Cedar policy ${d.deny}. Do not retry. Try a different approach or ask the user for guidance.`,
        };
      }
    }
  });
}
