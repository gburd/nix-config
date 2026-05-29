# PostgreSQL Workflow

This file is required reading for any PostgreSQL-related task — patches, internals questions, performance investigation, design discussion, or extension development. PostgreSQL is the user's primary work domain (≈22.8k topic mentions in chat history); applying this consistently saves substantial time per task.

## Rule of First Resort: Use `postgresq` MCP, Not Manual Search

The `postgresq` MCP server (https://pg.ddx.io/mcp) indexes the entire pgsql-hackers archive (76k+ messages) plus the upstream `master` git history with author/date/thread metadata. Before reaching for `grep`, `rg`, web search, or asking the user for context:

1. **Patch design questions** ("why does X work this way", "has Y been proposed before") → `postgresq` thread search.
2. **Symbol lookup** (`BufferDesc`, `XLogInsert`, executor node X) → `postgresq` symbol+history search.
3. **Reviewer objections in this area** ("what did the community say about lockless approaches") → `postgresq` thread search filtered by reviewer name or subject pattern.
4. **Cross-reference commit ↔ thread** ("what discussion led to commit `abc1234`") → `postgresq` git→list correlation.
5. **Community coding conventions** for a specific area → `postgresq` codified in conventions corpus.

If `postgresq` returns insufficient results, *then* fall back to web search or manual grep. Don't skip the MCP because "it might not have it" — it usually does.

**Do NOT use `postgresq` for:**

- Running SQL queries (use a regular Postgres client)
- Reading the user's own extensions (`ra`, `pg_dyn`, etc.) — those are local code, use file Read/git MCP
- Current end-user PostgreSQL documentation (use `context7` for postgres-the-database-docs)
- GitHub PRs/issues against forks/extensions (use `github` MCP)

## Patch Series Workflow

When the user asks for a patch or patch series targeting upstream PostgreSQL or one of their extensions:

1. **Phase 0 — Context gathering** (before touching code)
   - `postgresq` search for prior threads on the topic. Read the top 3–5.
   - `postgresq` git history for the area being modified — understand recent churn.
   - If the user already has a draft or referenced a commit, `postgresq` it for the original design discussion.

2. **Phase 1 — Design**
   - State the design intent in 2–4 sentences. Surface known trade-offs before writing code.
   - If a similar design was already reviewed and rejected on -hackers, surface the rejection reason and discuss whether it still applies.

3. **Phase 2 — Implementation**
   - Follow PostgreSQL coding conventions: 4-space indent, `PG_TRY/CATCH` for resource cleanup, `ereport()` for errors with `errcode()`, `palloc` not `malloc`, minimal use of `bool`-returning functions.
   - One logical change per commit. Patch series order: prep/refactor commits first, behavior-changing commits last.
   - If you're adding a `GUC`, it goes in `guc_tables.c` and `postgresql.conf.sample` together.

4. **Phase 3 — Testing**
   - Build with `--enable-cassert --enable-debug --enable-tap-tests`.
   - Run the relevant test suite: `make check`, `make installcheck`, the relevant `src/test/regress` group, or the appropriate TAP suite.
   - For buffer manager / WAL / recovery changes: also run `pg_amcheck` or the relevant `pg_isolated` tests.

5. **Phase 4 — Submission**
   - Commit message: present-tense imperative, ≤72 char subject, body explains the *why* not the *what*. Include reproducer if fixing a bug.
   - For -hackers submission: cover letter explains the patch series, lists open questions, references prior threads (`postgresq` link or `[1]` style).
   - For local PR against a fork: use the `github` MCP to open with full context.

## Performance Investigation Workflow

1. **First**: ask the user for the workload shape (read-heavy / write-heavy / mixed, working set size, isolation level). Don't guess.
2. **Reproduce**: a minimal `pgbench` or `psql` script that exhibits the issue. Time it. Get a baseline.
3. **Profile**: `perf record -p <pid>` for CPU; `bpftrace`/`bcc-tools` for syscalls/IO; `pg_stat_statements` for query-level. Use the `pg-numa-benchmark` skill (see `~/.kiro/skills/pg-numa-benchmark/`) when on bare-metal hardware.
4. **Hypothesize then test**: change one variable at a time. Don't combine config changes.

## Concrete Anti-Patterns to Avoid

These have appeared repeatedly in chat history and should not recur:

- **Reaching for `grep` against pgsql-hackers archives** — always use `postgresq` first.
- **Asking the user "what did the community say about X"** — `postgresq` knows; check it first.
- **Implementing a feature without checking prior art** — half the time someone already proposed it; understanding why it stalled saves the same dead-end.
- **Manually reading commit logs to find motivation** — `postgresq` correlates commits to their list threads.
- **Mixing patch series ordering** (behavior + refactor in one commit) — split.
- **Skipping the cassert build** — undefined-behavior bugs only show under cassert.

## When in Doubt

Ask `postgresq` first. If the response is empty or unhelpful, only then fall back to other tools. Document the gap so the corpus can be improved.
