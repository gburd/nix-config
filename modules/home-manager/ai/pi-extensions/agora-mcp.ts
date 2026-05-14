/**
 * Agora MCP Extension
 *
 * Connects to the Agora MCP server via SSE transport.
 * Provides access to 50+ tools for git/email/code intelligence.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { StreamableHTTPMCPClient } from "../lib/mcp-client";

const AGORA_URL = "https://postgr.esq/l/mcp/";

export default async function (pi: ExtensionAPI) {
  let mcpClient: StreamableHTTPMCPClient | null = null;

  // Connect to Agora MCP server
  const connectAgora = async (): Promise<void> => {
    if (mcpClient) return; // Already connected

    mcpClient = new StreamableHTTPMCPClient(AGORA_URL);

    mcpClient.on("error", (err) => {
      console.error("Agora MCP error:", err);
    });

    mcpClient.on("notification", (method, params) => {
      if (process.env.DEBUG_MCP) {
        console.log("Agora notification:", method, params);
      }
    });

    try {
      await mcpClient.connect();
      await mcpClient.initialize({
        name: "pi-coding-agent",
        version: "0.73.0",
      });

      // Register agora tools as Pi tools
      const tools = mcpClient.getTools();
      for (const tool of tools) {
        registerAgoraTool(tool);
      }

      // Register agora resources
      const resources = mcpClient.getResources();
      if (resources.length > 0 && process.env.DEBUG_MCP) {
        console.log("Agora resources available:", resources.length);
      }
    } catch (err) {
      console.error("Failed to connect to Agora MCP:", err);
      mcpClient = null;
      throw err;
    }
  };

  // Register an agora tool as a Pi tool
  const registerAgoraTool = (mcpTool: any): void => {
    // Group tools by category for better organization
    const category = getToolCategory(mcpTool.name);
    const label = category ? `${category}: ${mcpTool.name}` : mcpTool.name;

    pi.registerTool({
      name: mcpTool.name, // Keep original name for compatibility
      label,
      description: mcpTool.description || `Agora MCP tool: ${mcpTool.name}`,
      parameters: mcpTool.inputSchema,
      async execute(toolCallId, params, signal, onUpdate, ctx) {
        if (!mcpClient) {
          return {
            content: [
              {
                type: "text",
                text: "Agora MCP server not connected. Try /agora-reconnect",
              },
            ],
            isError: true,
          };
        }

        try {
          onUpdate?.({
            content: [{ type: "text", text: `Querying agora: ${mcpTool.name}...` }],
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
                text: `Agora error: ${err instanceof Error ? err.message : String(err)}`,
              },
            ],
            isError: true,
          };
        }
      },
    });
  };

  // Categorize tools for better labeling
  const getToolCategory = (toolName: string): string | null => {
    if (toolName.startsWith("git_")) return "Git";
    if (toolName.includes("search") || toolName.includes("semantic")) return "Search";
    if (toolName.includes("symbol") || toolName.includes("code")) return "Code";
    if (toolName.includes("message") || toolName.includes("thread")) return "Email";
    if (toolName.includes("inbox")) return "Inbox";
    if (toolName.includes("repository") || toolName.includes("repo")) return "Repository";
    return null;
  };

  // Connect on session start
  pi.on("session_start", async (event, ctx) => {
    try {
      await connectAgora();
      const toolCount = mcpClient?.getTools().length || 0;
      ctx.ui.notify(`🌐 Agora MCP connected (${toolCount} tools)`, "info");
    } catch (err) {
      ctx.ui.notify(
        `⚠️ Agora MCP connection failed: ${err instanceof Error ? err.message : String(err)}`,
        "warning",
      );
    }
  });

  pi.on("session_shutdown", async (event, ctx) => {
    if (event.reason === "quit" && mcpClient) {
      await mcpClient.disconnect();
      mcpClient = null;
    }
  });

  // Command to show agora status
  pi.registerCommand("agora", {
    description: "Show Agora MCP status and available tools",
    handler: async (_args, ctx) => {
      if (!mcpClient) {
        ctx.ui.notify(
          "Agora MCP not connected. Try /agora-reconnect",
          "warning",
        );
        return;
      }

      const tools = mcpClient.getTools();
      const resources = mcpClient.getResources();

      // Group tools by category
      const categories = new Map<string, string[]>();
      for (const tool of tools) {
        const cat = getToolCategory(tool.name) || "Other";
        if (!categories.has(cat)) categories.set(cat, []);
        categories.get(cat)!.push(tool.name);
      }

      const lines = [
        "# Agora MCP Status",
        "",
        "**Status:** Connected",
        `**Endpoint:** ${AGORA_URL}`,
        `**Total Tools:** ${tools.length}`,
        `**Resources:** ${resources.length}`,
        "",
      ];

      // Show tools by category
      for (const [cat, toolNames] of categories) {
        lines.push(`**${cat} (${toolNames.length}):**`);
        lines.push(...toolNames.slice(0, 10).map((n) => `- ${n}`));
        if (toolNames.length > 10) {
          lines.push(`  ... and ${toolNames.length - 10} more`);
        }
        lines.push("");
      }

      if (resources.length > 0) {
        lines.push("**Resources:**");
        lines.push(
          ...resources.slice(0, 5).map((r) => `- ${r.uri}: ${r.name}`),
        );
        if (resources.length > 5) {
          lines.push(`  ... and ${resources.length - 5} more`);
        }
      }

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  // Command to reconnect to agora
  pi.registerCommand("agora-reconnect", {
    description: "Reconnect to Agora MCP server",
    handler: async (_args, ctx) => {
      if (mcpClient) {
        await mcpClient.disconnect();
        mcpClient = null;
      }

      try {
        await connectAgora();
        const toolCount = mcpClient?.getTools().length || 0;
        ctx.ui.notify(
          `✅ Agora MCP reconnected (${toolCount} tools)`,
          "success",
        );
      } catch (err) {
        ctx.ui.notify(
          `❌ Agora reconnection failed: ${err instanceof Error ? err.message : String(err)}`,
          "error",
        );
      }
    },
  });

  // Tool to list available agora tools (for LLM discovery)
  pi.registerTool({
    name: "agora_list_tools",
    label: "Agora: List Tools",
    description:
      "List all available Agora MCP tools by category. Use this to discover what Agora can do.",
    parameters: {
      type: "object",
      properties: {
        category: {
          type: "string",
          description:
            "Optional filter by category (Git, Search, Code, Email, Inbox, Repository)",
          enum: ["Git", "Search", "Code", "Email", "Inbox", "Repository"],
        },
      },
    },
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      if (!mcpClient) {
        return {
          content: [
            { type: "text", text: "Agora MCP not connected" },
          ],
          isError: true,
        };
      }

      const tools = mcpClient.getTools();
      const categories = new Map<string, any[]>();

      for (const tool of tools) {
        const cat = getToolCategory(tool.name) || "Other";
        if (!params.category || cat === params.category) {
          if (!categories.has(cat)) categories.set(cat, []);
          categories.get(cat)!.push(tool);
        }
      }

      const lines: string[] = [];
      for (const [cat, catTools] of categories) {
        lines.push(`## ${cat} (${catTools.length} tools)`);
        lines.push("");
        for (const tool of catTools) {
          lines.push(`**${tool.name}**`);
          if (tool.description) {
            lines.push(`  ${tool.description}`);
          }
          lines.push("");
        }
      }

      return {
        content: [{ type: "text", text: lines.join("\n") }],
        details: { totalTools: tools.length, categories: Array.from(categories.keys()) },
      };
    },
  });
}
