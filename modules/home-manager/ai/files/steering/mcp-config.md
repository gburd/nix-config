# MCP Server Selection Guide

## When to Use Each Server

### postgresq — PostgreSQL Institutional Memory
**Use when** the question is about PostgreSQL *development*, not *usage*:
- "Why was X implemented this way?" → search pgsql-hackers for the design thread
- "Has anyone proposed Y before?" → find prior art before writing a patch
- "What did reviewers object to in this area?" → find review threads for similar patches
- "How did feature Z evolve?" → git_log + find_related_discussions
- "What's the community convention for X?" → community coding conventions
- Symbol lookup in PostgreSQL source (BufferDesc, WAL internals, executor nodes)
- Connecting commits to the mailing list threads that motivated them

**Do NOT use for**: running SQL queries, reading your own extensions (ra, pg_dyn), current PostgreSQL docs (use context7), GitHub PRs/issues (use github MCP).

### context7 — Live Library Documentation
**Use when** you need current API docs for any library, framework, or crate:
- Rust crate APIs (tokio, serde, crossbeam, parking_lot)
- Python package docs
- Any fast-moving library where training data may be stale

**Do NOT use for**: PostgreSQL internals (use postgresq), general concepts, business logic.

### github — GitHub Platform Operations
**Use when** working with GitHub-hosted repos:
- PR reviews, issue search, code search across GitHub
- Finding similar implementations in open source

**Do NOT use for**: local git operations (use git MCP), non-GitHub repos.

### git — Local Repository Operations  
**Use when** you need git operations on local repos:
- Diff, log, blame, branch operations on ~/ws/* projects
- Works on repos not hosted on GitHub (aether, dbsql, openldap)

### agent-memory — Shared Persistent Memory (all agents, all hosts)
**Use when** you need to store or retrieve knowledge across sessions:
- Corrections, user-stated facts and grants, codebase insights
- Project architecture decisions and known blockers

One mcp-memory-service on meh (`http://meh.ts.burd.me:8765`, tailnet only),
shared by pi, Claude Code, kiro and maki on every host. `memory_search` to
recall, `memory_store` to save (tag it `project:<path under ~>` plus
`kind:correction|user|insight`), `memory_update` / `memory_delete` to fix a
wrong one. A session-start hook injects the project's newest memories.
It replaced memelord on 2026-10-29; all 2602 unique memelord memories were
imported, tagged `origin:memelord`.

**The old `.memelord/` directories are a read-only archive.** Never open
`.memelord/memory.db` with stock SQLite (the `sqlite3` CLI, Python's
`sqlite3`, DB Browser, `datasette`): it is Turso, whose WAL is indexed by
`memory.db-tshm`, and a stock-SQLite read can truncate `memory.db-wal` while
`-tshm` still points into it, breaking the file for memelord. To read one,
copy the `.memelord/` directory elsewhere and open the copy with memelord's
own engine.

### sequential-thinking — Structured Reasoning
**Use when** facing complex architectural decisions:
- Buffer manager design trade-offs
- Multi-crate dependency planning
- Recovery algorithm correctness reasoning

### filesystem — File System Access
General-purpose file reading/writing. Prefer built-in Read/Write tools when available.

### llms-docs (nix, home-manager, rust, python)
**Use when** you need official documentation for these specific ecosystems. These serve llms.txt files optimized for LLM consumption.

## Decision Flow

1. **PostgreSQL internals/community question** → postgresq
2. **Library/crate API docs** → context7
3. **GitHub repo operation** → github MCP
4. **Local git repo operation** → git MCP
5. **Store/recall knowledge across sessions** → agent-memory
6. **Complex multi-step reasoning** → sequential-thinking
7. **Nix/Rust/Python official docs** → llms-docs wrappers
