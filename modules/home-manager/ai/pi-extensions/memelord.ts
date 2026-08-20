/**
 * Memelord lifecycle hooks for Pi.
 *
 * memelord's *tools* (memory_start_task, memory_report, ...) already reach Pi
 * as an MCP server via ~/.config/mcp/mcp.json + pi-mcp-adapter (lazy). What was
 * missing is memelord's automatic behavior, which upstream drives through
 * Claude-Code/Kiro-style hooks (memelord hook session-start / stop /
 * session-end). Pi has no hooks.json -- it uses TypeScript extensions -- so
 * this bridges those hook commands onto Pi's lifecycle events:
 *
 *   before_agent_start (first turn) -> `memelord hook session-start`
 *        inject the top-weighted memories + the memory-usage instructions
 *        into the session as a persistent message, so the model actually
 *        pulls past-session knowledge and knows to call the memory_* tools.
 *   session_shutdown                -> `memelord hook stop` then `session-end`
 *        let memelord record/embed new memories and run its weight decay.
 *
 * memelord's hook CLI speaks the Claude-Code hook protocol: JSON on stdin
 * ({session_id, cwd, ...}), and session-start prints
 * {hookSpecificOutput:{additionalContext}}. We pipe via `sh -c` since pi.exec
 * has no stdin option. All hooks no-op (exit 0) when cwd has no .memelord/,
 * so this is harmless in projects that don't use memelord.
 *
 * (Replaces the never-deployed, broken pi-extensions/memelord-mcp.ts, which
 * imported a lib/mcp-client that doesn't exist and reimplemented MCP stdio
 * that pi-mcp-adapter already provides.)
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Single-quote-safe wrapper for embedding a JSON payload in `sh -c '... echo <j> ...'`.
const shQuote = (s: string): string => `'${s.replace(/'/g, `'\\''`)}'`;

export default async function (pi: ExtensionAPI) {
  let injected = false; // session-start hook fires once per session

  const runHook = async (
    event: string,
    payload: Record<string, unknown>,
    cwd: string,
    signal?: AbortSignal,
  ): Promise<string> => {
    const json = shQuote(JSON.stringify(payload));
    // `memelord` is on PATH (home.packages); hook reads stdin, writes stdout.
    const res = await pi.exec(
      "sh",
      ["-c", `printf '%s' ${json} | memelord hook ${event}`],
      { cwd, signal, timeout: 15000 },
    );
    return res.stdout ?? "";
  };

  pi.on("before_agent_start", async (_event, ctx) => {
    if (injected) return; // only the first turn injects past memories
    injected = true;
    // Ephemeral sessions (no session file) skip memory persistence.
    const sessionId = ctx.sessionManager.getSessionId?.() ?? "pi";
    let out = "";
    try {
      out = await runHook("session-start", { session_id: sessionId, cwd: ctx.cwd }, ctx.cwd);
    } catch {
      return; // memelord absent/errored -> silently skip (tools still work)
    }
    // session-start prints Claude-Code hook JSON; pull out additionalContext.
    let context = "";
    try {
      const parsed = JSON.parse(out.trim());
      context = parsed?.hookSpecificOutput?.additionalContext ?? "";
    } catch {
      context = ""; // no .memelord/ (hook exited 0 with no output) -> nothing
    }
    if (!context) return;
    return {
      message: {
        customType: "memelord",
        content: context,
        display: false, // memory context is for the model, not screen clutter
      },
    };
  });

  pi.on("session_shutdown", async (event, ctx) => {
    const sessionId = ctx.sessionManager.getSessionId?.() ?? "pi";
    const payload = { session_id: sessionId, cwd: ctx.cwd, reason: event.reason };
    // stop: record correction/discovery patterns from the transcript;
    // session-end: embed new memories + weight decay. Both best-effort.
    for (const hook of ["stop", "session-end"]) {
      try {
        await runHook(hook, payload, ctx.cwd);
      } catch {
        /* best-effort: never block shutdown on memelord */
      }
    }
  });
}
