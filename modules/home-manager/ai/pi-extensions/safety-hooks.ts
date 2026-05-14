/**
 * Safety Hooks Extension
 *
 * Replicates Claude Code's PreToolUse safety checks:
 * - Block rm -rf (suggest trash instead)
 * - Block force push
 * - Warn on sensitive directory edits
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

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
  });

  // Track session start for status
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setStatus("safety", "🛡️  Safety hooks active");
  });
}
