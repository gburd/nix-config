# MCP Server Configuration

## Kiro CLI

MCP servers configured in `~/.kiro/settings/mcp.json`:
- **builder-mcp** — Amazon internal code search, ticketing, wiki, phonetool
- **amzn-mcp** — Amazon internal website reading, code search, search engine

Both are auto-loaded. Check status: `/mcp` in chat or `kiro-cli mcp list`.

## Claude Code

MCP servers configured per-project in `.mcp.json` or globally. Claude Code also has:
- **Exa AI** — preferred web search (per CLAUDE.md: use `mcp__exa__web_search_exa` over `WebSearch`)
- **LSP plugins** — rust-analyzer, clangd, pyright (configured in `~/.claude/plugins/`)

## Differences

| Capability | Claude Code | Kiro CLI |
|-----------|-------------|----------|
| Web search | Exa AI (MCP) | Built-in `web_search` |
| Internal search | N/A (unless MCP added) | builder-mcp, amzn-mcp |
| Code intelligence | rust-analyzer plugin | Built-in `code` tool |
| AWS operations | `use_aws` tool | `use_aws` tool |

## Adding MCP Servers

```bash
# Kiro CLI
kiro-cli mcp add --name <name> --command <cmd> --args <args> --scope global

# Claude Code — add to project .mcp.json or use claude mcp add
```
