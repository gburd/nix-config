# codex/ — Codex-native translations of the skills

OpenAI Codex doesn't have a `/skill:` slash command the way Claude Code and Pi do. It does have:

1. **MCP servers**, configured in `~/.codex/config.toml` under `[mcp_servers.<name>]` blocks.
2. **Custom prompts**, in `~/.codex/prompts/<name>.md`, invoked as `/<name>` slash commands.
3. **AGENTS.md**, read natively from project roots.

This directory mirrors the top-level skill catalogue, retargeted for Codex. Each `codex/<skill-name>/SKILL.md` is a flat prompt file: no YAML frontmatter (Codex doesn't parse it), no Pi/Claude-specific phrasing.

## Install

### Prompts (slash-commands)

```bash
cd codex && ./install.sh
```

This creates `~/.codex/prompts/` if needed and symlinks every `codex/<name>/SKILL.md` to `~/.codex/prompts/<name>.md`. Each becomes a `/<name>` slash command in your Codex session. Re-running the script is idempotent (it skips existing correct symlinks and surfaces conflicts rather than overwriting).

To uninstall, delete the symlinks:

```bash
find ~/.codex/prompts -maxdepth 1 -type l -lname '*/skills/codex/*' -delete
```

### MCP servers

Paste the contents of `codex/mcp_servers.toml` into your `~/.codex/config.toml`. The file documents each server (memelord, agora) and points at the install paths and endpoints. You'll need to:

- For memelord: have `memelord` installed (`npm install -g @earendil-works/memelord`) and pick a per-host or per-project `MEMELORD_DIR`.
- For agora: have a working network path to `https://postgr.esq/mcp/`.

## Why these are different from the originals

The Claude/Pi versions of each skill use:

- YAML frontmatter (`---\nname: …\ndescription: …\n---`) — Claude/Pi parse this; Codex ignores or warns.
- `/skill:<other-skill>` cross-references — Codex slash commands are `/<name>`.
- Occasional references to Pi extensions (`agora-mcp`, `memelord-mcp`) — those don't exist in Codex; the equivalents are MCP servers in `~/.codex/config.toml`.

The Codex translations strip the frontmatter, retarget the cross-references, and drop the Pi/Claude-only sidebars. The procedural content is identical.

## Layout

```
codex/
├── README.md                       (this file)
├── install.sh                      symlink installer
├── mcp_servers.toml                paste-into-config snippet
└── <skill-name>/
    └── SKILL.md                    Codex-native prompt
```
