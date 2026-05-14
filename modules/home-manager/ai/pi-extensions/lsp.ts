/**
 * LSP Extension for Pi
 *
 * Provides Language Server Protocol integration for multiple languages.
 * Auto-detects language and spawns appropriate LSP server.
 *
 * Supported languages:
 * - Rust (rust-analyzer)
 * - C/C++ (clangd)
 * - Python (pyright or pylsp)
 * - Go (gopls)
 * - Perl (PLS)
 * - Nix (nil or nixd)
 * - SQL (sqls)
 * - JSON (vscode-json-language-server)
 * - YAML (yaml-language-server)
 * - TOML (taplo)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { LSPClient, type LSPPosition, type LSPLocation } from "../lib/lsp-client";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname, extname } from "node:path";
import { Type } from "typebox";

interface LSPServerInfo {
  command: string;
  args?: string[];
  extensions: string[];
  initOptions?: any;
}

const LSP_SERVERS: Record<string, LSPServerInfo> = {
  rust: {
    command: "rust-analyzer",
    extensions: [".rs"],
  },
  clangd: {
    command: "clangd",
    args: ["--background-index", "--clang-tidy"],
    extensions: [".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".hxx"],
  },
  pyright: {
    command: "pyright-langserver",
    args: ["--stdio"],
    extensions: [".py", ".pyi"],
  },
  gopls: {
    command: "gopls",
    args: ["serve"],
    extensions: [".go"],
  },
  pls: {
    command: "pls",
    extensions: [".pl", ".pm"],
  },
  nil: {
    command: "nil",
    extensions: [".nix"],
  },
  sqls: {
    command: "sqls",
    extensions: [".sql"],
  },
  json: {
    command: "vscode-json-language-server",
    args: ["--stdio"],
    extensions: [".json", ".jsonc"],
  },
  yaml: {
    command: "yaml-language-server",
    args: ["--stdio"],
    extensions: [".yaml", ".yml"],
  },
  toml: {
    command: "taplo",
    args: ["lsp", "stdio"],
    extensions: [".toml"],
  },
};

export default async function (pi: ExtensionAPI) {
  const lspClients = new Map<string, LSPClient>(); // language -> client
  const diagnosticsMap = new Map<string, any[]>(); // uri -> diagnostics

  // Detect language from file path
  const detectLanguage = (filePath: string): string | null => {
    const ext = extname(filePath).toLowerCase();

    for (const [lang, info] of Object.entries(LSP_SERVERS)) {
      if (info.extensions.includes(ext)) {
        return lang;
      }
    }

    return null;
  };

  // Get or create LSP client for language
  const getClient = async (language: string, rootPath: string): Promise<LSPClient | null> => {
    if (lspClients.has(language)) {
      return lspClients.get(language)!;
    }

    const serverInfo = LSP_SERVERS[language];
    if (!serverInfo) return null;

    try {
      const client = new LSPClient({
        command: serverInfo.command,
        args: serverInfo.args,
        rootPath,
        initializationOptions: serverInfo.initOptions,
      });

      client.on("error", (err) => {
        console.error(`LSP ${language} error:`, err);
      });

      client.on("stderr", (data) => {
        if (process.env.DEBUG_LSP) {
          console.error(`LSP ${language} stderr:`, data);
        }
      });

      client.on("diagnostics", (params) => {
        diagnosticsMap.set(params.uri, params.diagnostics);
      });

      await client.start();
      await client.initialize();

      lspClients.set(language, client);
      return client;
    } catch (err) {
      console.error(`Failed to start ${language} LSP server:`, err);
      return null;
    }
  };

  // Convert file path to URI
  const pathToUri = (path: string): string => {
    return `file://${resolve(path)}`;
  };

  // Convert URI to file path
  const uriToPath = (uri: string): string => {
    return uri.replace(/^file:\/\//, "");
  };

  // Parse line:col format
  const parsePosition = (posStr: string): LSPPosition | null => {
    const match = posStr.match(/^(\d+):(\d+)$/);
    if (!match) return null;
    return {
      line: parseInt(match[1], 10) - 1, // Convert to 0-indexed
      character: parseInt(match[2], 10) - 1,
    };
  };

  // Format location for display
  const formatLocation = (loc: LSPLocation): string => {
    const path = uriToPath(loc.uri);
    const line = loc.range.start.line + 1; // Convert to 1-indexed
    const col = loc.range.start.character + 1;
    return `${path}:${line}:${col}`;
  };

  // Tool: goto_definition
  pi.registerTool({
    name: "lsp_goto_definition",
    label: "LSP: Go to Definition",
    description: "Find the definition of a symbol at a specific position in a file",
    parameters: Type.Object({
      file: Type.String({ description: "File path" }),
      position: Type.String({ description: "Position as line:column (1-indexed)" }),
    }),
    async execute(_toolCallId, params, _signal, onUpdate, ctx) {
      const { file, position } = params;

      onUpdate?.({ content: [{ type: "text", text: `Finding definition in ${file}...` }] });

      const language = detectLanguage(file);
      if (!language) {
        return {
          content: [{ type: "text", text: `No LSP server available for ${file}` }],
          isError: true,
        };
      }

      const client = await getClient(language, ctx.cwd);
      if (!client) {
        return {
          content: [{ type: "text", text: `Failed to start ${language} LSP server` }],
          isError: true,
        };
      }

      const pos = parsePosition(position);
      if (!pos) {
        return {
          content: [{ type: "text", text: `Invalid position format: ${position} (expected line:col)` }],
          isError: true,
        };
      }

      try {
        const uri = pathToUri(file);
        const text = readFileSync(file, "utf-8");
        await client.didOpen(uri, language, 1, text);

        const locations = await client.gotoDefinition(uri, pos);

        if (!locations || locations.length === 0) {
          return {
            content: [{ type: "text", text: "No definition found" }],
            details: {},
          };
        }

        const lines = ["# Definitions", ""];
        for (const loc of locations) {
          lines.push(`- ${formatLocation(loc)}`);
        }

        return {
          content: [{ type: "text", text: lines.join("\n") }],
          details: { locations: locations.map(formatLocation) },
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: `LSP error: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  });

  // Tool: find_references
  pi.registerTool({
    name: "lsp_find_references",
    label: "LSP: Find References",
    description: "Find all references to a symbol at a specific position in a file",
    parameters: Type.Object({
      file: Type.String({ description: "File path" }),
      position: Type.String({ description: "Position as line:column (1-indexed)" }),
      include_declaration: Type.Optional(Type.Boolean({ description: "Include declaration in results" })),
    }),
    async execute(_toolCallId, params, _signal, onUpdate, ctx) {
      const { file, position, include_declaration = false } = params;

      onUpdate?.({ content: [{ type: "text", text: `Finding references in ${file}...` }] });

      const language = detectLanguage(file);
      if (!language) {
        return {
          content: [{ type: "text", text: `No LSP server available for ${file}` }],
          isError: true,
        };
      }

      const client = await getClient(language, ctx.cwd);
      if (!client) {
        return {
          content: [{ type: "text", text: `Failed to start ${language} LSP server` }],
          isError: true,
        };
      }

      const pos = parsePosition(position);
      if (!pos) {
        return {
          content: [{ type: "text", text: `Invalid position format: ${position}` }],
          isError: true,
        };
      }

      try {
        const uri = pathToUri(file);
        const text = readFileSync(file, "utf-8");
        await client.didOpen(uri, language, 1, text);

        const locations = await client.findReferences(uri, pos, include_declaration);

        if (!locations || locations.length === 0) {
          return {
            content: [{ type: "text", text: "No references found" }],
            details: {},
          };
        }

        const lines = [`# References (${locations.length})`, ""];
        for (const loc of locations) {
          lines.push(`- ${formatLocation(loc)}`);
        }

        return {
          content: [{ type: "text", text: lines.join("\n") }],
          details: { count: locations.length, locations: locations.map(formatLocation) },
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: `LSP error: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  });

  // Tool: hover (documentation)
  pi.registerTool({
    name: "lsp_hover",
    label: "LSP: Hover Info",
    description: "Get documentation/type information for a symbol at a specific position",
    parameters: Type.Object({
      file: Type.String({ description: "File path" }),
      position: Type.String({ description: "Position as line:column (1-indexed)" }),
    }),
    async execute(_toolCallId, params, _signal, onUpdate, ctx) {
      const { file, position } = params;

      onUpdate?.({ content: [{ type: "text", text: `Getting info for ${file}...` }] });

      const language = detectLanguage(file);
      if (!language) {
        return {
          content: [{ type: "text", text: `No LSP server available for ${file}` }],
          isError: true,
        };
      }

      const client = await getClient(language, ctx.cwd);
      if (!client) {
        return {
          content: [{ type: "text", text: `Failed to start ${language} LSP server` }],
          isError: true,
        };
      }

      const pos = parsePosition(position);
      if (!pos) {
        return {
          content: [{ type: "text", text: `Invalid position format: ${position}` }],
          isError: true,
        };
      }

      try {
        const uri = pathToUri(file);
        const text = readFileSync(file, "utf-8");
        await client.didOpen(uri, language, 1, text);

        const hover = await client.hover(uri, pos);

        if (!hover) {
          return {
            content: [{ type: "text", text: "No information available" }],
            details: {},
          };
        }

        let content = "";
        if (typeof hover.contents === "string") {
          content = hover.contents;
        } else if (hover.contents && typeof hover.contents === "object") {
          if ("language" in hover.contents) {
            content = `\`\`\`${hover.contents.language}\n${hover.contents.value}\n\`\`\``;
          } else {
            content = JSON.stringify(hover.contents);
          }
        }

        return {
          content: [{ type: "text", text: content }],
          details: { hover },
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: `LSP error: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  });

  // Tool: rename
  pi.registerTool({
    name: "lsp_rename",
    label: "LSP: Rename Symbol",
    description: "Rename a symbol across all references in the project",
    parameters: Type.Object({
      file: Type.String({ description: "File path" }),
      position: Type.String({ description: "Position as line:column (1-indexed)" }),
      new_name: Type.String({ description: "New name for the symbol" }),
    }),
    async execute(_toolCallId, params, _signal, onUpdate, ctx) {
      const { file, position, new_name } = params;

      onUpdate?.({ content: [{ type: "text", text: `Renaming symbol in ${file}...` }] });

      const language = detectLanguage(file);
      if (!language) {
        return {
          content: [{ type: "text", text: `No LSP server available for ${file}` }],
          isError: true,
        };
      }

      const client = await getClient(language, ctx.cwd);
      if (!client) {
        return {
          content: [{ type: "text", text: `Failed to start ${language} LSP server` }],
          isError: true,
        };
      }

      const pos = parsePosition(position);
      if (!pos) {
        return {
          content: [{ type: "text", text: `Invalid position format: ${position}` }],
          isError: true,
        };
      }

      try {
        const uri = pathToUri(file);
        const text = readFileSync(file, "utf-8");
        await client.didOpen(uri, language, 1, text);

        const result = await client.rename(uri, pos, new_name);

        if (!result || !result.changes) {
          return {
            content: [{ type: "text", text: "Cannot rename this symbol" }],
            details: {},
          };
        }

        const fileCount = Object.keys(result.changes).length;
        let totalEdits = 0;
        const lines = [`# Rename to '${new_name}'`, "", `**Files affected:** ${fileCount}`, ""];

        for (const [fileUri, edits] of Object.entries(result.changes)) {
          const filePath = uriToPath(fileUri as string);
          lines.push(`- ${filePath}: ${(edits as any[]).length} edits`);
          totalEdits += (edits as any[]).length;
        }

        lines.push("", `**Total edits:** ${totalEdits}`);

        return {
          content: [{ type: "text", text: lines.join("\n") }],
          details: { workspaceEdit: result, fileCount, totalEdits },
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: `LSP error: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  });

  // Tool: diagnostics
  pi.registerTool({
    name: "lsp_diagnostics",
    label: "LSP: Get Diagnostics",
    description: "Get compiler errors, warnings, and hints for a file",
    parameters: Type.Object({
      file: Type.String({ description: "File path" }),
    }),
    async execute(_toolCallId, params, _signal, onUpdate, ctx) {
      const { file } = params;

      onUpdate?.({ content: [{ type: "text", text: `Checking ${file}...` }] });

      const language = detectLanguage(file);
      if (!language) {
        return {
          content: [{ type: "text", text: `No LSP server available for ${file}` }],
          isError: true,
        };
      }

      const client = await getClient(language, ctx.cwd);
      if (!client) {
        return {
          content: [{ type: "text", text: `Failed to start ${language} LSP server` }],
          isError: true,
        };
      }

      try {
        const uri = pathToUri(file);
        const text = readFileSync(file, "utf-8");
        await client.didOpen(uri, language, 1, text);

        // Wait briefly for diagnostics
        await new Promise((resolve) => setTimeout(resolve, 1000));

        const diagnostics = diagnosticsMap.get(uri) || [];

        if (diagnostics.length === 0) {
          return {
            content: [{ type: "text", text: "✅ No issues found" }],
            details: { count: 0 },
          };
        }

        const severityNames = ["", "Error", "Warning", "Info", "Hint"];
        const lines = [`# Diagnostics (${diagnostics.length})`, ""];

        for (const diag of diagnostics) {
          const severity = severityNames[diag.severity || 1];
          const line = diag.range.start.line + 1;
          const col = diag.range.start.character + 1;
          lines.push(`**${severity}** at ${line}:${col}: ${diag.message}`);
          if (diag.code) {
            lines.push(`  Code: ${diag.code}`);
          }
          lines.push("");
        }

        return {
          content: [{ type: "text", text: lines.join("\n") }],
          details: { count: diagnostics.length, diagnostics },
        };
      } catch (err) {
        return {
          content: [{ type: "text", text: `LSP error: ${err instanceof Error ? err.message : String(err)}` }],
          isError: true,
        };
      }
    },
  });

  // Command: lsp status
  pi.registerCommand("lsp", {
    description: "Show LSP server status",
    handler: async (_args, ctx) => {
      const lines = ["# LSP Server Status", ""];

      if (lspClients.size === 0) {
        lines.push("No LSP servers running");
      } else {
        lines.push(`**Active servers:** ${lspClients.size}`, "");
        for (const [lang, client] of lspClients) {
          const status = client.isInitialized() ? "✅ Ready" : "⏳ Starting";
          lines.push(`- **${lang}**: ${status}`);

          const caps = client.getCapabilities();
          if (caps.definitionProvider) lines.push("  - Go to definition");
          if (caps.referencesProvider) lines.push("  - Find references");
          if (caps.hoverProvider) lines.push("  - Hover info");
          if (caps.renameProvider) lines.push("  - Rename");
          if (caps.documentFormattingProvider) lines.push("  - Formatting");
        }
      }

      lines.push("", "**Supported languages:**");
      for (const [lang, info] of Object.entries(LSP_SERVERS)) {
        lines.push(`- **${lang}**: ${info.extensions.join(", ")}`);
      }

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  // Shutdown on exit
  pi.on("session_shutdown", async (_event, _ctx) => {
    for (const client of lspClients.values()) {
      await client.shutdown();
    }
    lspClients.clear();
  });
}
