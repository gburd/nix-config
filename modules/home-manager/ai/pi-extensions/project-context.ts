/**
 * Project Context Extension
 *
 * Automatically loads project-specific context files (AGENTS.md, CLAUDE.md, README.md)
 * when working in different projects. Helps Pi understand project conventions without
 * explicit prompting.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const CONTEXT_FILES = ["AGENTS.md", "CLAUDE.md", "README.md"];

interface ProjectContext {
  cwd: string;
  files: Map<string, string>; // filename -> content
  loaded: boolean;
}

function loadProjectContext(cwd: string): ProjectContext {
  const files = new Map<string, string>();

  for (const filename of CONTEXT_FILES) {
    const path = join(cwd, filename);
    if (existsSync(path)) {
      try {
        const content = readFileSync(path, "utf-8");
        files.set(filename, content);
      } catch {
        // Skip unreadable files
      }
    }
  }

  return { cwd, files, loaded: files.size > 0 };
}

function summarizeProjectContext(context: ProjectContext): string {
  const lines: string[] = [];

  for (const [filename, content] of context.files) {
    const firstSection = content.split("\n\n")[0]; // First paragraph/section
    const preview =
      firstSection.length > 200
        ? firstSection.slice(0, 200) + "..."
        : firstSection;
    lines.push(`**${filename}**: ${preview}`);
  }

  return lines.join("\n\n");
}

export default function (pi: ExtensionAPI) {
  let lastContext: ProjectContext | null = null;

  // Load project context on session start
  pi.on("session_start", async (_event, ctx) => {
    const context = loadProjectContext(ctx.cwd);

    if (context.loaded && context.cwd !== lastContext?.cwd) {
      lastContext = context;

      const fileList = Array.from(context.files.keys()).join(", ");
      ctx.ui.notify(`📚 Loaded project context: ${fileList}`, "info");

      // Don't inject into context automatically - let /project command do it
      // This avoids polluting every session with large README files
    }
  });

  // Command to inject project context
  pi.registerCommand("project", {
    description: "Load project context files (AGENTS.md, CLAUDE.md, README.md)",
    handler: async (_args, ctx) => {
      const context = loadProjectContext(ctx.cwd);

      if (!context.loaded) {
        ctx.ui.notify("No project context files found", "info");
        return;
      }

      const sections: string[] = [];

      for (const [filename, content] of context.files) {
        sections.push(`# ${filename}\n\n${content}`);
      }

      const message = `# Project Context\n\n${sections.join("\n\n---\n\n")}`;

      pi.sendMessage(
        {
          customType: "project-context",
          content: message,
          display: true,
        },
        {
          triggerTurn: false, // Just add to context, don't start new turn
        },
      );

      ctx.ui.notify(
        `✅ Loaded ${context.files.size} context file(s)`,
        "success",
      );
    },
  });

  // Command to show project context summary
  pi.registerCommand("project-info", {
    description: "Show summary of project context",
    handler: async (_args, ctx) => {
      const context = loadProjectContext(ctx.cwd);

      if (!context.loaded) {
        ctx.ui.notify("No project context files found", "info");
        return;
      }

      const summary = summarizeProjectContext(context);
      const title = `Project: ${ctx.cwd.split("/").pop()}`;

      ctx.ui.notify(`${title}\n\n${summary}`, "info");
    },
  });

  // Tool for LLM to query project context
  pi.registerTool({
    name: "get_project_context",
    label: "Get Project Context",
    description:
      "Load project-specific context files (AGENTS.md, CLAUDE.md, README.md) for the current project",
    parameters: {
      type: "object",
      properties: {},
    },
    async execute(_toolCallId, _params, _signal, onUpdate, ctx) {
      onUpdate?.({
        content: [{ type: "text", text: "Loading project context..." }],
      });

      const context = loadProjectContext(ctx.cwd);

      if (!context.loaded) {
        return {
          content: [
            {
              type: "text",
              text: "No project context files found in current directory",
            },
          ],
          details: { cwd: ctx.cwd },
        };
      }

      const sections: string[] = [];

      for (const [filename, content] of context.files) {
        sections.push(`# ${filename}\n\n${content}`);
      }

      const message = sections.join("\n\n---\n\n");

      return {
        content: [{ type: "text", text: message }],
        details: {
          cwd: ctx.cwd,
          files: Array.from(context.files.keys()),
        },
      };
    },
  });
}
