# skills

Curated, operator-tested instructions for AI coding agents — Claude Code, Pi, and OpenAI Codex.

Each subdirectory is a *skill*: a small, focused markdown document that an agent harness loads on demand to handle a specific task domain (provisioning AWS, porting C to Rust, running pgbench on bare-metal NUMA hardware, reviewing a diff, etc.). Skills are invoked through the host agent's slash-command mechanism — `/skill:<name>` in Claude/Pi, `/<name>` in Codex — and they fold operator-vetted procedure into the agent's context for the duration of one task.

This is a community starting point, not gospel. Fork it, prune what you don't need, contribute back what you wish someone had given you when you started.

## Status

- 26 skills (AWS, Rust, porting, workflow, domain).
- Cross-tool: Claude Code, Pi, Codex (Codex translations live under `codex/`).
- Maintainer: Greg Burd (`gregburd`).
- License: TBD — flag for fork-time decision; treat as "operator-internal" until set.

## How skills work

A skill is a directory. The directory contains at minimum a `SKILL.md` with a YAML frontmatter for Claude/Pi:

```yaml
---
name: my-skill
description: One-line description that matches when the agent should load this skill.
---

# My Skill — heading

Procedure, code samples, gotchas, references.
```

The *description* matters: agent harnesses match it against the user's request to decide whether to surface the skill. Write it so the trigger conditions are unambiguous — verbs and concrete domains, not vague aspirations.

Loading mechanisms differ per host:

| Agent       | Discovery path                       | Invocation                  |
|-------------|--------------------------------------|-----------------------------|
| Claude Code | `~/.claude/skills/` or repo path     | `/skill:<name>`             |
| Pi          | `skills` setting (defaults to `~/.kiro/skills/`) | `/skill:<name>` |
| Codex       | `~/.codex/prompts/<name>.md`         | `/<name>`                   |

Skills can reference other skills (`/skill:<other>`), files in the host harness, MCP tools, or external docs — they are plain markdown, so anything Markdown-renderable is fair game.

