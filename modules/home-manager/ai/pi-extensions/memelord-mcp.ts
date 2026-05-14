/**
 * Memelord MCP Extension
 *
 * Connects to the memelord MCP server via stdio transport.
 * Provides persistent memory across Pi sessions.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { StdioMCPClient } from "../lib/mcp-client";
import { existsSync } from "node:fs";
import { join } from "node:path";

export default async function (pi: ExtensionAPI) {
  let mcpClient: StdioMCPClient | null = null;
  let sessionActive = false;

  // Initialize memelord if needed
  const ensureMemelordInit = async (cwd: string): Promise<void> => {
    const memelordDir = join(cwd, ".memelord");
    if (!existsSync(memelordDir)) {
      try {
        await pi.exec("memelord", ["init", cwd]);
      } catch {
        // Already initialized or error - continue anyway
      }
    }
  };

  // Connect to memelord MCP server
  const connectMemelord = async (cwd: string): Promise<void> => {
    if (mcpClient) return; // Already connected

    await ensureMemelordInit(cwd);

    mcpClient = new StdioMCPClient("memelord", ["serve"], {
      MEMELORD_DIR: join(cwd, ".memelord"),
    });

    mcpClient.on("error", (err) => {
      console.error("Memelord MCP error:", err);
    });

    mcpClient.on("stderr", (data) => {
      // Memelord debug output
      if (process.env.DEBUG_MCP) {
        console.error("Memelord stderr:", data);
      }
    });

    try {
      await mcpClient.connect();
      await mcpClient.initialize({
        name: "pi-coding-agent",
        version: "0.73.0",
      });

      // Register memelord tools as Pi tools
      const tools = mcpClient.getTools();
      for (const tool of tools) {
        registerMemelordTool(tool);
      }

      sessionActive = true;
    } catch (err) {
      console.error("Failed to connect to memelord MCP:", err);
      mcpClient = null;
    }
  };

  // Register a memelord tool as a Pi tool
  const registerMemelordTool = (mcpTool: any): void => {
    pi.registerTool({
      name: `memelord_${mcpTool.name}`,
      label: `Memelord: ${mcpTool.name}`,
      description: mcpTool.description || `Memelord MCP tool: ${mcpTool.name}`,
      parameters: mcpTool.inputSchema,
      async execute(toolCallId, params, signal, onUpdate, ctx) {
        if (!mcpClient) {
          return {
            content: [
              {
                type: "text",
                text: "Memelord MCP server not connected",
              },
            ],
            isError: true,
          };
        }

        try {
          onUpdate?.({
            content: [{ type: "text", text: `Calling memelord: ${mcpTool.name}...` }],
          });

          const result = await mcpClient.callTool(mcpTool.name, params);

          return {
            content: result.content || [
              { type: "text", text: JSON.stringify(result) },
            ],
            isError: result.isError || false,
            details: result,
          };
        } catch (err) {
          return {
            content: [
              {
                type: "text",
                text: `Memelord error: ${err instanceof Error ? err.message : String(err)}`,
              },
            ],
            isError: true,
          };
        }
      },
    });
  };

  // Session lifecycle hooks
  pi.on("session_start", async (event, ctx) => {
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (!sessionFile) return; // Ephemeral session

    await connectMemelord(ctx.cwd);

    if (mcpClient && sessionActive) {
      ctx.ui.notify("🧠 Memelord MCP connected", "info");

      // Trigger session-start hook via tool call
      try {
        await mcpClient.callTool("session_start", {
          reason: event.reason,
          sessionFile,
          timestamp: Date.now(),
        });
      } catch (err) {
        // Tool might not exist, that's okay
        if (process.env.DEBUG_MCP) {
          console.error("Memelord session_start hook failed:", err);
        }
      }
    }
  });

  pi.on("agent_end", async (event, ctx) => {
    if (!mcpClient || !sessionActive) return;

    try {
      // Trigger post-tool-use equivalent
      await mcpClient.callTool("observe", {
        messages: event.messages,
        timestamp: Date.now(),
      });
    } catch (err) {
      // Tool might not exist
      if (process.env.DEBUG_MCP) {
        console.error("Memelord observe failed:", err);
      }
    }
  });

  pi.on("session_shutdown", async (event, ctx) => {
    if (!mcpClient || !sessionActive) return;

    try {
      // Trigger session-end hook
      await mcpClient.callTool("session_end", {
        reason: event.reason,
        timestamp: Date.now(),
      });
    } catch (err) {
      if (process.env.DEBUG_MCP) {
        console.error("Memelord session_end failed:", err);
      }
    }

    sessionActive = false;

    // Disconnect on quit, but keep alive on reload/switch
    if (event.reason === "quit") {
      await mcpClient.disconnect();
      mcpClient = null;
    }
  });

  // Command to check memelord status
  pi.registerCommand("memelord", {
    description: "Show memelord status and available tools",
    handler: async (_args, ctx) => {
      if (!mcpClient) {
        ctx.ui.notify("Memelord MCP not connected", "warning");
        return;
      }

      const tools = mcpClient.getTools();
      const resources = mcpClient.getResources();

      const lines = [
        "# Memelord MCP Status",
        "",
        "**Status:** Connected",
        `**Tools:** ${tools.length}`,
        `**Resources:** ${resources.length}`,
        "",
        "**Available Tools:**",
        ...tools.map((t) => `- memelord_${t.name}: ${t.description || "No description"}`),
      ];

      if (resources.length > 0) {
        lines.push("", "**Resources:**");
        lines.push(...resources.map((r) => `- ${r.uri}: ${r.name}`));
      }

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });
}
