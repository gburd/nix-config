/**
 * Context Monitor Extension
 *
 * Provides visibility into context window usage, similar to Claude Code's status line.
 * Shows token usage, cache hit rate, and cost in footer status bar.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface UsageStats {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  totalCost: number;
  cacheHitRate: number;
}

function formatNumber(n: number | null | undefined): string {
  if (n == null || !Number.isFinite(n)) return "0";
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return Math.round(n).toString();
}

function formatCost(cost: number | null | undefined): string {
  if (cost == null || !Number.isFinite(cost)) return "$0";
  if (cost < 0.01) return `$${(cost * 1000).toFixed(2)}m`;
  return `$${cost.toFixed(2)}`;
}

export default function (pi: ExtensionAPI) {
  let stats: UsageStats = {
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    totalCost: 0,
    cacheHitRate: 0,
  };

  function updateStatus(ctx: any): void {
    const usage = ctx.getContextUsage?.();
    if (!usage) return;

    const tokens = Number(usage.tokens);
    const window = Number(usage.contextWindow);
    if (!Number.isFinite(tokens) || !Number.isFinite(window) || window <= 0) return;

    const pct = Math.floor((tokens / window) * 100);
    const bar = buildProgressBar(pct);
    const statusLine = `${bar} ${pct}% · ${formatNumber(tokens)}/${formatNumber(window)} · ${formatCost(stats.totalCost)}`;

    if (stats.cacheHitRate > 0) {
      setStatus(ctx, `${statusLine} · ↻${stats.cacheHitRate.toFixed(0)}%`);
    } else {
      setStatus(ctx, statusLine);
    }
  }

  function buildProgressBar(pct: number): string {
    const width = 10;
    const filled = Math.floor((pct / 100) * width);
    const empty = width - filled;
    return "█".repeat(filled) + "░".repeat(empty);
  }

  function setStatus(ctx: any, text: string): void {
    if (ctx.ui && ctx.ui.setStatus) {
      ctx.ui.setStatus("context", text);
    }
  }

  // Update stats on each message
  pi.on("message_end", async (event, ctx) => {
    if (event.message.role !== "assistant" || !event.message.usage) return;

    const usage = event.message.usage;

    stats.inputTokens += usage.inputTokens || 0;
    stats.outputTokens += usage.outputTokens || 0;
    stats.cacheReadTokens += usage.cacheReadInputTokens || 0;
    stats.cacheWriteTokens += usage.cacheCreationInputTokens || 0;
    stats.totalCost += usage.cost?.total || 0;

    const totalCached = stats.cacheReadTokens + stats.cacheWriteTokens;
    const totalInput = stats.inputTokens + totalCached;
    stats.cacheHitRate = totalInput > 0 ? (stats.cacheReadTokens / totalInput) * 100 : 0;

    updateStatus(ctx);
  });

  // Clear on session start
  pi.on("session_start", async (_event, ctx) => {
    stats = {
      inputTokens: 0,
      outputTokens: 0,
      cacheReadTokens: 0,
      cacheWriteTokens: 0,
      totalCost: 0,
      cacheHitRate: 0,
    };
    updateStatus(ctx);
  });

  // Command to show detailed stats
  pi.registerCommand("usage", {
    description: "Show detailed token usage and cost statistics",
    handler: async (_args, ctx) => {
      const usage = ctx.getContextUsage?.();
      const tokens = Number(usage?.tokens ?? 0);
      const window = Number(usage?.contextWindow ?? 0);
      const pct = window > 0 ? Math.floor((tokens / window) * 100) : 0;

      const lines = [
        "# Context Usage",
        "",
        `**Context Window:** ${formatNumber(tokens)} / ${formatNumber(window)} (${pct}%)`,
        "",
        "# Session Totals",
        "",
        `**Input Tokens:** ${formatNumber(stats.inputTokens)}`,
        `**Output Tokens:** ${formatNumber(stats.outputTokens)}`,
        `**Cache Read:** ${formatNumber(stats.cacheReadTokens)}`,
        `**Cache Write:** ${formatNumber(stats.cacheWriteTokens)}`,
        `**Cache Hit Rate:** ${stats.cacheHitRate.toFixed(1)}%`,
        "",
        `**Total Cost:** ${formatCost(stats.totalCost)}`,
      ];

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  // Register shortcut for quick usage check (changed from ctrl+u to avoid conflict)
  pi.registerShortcut("ctrl+shift+u", {
    description: "Show token usage",
    handler: async (ctx) => {
      const usage = ctx.getContextUsage?.();
      const tokens = Number(usage?.tokens ?? 0);
      const window = Number(usage?.contextWindow ?? 0);
      if (!window) {
        ctx.ui.notify("No usage data available", "info");
        return;
      }

      const pct = Math.floor((tokens / window) * 100);
      ctx.ui.notify(
        `Context: ${pct}% (${formatNumber(tokens)}/${formatNumber(window)})\nCost: ${formatCost(stats.totalCost)} · Cache: ${stats.cacheHitRate.toFixed(0)}%`,
        "info",
      );
    },
  });

  // Tool for LLM to check context usage
  pi.registerTool({
    name: "check_context_usage",
    label: "Check Context Usage",
    description:
      "Check current context window usage and determine if compaction is needed",
    parameters: {
      type: "object",
      properties: {},
    },
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      const usage = ctx.getContextUsage?.();
      const tokens = Number(usage?.tokens ?? NaN);
      const window = Number(usage?.contextWindow ?? NaN);

      if (!Number.isFinite(tokens) || !Number.isFinite(window) || window <= 0) {
        return {
          content: [{ type: "text", text: "No context usage information available" }],
          details: {},
        };
      }

      const pct = Math.floor((tokens / window) * 100);
      const needsCompaction = pct > 80;

      const message = [
        `Context window: ${pct}% used (${formatNumber(tokens)} / ${formatNumber(window)} tokens)`,
        `Session cost: ${formatCost(stats.totalCost)}`,
        `Cache hit rate: ${stats.cacheHitRate.toFixed(1)}%`,
        "",
        needsCompaction
          ? "⚠️  Context window above 80% - compaction recommended"
          : "✅ Context window usage healthy",
      ].join("\n");

      return {
        content: [{ type: "text", text: message }],
        details: {
          contextUsagePercent: pct,
          needsCompaction,
          totalTokens: tokens,
          contextWindow: window,
          sessionCost: stats.totalCost,
          cacheHitRate: stats.cacheHitRate,
        },
      };
    },
  });
}