For Codex, the translations under `codex/<name>/SKILL.md` are flat prompt files (no YAML frontmatter, since Codex doesn't parse it). See `codex/README.md` for the install procedure.

## Skill catalogue

### AWS
| Skill                | What it does |
|----------------------|--------------|
| `aws-ec2-lifecycle`  | Spin up / connect / collect / terminate test EC2 instances. Tags, spot, multi-region. |
| `aws-isengard-auth`  | Refresh Isengard credentials via `ada`. Multi-account / multi-region. |
| `aws-rds-aurora`     | Create and manage RDS / Aurora clusters; parameter groups; snapshots. |
| `aws-s3-ops`         | Bucket ops, lifecycle policies, cross-account access, sync patterns. |
| `aws-serverless`     | Deploy Lambda / API Gateway / Step Functions via raw CLI (no CDK). |
| `aws-terraform`      | Terraform with Isengard credentials, S3+DynamoDB state backend, modules. |

### Rust
| Skill                  | What it does |
|------------------------|--------------|
| `rust-async`           | tokio: async/await, tasks, channels, shared state, graceful shutdown. |
| `rust-error-handling`  | `Result`, `Option`, `thiserror`, `anyhow`, `?`, error conversion. |
| `rust-idiomatic`       | Newtypes, methods over functions, enums over booleans, iterators, two-layer C-compatible APIs. |
| `rust-ownership`       | Move / borrow / lifetimes, smart pointers, interior mutability, `Pin`, `Cow`, RAII. |
| `rust-testing`         | Unit / integration / doc tests, `proptest`, `criterion`, `mockall`, fuzzing, snapshots. |
| `rust-traits`          | Associated types, generics, trait objects, derive macros, sealed traits, `From`/`Into`. |

### Porting & code transformation
| Skill                  | What it does |
|------------------------|--------------|
| `c-to-rust`            | Faithful C-to-Rust ports: pointers→references, macros→fns, error handling, verification checklist. |
| `flex-bison-to-lime`   | Port flex+bison parser/scanner pairs to the Lime parser generator. Distilled from porting 12 PostgreSQL grammars (~36k lines). |
| `coccinelle`           | Semantic patching for C/C++ via `spatch`. Pre-defined rules: null-checks, error-handling, leaks, dead code. |

### Workflow & meta
| Skill              | What it does |
|--------------------|--------------|
| `btw`              | Quick aside without derailing the current task. |
| `checkpoint`       | Summarize progress / blockers between tasks or before context overflow. |
| `dream`            | Brainstorm an architecture without writing code. |
| `maintain-docs`    | Audit and update `AGENTS.md` / `CLAUDE.md` against actual project state. |
| `memelord-init`    | Initialize memelord persistent memory in a new project. |
| `review-diff`      | Review a git diff for regressions, style, complexity, security. |
| `think-hard`       | Deep-analysis mode for complex bugs / design decisions. |
| `watchdog`         | Periodic project health check (build, tests, lint, format, drift). |

### Domain
| Skill                | What it does |
|----------------------|--------------|
| `hegel`              | Property-based tests using Hegel across Rust, C, C++, Go, TypeScript. |
| `pg-numa-benchmark`  | Run PostgreSQL clock-sweep benchmarks on bare-metal EC2 (r8i.metal, m6i.metal). |
| `postgresq`          | Research the PostgreSQL community via the `agora` MCP server (76k+ mailing-list messages, code intel, commit archaeology). |

## MCP servers in active use

The operator runs nine MCP servers that these skills (and the agents loading them) consult during PostgreSQL development. They are independent — install whichever you actually need. The canonical configuration lives in `nix-config/modules/home-manager/ai/mcps.nix`; the snippets below are the equivalent hand-installs.

For Codex users, paste-ready blocks for all nine are in `codex/mcp_servers.toml`; servers requiring credentials are shipped commented-out with `enabled = false` so `install.sh` does not break on first run.

### memelord — persistent memory across sessions
- **Source:** https://github.com/earendil-works/memelord
- **Transport:** stdio
- **Purpose:** Per-project notebook the agent reads at session start and writes to throughout. Cross-session lessons survive between conversations — "pg_search BM25 fails on replica", "agora SSH facade on port 22", which patch landed and which did not — preserved across sessions, agents, and machines.
- **When to use for PG dev:** every long-running PostgreSQL task. Lessons learned reviewing one patch get reused when reviewing the next; gotchas about a benchmark host survive instance restarts.
- **Install (Pi):** `memelord-mcp` extension in `~/.pi/agent/extensions/`.
- **Install (Claude Code):** stdio entry in `~/.claude.json` `mcpServers`, plus `SessionStart` / `PostToolUse` / `Stop` / `SessionEnd` hooks in `~/.claude/settings.json`. See the `memelord-init` skill.
- **Install (Codex):**

  ```toml
  [mcp_servers.memelord]
  command = "node"
  args = ["/home/<you>/.npm-global/bin/memelord", "serve"]
  env = { MEMELORD_DIR = "/home/<you>/.memelord" }
  enabled = true
  ```

### postgresq — PostgreSQL community + git + code intel (the agora server)
- **Source:** https://codeberg.org/postgresq/agora (publicly hosted at https://postgr.esq/)
- **Transport:** SSE (HTTP)
- **Endpoint:** `https://postgr.esq/mcp/`
- **Purpose:** 108-tool MCP exposing the entire pgsql-hackers archive (188k+ messages, JWZ-threaded), 28 git repos with code intelligence (165k+ symbols across UCB POSTGRES historical and modern trees), commitfest entries, build-farm runs, the wiki, and 1837 wiki pages. Primary tool for PG community research.
- **When to use for PG dev:** any time the question "why was this designed this way?", "who else has hit this?", "what does the buildfarm say?", or "who calls this function?" comes up. Replaces hours of `git log -S` / archive-grepping.
- **Install (Pi):** `agora-mcp` extension in `~/.pi/agent/extensions/`.
- **Install (Claude Code):**

  ```json
  "postgresq": { "type": "http", "url": "https://postgr.esq/mcp/" }
  ```

- **Install (Codex):**

  ```toml
  [mcp_servers.postgresq]
  url = "https://postgr.esq/mcp/"
  transport = "sse"
  enabled = true
  ```

### github — read-only GitHub repos and issues
- **Source:** `github-mcp-server` (binary; authenticated via `gh auth token`)
- **Transport:** stdio
- **Purpose:** Browse GitHub repos and issues without leaving the agent. The Postgres org has many adjacent repos (`psycopg/psycopg`, `postgrespro/postgres`, `supabase/postgres`, extension vendors), and this server gives the agent a uniform read interface. Dynamic toolsets: tools register only for the repos you actually fetch.
- **When to use for PG dev:** triaging an issue against a downstream fork, comparing extension implementations across vendors, fetching a referenced PR's diff without leaving the conversation.
- **Install (Pi):** stdio entry pointing at the `github-mcp-server` binary; export `GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token)` first.
- **Install (Claude Code):** same stdio entry in `~/.claude.json`.
- **Install (Codex):**

  ```toml
  [mcp_servers.github]
  command = "/path/to/github-mcp-server"
  args = ["stdio", "--dynamic-toolsets", "--read-only"]
  # Set GITHUB_PERSONAL_ACCESS_TOKEN in your shell or env block.
  enabled = false  # requires `gh auth login` first
  ```

### filesystem — sandboxed local file access
- **Source:** `@modelcontextprotocol/server-filesystem`
- **Transport:** stdio
- **Purpose:** Constrain agent file I/O to a configured root. Useful when an agent needs to inspect a checkout, a patch series, or a benchmarking results directory without granting it free reign over `$HOME`.
- **When to use for PG dev:** inspecting a patched PostgreSQL tree, applying or reading `.patch` files, walking a benchmark results dump.
- **Install (Pi):** stdio entry, `args = ["-y", "@modelcontextprotocol/server-filesystem", "<root>"]`.
- **Install (Claude Code):** same stdio entry in `~/.claude.json`.
- **Install (Codex):**

  ```toml
  [mcp_servers.filesystem]
  command = "npx"
  args = ["-y", "@modelcontextprotocol/server-filesystem", "/home/<you>"]
  enabled = true
  ```

### server-memory — knowledge-graph persistent memory
- **Source:** `@modelcontextprotocol/server-memory`
- **Transport:** stdio
- **Purpose:** A *different* persistence mechanism from memelord — structured knowledge-graph (entities, relations, observations) rather than freeform notes. Useful when the agent needs structured fact-recall across a single long session.
- **When to use for PG dev:** complex multi-hop deduction over a single review pass — "this function calls that, which is held in tension with this MR, which contradicts that thread on -hackers". Within one session it builds and traverses the graph; memelord is the cross-session counterpart.
- **Install (Pi):** stdio entry, `args = ["-y", "@modelcontextprotocol/server-memory"]`.
- **Install (Claude Code):** same stdio entry in `~/.claude.json` (key: `memory`).
- **Install (Codex):**

  ```toml
  [mcp_servers.memory]
  command = "npx"
  args = ["-y", "@modelcontextprotocol/server-memory"]
  enabled = true
  ```

### server-git — local Git operations
- **Source:** `mcp-server-git` (official MCP, Python; via `uvx`)
- **Transport:** stdio
- **Purpose:** `log`, `diff`, `blame`, `show`, branch/tree inspection on a *local* checkout. Distinct from the `github` server (remote) and from `postgresq` (curated PG repos with code intel).
- **When to use for PG dev:** archaeology on a local PostgreSQL tree — bisecting in your head, blaming a hunk, walking a patch series across rebases.
- **Install (Pi):** stdio entry, `args = ["--from", "mcp-server-git", "mcp-server-git"]` via `uvx`.
- **Install (Claude Code):** same stdio entry in `~/.claude.json` (key: `git`).
- **Install (Codex):**

  ```toml
  [mcp_servers.git]
  command = "uvx"
  args = ["--from", "mcp-server-git", "mcp-server-git"]
  enabled = true
  ```

### context7 — version-aware library docs (Upstash)
- **Source:** `@upstash/context7-mcp`
- **Transport:** stdio
- **Purpose:** Live library documentation lookup *for the version pinned in your project*. Resolves the long-standing failure mode where an agent cites a library API that no longer exists or never existed in your version.
- **When to use for PG dev:** any time you touch a third-party library — psycopg3, asyncpg, sqlalchemy, libpq bindings, a Rust crate wrapping libpq. Pull the docs the project actually uses, not whatever version the LLM trained on.
- **Install (Pi):** stdio entry, `args = ["-y", "@upstash/context7-mcp@latest"]`.
- **Install (Claude Code):** same stdio entry in `~/.claude.json`.
- **Install (Codex):**

  ```toml
  [mcp_servers.context7]
  command = "npx"
  args = ["-y", "@upstash/context7-mcp@latest"]
  enabled = true
  ```

### sequential-thinking — structured multi-step reasoning
- **Source:** `@modelcontextprotocol/server-sequential-thinking`
- **Transport:** stdio
- **Purpose:** A reasoning scaffold the agent calls out to when a problem benefits from explicit step-by-step deduction with revision. Externalises the chain of thought so it can be revised mid-stream rather than written-and-forgotten.
- **When to use for PG dev:** complex internals deduction — "trace WAL replay through pg_tre's pending-merge phase", "reason about lock interactions between CONCURRENTLY index build and a parallel VACUUM", anything where a single forward pass produces hand-wavy nonsense.
- **Install (Pi):** stdio entry, `args = ["-y", "@modelcontextprotocol/server-sequential-thinking"]`.
- **Install (Claude Code):** same stdio entry in `~/.claude.json`.
- **Install (Codex):**

  ```toml
  [mcp_servers.sequential-thinking]
  command = "npx"
  args = ["-y", "@modelcontextprotocol/server-sequential-thinking"]
  enabled = true
  ```

### llms-docs — `mcpdoc` wrappers for `llms.txt` sources
- **Source:** `mcpdoc` (via `uvx`)
- **Transport:** stdio
- **Purpose:** Each entry in this group wraps an `llms.txt` URL — PostgreSQL official docs, pgsql-hackers archive renders, vendor docs — and exposes them as a fetchable resource. The agent gets authoritative text on demand, *per project*, configured by the operator.
- **When to use for PG dev:** quoting the canonical PostgreSQL docs verbatim, fetching the latest `pg_hba.conf` reference, citing a -hackers thread by URL. Anything where you want the source-of-truth text rather than the model's recollection.
- **Install (Pi):** one stdio entry per source, each invoking `uvx --from mcpdoc mcpdoc --urls "<title>:<url>" --transport stdio`.
- **Install (Claude Code):** same per-source stdio entries in `~/.claude.json`.
- **Install (Codex):**

  ```toml
  [mcp_servers.pg-docs]
  command = "uvx"
  args = ["--from", "mcpdoc", "mcpdoc", "--urls", "PostgreSQL:https://www.postgresql.org/llms.txt", "--transport", "stdio"]
  enabled = false  # configure your own llms.txt sources
  ```

These are the operator's curated servers; the broader MCP ecosystem has many more. Forks and additions welcome.

## Engineering standards

The non-negotiables. Every skill in this repo, and every change to this repo, must comply.

### Voice & stance

- Lead with the strongest counterargument before agreeing. No sycophancy ("great question", "you're absolutely right" — banned).
- Accuracy is the success metric, not user approval. Disagree without apology when the reasoning holds.
- State explicit confidence levels: high / moderate / low / unknown.
- Don't anchor on user-supplied numbers; produce your own estimate first.
- Negative conclusions and bad news are fine. Don't soften.
- If you don't know, say so. Never fabricate facts, citations, names, dates, or examples.

### Hard limits

1. ≤100 lines per function; cyclomatic complexity ≤8.
2. ≤5 positional parameters.
3. 100-character line length.
4. Absolute imports only — no relative `..` paths.
5. Google-style docstrings on non-trivial public APIs.

### Zero-warnings policy

Fix every warning from every linter, type checker, compiler, and test. If a warning genuinely cannot be fixed, add an inline ignore *with* a justification comment. "I'll get to it later" is not a justification.

### Error handling

- Fail fast with clear, actionable messages.
- Never swallow exceptions silently.
- Include context: what operation, what input, what the caller can do about it.

### Testing

- **Test behaviour, not implementation.** A refactor that breaks tests but not behaviour means the tests were wrong.
- **Test edges and errors.** Empty inputs, boundaries, malformed data, missing files, network failures — not just the happy path.
- **Mock boundaries, not logic.** Mock only what is slow, non-deterministic, or external.
- **Verify tests fail.** Break the code, confirm the test fails, revert. Tests that never fail are decoration.

### Commits & git safety

- Imperative mood, ≤72-char subject, one logical change per commit.
- **Never** force push, **never** rewrite history that has been pushed, **never** amend pushed commits.
- `git add` paths explicitly — no `git add .`, `-A`, `-u`, or `*`.
- Never commit secrets, API keys, credentials, or AI-collaboration footers (`Co-Authored-By: Claude/Pi/Codex`, "Generated with assistance from …", 🤖). Author is the human; message describes the change.
- Use `-P` on git commands that paginate.

### Tool preferences

| Use            | Not          | Why |
|----------------|--------------|-----|
| `rg`           | `grep`       | 10× faster, gitignore-aware. |
| `fd`           | `find`       | Fast, ergonomic. |
| `ast-grep`     | regex        | Structural code search at AST level. |
| `shellcheck` + `shfmt` | unchecked shell | Catches the foot-guns. |
| `trash`        | `rm -rf`     | Recoverable. **`rm -rf` is banned by hook in this operator's setup.** |

For long-running build/test sessions: prefer `/scratch` to `/tmp` (tmpfs OOMs); export `TMPDIR` and `CARGO_TARGET_DIR` accordingly.

## Multi-reviewer requirement

**Every change to this repo passes through 2–3 reviewer passes before merge.** A reviewer is a separate agent invocation (or a human) tasked specifically with adversarial review — not the same agent that wrote the code.

Why: a single-author / single-reviewer pipeline produces blind spots. Two or three reviewers, ideally with different prompt framings (e.g. "find regressions", "find security issues", "verify spec alignment"), surface what one would miss.

The `review-diff` skill is the canonical reviewer entry point. Reuse this prompt template for each pass:

```
You are reviewing a git diff for a change to the skills.git repo.

Inputs:
- Diff: <paste the full diff or `git -P diff <base>..<head>`>
- Spec / task description: <what was the change supposed to do?>
- Engineering standards: ./README.md ("Engineering standards" section)

Do, in order:

1. Read the spec. Restate it in one sentence.
2. Read the diff. List every file touched.
3. For each file, answer:
   - Does this change do what the spec says?
   - Does it introduce regressions in adjacent code?
   - Are tests added or updated to cover the new behaviour?
   - Does it violate any hard limit (function length, complexity, params)?
   - Does it leak secrets, embed credentials, or add an AI-collab footer?
   - Are there stubs, TODOs, FIXMEs, `unimplemented!()`, `panic!("not implemented")`,
     or empty handlers?
4. Rate the change: APPROVE / REQUEST_CHANGES / BLOCK. Justify.
5. List concrete, file:line-level fix requests if not APPROVE.

Be adversarial. Lead with the strongest objection. Do not soften criticism.
```

Run this prompt at least twice — different reviewer agents, different framings — before merging. For non-trivial changes (new skills, restructuring, anything touching engineering standards) require three.

## Agent self-review for accuracy

Separate from peer review, **agents must self-review their own work mid-task**. After producing any non-trivial output, the agent stops and asks:

> Is what I just wrote actually doing what was specified? Read the spec; read the code/doc; compare; document the alignment or surface the gap.

This is an integrity check, not a quality gloss. It catches the class of failure where an agent confidently produces output that *looks* right but answers a question that wasn't asked, or implements 80% of the spec and silently drops 20%.

Worked example: an agent asked to "add a `--dry-run` flag to the deploy script" might add the flag *and the help text*, then commit. Self-review: "Does my code actually skip the side-effecting calls when `--dry-run` is set, or did I only add the flag plumbing?" — a non-trivial fraction of the time the answer is *only the plumbing*.

A good self-review is short:

```
SELF-REVIEW
- Spec: <one sentence>
- What I produced: <one sentence>
- Alignment: full / partial / divergent
- Gaps: <bullet list, or "none">
- Action: ship / revise / surface to user
```

Append it to the agent's reply or write it to `.agent/notes/self-review-<timestamp>.md`. Do not skip it for "small" changes — the small changes are where the silent drift compounds.

## No stubs, no TODOs, no `unimplemented`

A change either lands working or it does not land. Banned in any committed code:

- `// TODO`, `// FIXME`, `// XXX`, `// HACK`
- `unimplemented!()`, `todo!()`, `panic!("not implemented")`, `panic!("TODO …")`
- Empty function bodies, no-op handlers, placeholder return values (`return null;`, `return None;` *as a stand-in*, etc.)
- Dummy classes, stub modules, "we'll fill this in later" tests
- `pass` (Python) / empty `{}` (JS/Go/Rust) when the function is supposed to do work

This is a *completeness* rule, not a *perfectionism* rule. Code MAY have known limitations — document them as `Limitations:` in the docstring or in a `LIMITATIONS.md` — but it MUST work for its stated scope.

If a feature can't land in one pass, that's fine: keep it on a feature branch until it does. "Working but partial" merged to mainline is the worst of both worlds.

Before declaring a task done, run:

```bash
rg -i 'TODO|FIXME|XXX|HACK|unimplemented|todo!|panic!\("not implemented' --type-not md
rg -l 'pass$' -t py | xargs -r rg -nC2 'def .*:\s*pass'   # Python stubs
ast-grep --pattern 'fn $F($$$) { }' --lang rust            # empty Rust fns
ast-grep --pattern 'fn $F($$$) -> $T { unimplemented!() }' --lang rust
```

If those return anything that wasn't intentional, fix or back out before committing.

## Codex support

OpenAI Codex doesn't have `/skill:` natively. It does have:

1. `~/.codex/config.toml` for MCP servers (TOML, `[mcp_servers.<name>]` blocks).
2. `~/.codex/prompts/<name>.md` — markdown prompt files invoked as `/<name>` slash commands.
3. `AGENTS.md` at project roots, read natively.

Each skill in this repo has a Codex-native equivalent under `codex/<skill-name>/SKILL.md`. To install:

```bash
cd codex && ./install.sh        # symlinks each codex/<name>/SKILL.md to ~/.codex/prompts/<name>.md
```

To wire up the MCP servers, paste `codex/mcp_servers.toml` into your `~/.codex/config.toml`. See `codex/README.md` for the long form.

## Contributing

This repo is a starting point, not a finished product. PRs welcome.

### Workflow

1. **Fork** to your own account on the canonical host (codeberg or github — currently TBD; check `git remote -v`).
2. **Branch:** `feat/<skill-name>` for new skills, `fix/<skill-name>` for fixes.
3. **Write** the skill: directory under the repo root with `SKILL.md` (YAML frontmatter `name` + `description`, then content). For Codex, mirror under `codex/<name>/SKILL.md` (no frontmatter; Codex-friendly framing).
4. **Comply** with the engineering standards above. Self-review before pushing.
5. **PR** with a clear description: what the skill does, when it triggers, why it's worth its own skill rather than a paragraph in an existing one.
6. **Review:** 2–3 reviewers pass before merge (use the template in "Multi-reviewer requirement"). Maintainer (Greg Burd) does the final pass.

### What makes a good skill

- **Narrow.** One domain, one mental model. If the description needs three "and" clauses, split it.
- **Operator-tested.** Don't propose skills you haven't actually used.
- **Concrete.** Code samples, real commands, real flags. Not "consider using `aws ec2 …`" but the exact invocation.
- **Boundaries explicit.** "Use when X. Don't use when Y."
- **Cross-references over copy-paste.** If `aws-isengard-auth` already covers credentials, don't redo it inline — link.

### What makes a bad skill

- Reformulations of agent / model documentation.
- "How to write good code" generalities.
- Skills whose entire content fits on a sticky note (fold them into a related skill).
- Skills that depend on closed-source / Amazon-internal tooling without saying so up front.

## Repo layout

```
.
├── README.md                       (this file)
├── <skill-name>/
│   └── SKILL.md
│   └── (optional) references/, examples/, *.backup
├── codex/
│   ├── README.md                   how to install Codex prompts + MCP
│   ├── install.sh                  symlink each codex/<name>/SKILL.md to ~/.codex/prompts/<name>.md
│   ├── mcp_servers.toml            paste-into-config snippets for the nine MCP servers
│   └── <skill-name>/
│       └── SKILL.md                Codex-native (no frontmatter)
└── (operator-local notes — not committed unless explicitly added)
```

The 27 skill directories are listed in the catalogue above.

## Open items

These need operator decisions before this repo can be cut public:

1. **Canonical remote URL.** The local checkout currently has no remote. Pick host (codeberg recommended for the postgr.esq alignment) and `git remote add origin <url>`.
2. **Licence.** No `LICENSE` file yet. Pick one (MIT, Apache-2.0, CC-BY-SA-4.0 for the prose, or dual). Add it before first push.
3. **`.local-gitignore` / per-clone state.** Skills directories may accumulate `*.backup` files, `references/` symlinks, and operator notebooks. The `.local-gitignore` mechanism (per the workflow steering) handles this; verify it's set up before pushing.
