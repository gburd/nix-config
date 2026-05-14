/**
 * Coccinelle Extension for Pi
 *
 * Semantic patching tool for C/C++ (and experimentally Rust).
 * Enables language-aware large-scale code transformations.
 *
 * Coccinelle uses Semantic Patch Language (SmPL) to describe code patterns
 * and transformations. Unlike text-based tools, it understands C syntax and
 * control flow.
 *
 * See: https://coccinelle.gitlabpages.inria.fr/website/
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { writeFileSync, readFileSync, mkdirSync, existsSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { Type } from "typebox";
import { StringEnum } from "@mariozechner/pi-ai";

export default async function (pi: ExtensionAPI) {
  const COCCI_DIR = ".coccinelle";

  // Ensure .coccinelle directory exists
  const ensureCocciDir = (cwd: string): string => {
    const dir = join(cwd, COCCI_DIR);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    return dir;
  };

  // Execute spatch command
  const runSpatch = async (
    args: string[],
    cwd: string,
  ): Promise<{ stdout: string; stderr: string; exitCode: number }> => {
    try {
      const result = await pi.exec("spatch", args, { cwd });
      return {
        stdout: result.stdout || "",
        stderr: result.stderr || "",
        exitCode: result.exitCode || 0,
      };
    } catch (err: any) {
      return {
        stdout: err.stdout || "",
        stderr: err.stderr || String(err),
        exitCode: err.exitCode || 1,
      };
    }
  };

  // Tool: Apply semantic patch
  pi.registerTool({
    name: "coccinelle_patch",
    label: "Coccinelle: Apply Semantic Patch",
    description:
      "Apply a Coccinelle semantic patch (SmPL) to C/C++ source files. " +
      "SmPL describes code patterns to match and transformations to apply. " +
      "Use --dry-run to preview changes before applying.",
    parameters: Type.Object({
      patch: Type.String({
        description:
          "SmPL patch script. Example: '@@\\n@@\\n-if (x == NULL)\\n+if (!x)'",
      }),
      files: Type.Array(Type.String(), {
        description: "Files or directories to process (C/C++ source)",
      }),
      dry_run: Type.Optional(
        Type.Boolean({
          description: "Show diff without modifying files (default: true)",
          default: true,
        }),
      ),
      include_headers: Type.Optional(
        Type.Boolean({
          description: "Process header files (.h) as well",
          default: false,
        }),
      ),
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const { patch, files, dry_run = true, include_headers = false } = params;

      onUpdate?.({
        content: [
          {
            type: "text",
            text: `Applying semantic patch to ${files.length} target(s)...`,
          },
        ],
      });

      const cocciDir = ensureCocciDir(ctx.cwd);
      const patchFile = join(cocciDir, `patch-${Date.now()}.cocci`);

      try {
        // Write patch to file
        writeFileSync(patchFile, patch, "utf-8");

        // Build spatch arguments
        const args = ["--sp-file", patchFile];

        // Add targets
        for (const file of files) {
          args.push("--dir", file);
        }

        // Options
        if (dry_run) {
          args.push("--parse-cocci"); // Just parse, don't apply
        } else {
          args.push("--in-place"); // Modify files in place
        }

        if (!include_headers) {
          args.push("--include-headers-for-types"); // Only include headers for type info
        }

        args.push("--very-quiet"); // Reduce output noise

        // Run spatch
        const result = await runSpatch(args, ctx.cwd);

        // Clean up patch file
        unlinkSync(patchFile);

        if (result.exitCode !== 0) {
          return {
            content: [
              {
                type: "text",
                text: `Coccinelle failed:\n${result.stderr}`,
              },
            ],
            isError: true,
          };
        }

        const output = result.stdout || result.stderr;

        if (dry_run) {
          return {
            content: [
              {
                type: "text",
                text: `# Preview (dry-run)\n\n${output}\n\nUse dry_run=false to apply changes.`,
              },
            ],
            details: { dry_run: true, output },
          };
        } else {
          return {
            content: [
              {
                type: "text",
                text: `# Changes Applied\n\n${output}`,
              },
            ],
            details: { dry_run: false, output },
          };
        }
      } catch (err) {
        // Clean up patch file if it exists
        if (existsSync(patchFile)) {
          unlinkSync(patchFile);
        }

        return {
          content: [
            {
              type: "text",
              text: `Error: ${err instanceof Error ? err.message : String(err)}`,
            },
          ],
          isError: true,
        };
      }
    },
  });

  // Tool: Apply common refactoring patterns
  pi.registerTool({
    name: "coccinelle_refactor",
    label: "Coccinelle: Common Refactorings",
    description:
      "Apply common C/C++ refactoring patterns using pre-defined templates",
    parameters: Type.Object({
      pattern: StringEnum([
        "null-checks",
        "error-handling",
        "memory-leaks",
        "resource-leaks",
        "dead-code",
        "simplify-conditionals",
        "const-correctness",
      ] as const, {
        description:
          "Refactoring pattern: null-checks (if(x==NULL)->if(!x)), " +
          "error-handling (add NULL checks), memory-leaks (find missing free()), " +
          "resource-leaks (find missing close/fclose), dead-code (remove unreachable), " +
          "simplify-conditionals (if(x==true)->if(x)), const-correctness (add const)",
      }),
      files: Type.Array(Type.String(), {
        description: "Files or directories to process",
      }),
      dry_run: Type.Optional(
        Type.Boolean({ description: "Preview changes only", default: true }),
      ),
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const { pattern, files, dry_run = true } = params;

      onUpdate?.({
        content: [
          { type: "text", text: `Applying ${pattern} refactoring...` },
        ],
      });

      // Pre-defined SmPL patterns
      const patterns: Record<string, string> = {
        "null-checks": `
@@
expression E;
@@
- if (E == NULL)
+ if (!E)

@@
expression E;
@@
- if (E != NULL)
+ if (E)
`,
        "error-handling": `
@@
expression E;
@@
E = malloc(...);
+ if (!E) {
+   return -ENOMEM;
+ }
`,
        "memory-leaks": `
// Find malloc without corresponding free
@@
expression E;
@@
*E = malloc(...);
... when != free(E)
    when != E = ...
return ...;
`,
        "resource-leaks": `
// Find fopen without corresponding fclose
@@
expression F;
@@
*F = fopen(...);
... when != fclose(F)
    when != F = ...
return ...;
`,
        "dead-code": `
@@
@@
- if (0) { ... }

@@
@@
- if (false) { ... }
`,
        "simplify-conditionals": `
@@
expression E;
@@
- if (E == true)
+ if (E)

@@
expression E;
@@
- if (E == false)
+ if (!E)

@@
expression E;
@@
- while (E == true)
+ while (E)
`,
        "const-correctness": `
@@
identifier f;
parameter p;
@@
f(...,
-  p
+  const p
  ,...)
{ ... when != p = ...  }
`,
      };

      const smpl = patterns[pattern];
      if (!smpl) {
        return {
          content: [{ type: "text", text: `Unknown pattern: ${pattern}` }],
          isError: true,
        };
      }

      // Use the patch tool
      return await pi.invokeTool("coccinelle_patch", {
        patch: smpl,
        files,
        dry_run,
      });
    },
  });

  // Tool: Find pattern matches
  pi.registerTool({
    name: "coccinelle_find",
    label: "Coccinelle: Find Pattern",
    description:
      "Find code patterns using SmPL without modifying files. " +
      "Useful for code audits and finding potential bugs.",
    parameters: Type.Object({
      pattern: Type.String({
        description:
          "SmPL pattern to search for. Example: '@@\\nexpression E;\\n@@\\n*E = malloc(...);\\n... when != free(E)'",
      }),
      files: Type.Array(Type.String(), {
        description: "Files or directories to search",
      }),
    }),
    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const { pattern, files } = params;

      onUpdate?.({
        content: [
          { type: "text", text: `Searching for pattern in ${files.length} target(s)...` },
        ],
      });

      const cocciDir = ensureCocciDir(ctx.cwd);
      const patchFile = join(cocciDir, `find-${Date.now()}.cocci`);

      try {
        writeFileSync(patchFile, pattern, "utf-8");

        const args = [
          "--sp-file",
          patchFile,
          "--parse-cocci",
          "--very-quiet",
        ];

        for (const file of files) {
          args.push("--dir", file);
        }

        const result = await runSpatch(args, ctx.cwd);
        unlinkSync(patchFile);

        if (result.exitCode !== 0) {
          return {
            content: [
              {
                type: "text",
                text: `Search failed:\n${result.stderr}`,
              },
            ],
            isError: true,
          };
        }

        const output = result.stdout || result.stderr || "No matches found";

        return {
          content: [{ type: "text", text: `# Matches\n\n${output}` }],
          details: { output },
        };
      } catch (err) {
        if (existsSync(patchFile)) {
          unlinkSync(patchFile);
        }

        return {
          content: [
            {
              type: "text",
              text: `Error: ${err instanceof Error ? err.message : String(err)}`,
            },
          ],
          isError: true,
        };
      }
    },
  });

  // Command: Check if coccinelle is installed
  pi.registerCommand("coccinelle", {
    description: "Check Coccinelle installation and show examples",
    handler: async (_args, ctx) => {
      try {
        const result = await pi.exec("spatch", ["--version"]);
        const version = result.stdout?.trim() || "unknown";

        const lines = [
          "# Coccinelle Status",
          "",
          `**Installed:** ✅ ${version}`,
          "",
          "## Available Tools",
          "",
          "- `coccinelle_patch` - Apply custom semantic patches",
          "- `coccinelle_refactor` - Apply common refactoring patterns",
          "- `coccinelle_find` - Search for code patterns",
          "",
          "## Pre-defined Refactorings",
          "",
          "- **null-checks**: Modernize NULL comparisons (if(x==NULL) -> if(!x))",
          "- **error-handling**: Add missing NULL checks after malloc",
          "- **memory-leaks**: Find malloc without free",
          "- **resource-leaks**: Find fopen without fclose",
          "- **dead-code**: Remove unreachable code (if(0), if(false))",
          "- **simplify-conditionals**: Simplify boolean comparisons",
          "- **const-correctness**: Add const to parameters",
          "",
          "## Example Usage",
          "",
          "```",
          "# Preview null-check refactoring",
          'coccinelle_refactor(pattern="null-checks", files=["src/"], dry_run=true)',
          "",
          "# Apply custom patch",
          'coccinelle_patch(patch="@@ ... @@\\n...", files=["file.c"], dry_run=false)',
          "",
          "# Find potential memory leaks",
          'coccinelle_find(pattern="memory-leaks", files=["src/"])',
          "```",
          "",
          "## SmPL Resources",
          "",
          "- Tutorial: https://coccinelle.gitlabpages.inria.fr/website/sp.html",
          "- Examples: /usr/share/coccinelle/standard.h (if installed)",
        ];

        ctx.ui.notify(lines.join("\n"), "info");
      } catch (err) {
        ctx.ui.notify(
          "⚠️ Coccinelle not installed\n\n" +
            "Install with:\n" +
            "- Debian/Ubuntu: sudo apt-get install coccinelle\n" +
            "- Fedora: sudo dnf install coccinelle\n" +
            "- macOS: brew install coccinelle\n" +
            "- From source: https://coccinelle.gitlabpages.inria.fr/website/download.html",
          "warning",
        );
      }
    },
  });
}
