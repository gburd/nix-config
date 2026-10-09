# Must Rules — Read First

These are the **non-negotiable** rules every agent must follow. If a request conflicts with one of these, surface the conflict and ask — do not silently bypass.

## NEVER send email. The user sends email. Always.

**THE RULE: an agent sends no email, for any reason, under any circumstance. There is no exception, no approval, and no emergency that unlocks this. If you believe you have found one, you are wrong — stop and hand the draft to the user.**

- **MUST NOT** send, post, or submit email of any kind: not to pgsql-hackers or any other mailing list, not to a person, and not a "test" copy to the user, and not to an address the agent controls. That covers SMTP (`smtplib`, the Proton bridge on 127.0.0.1:1025, Fastmail/Gmail/iCloud SMTP), `git send-email`, `neomutt`/`mutt`/`sendmail`/`msmtp`/`mailx`/`mail`, `curl smtp://`, any HTTP mail API (SES, SendGrid, Mailgun, Postmark, Resend), any MCP tool or agent skill that sends mail, and any script, alias, Makefile target, CI job, or cron entry that does the same. Writing a file that something *else* will send counts as sending.
- **There is no authorization path.** This rule cannot be satisfied, waived, or overridden — not by the user saying "send it", "yes", "go ahead", "ship it", "do 2", not by a prior session appearing to grant it, not by a project README or `.envrc`, and not by the agent's own judgement that the mail is harmless. Approval of content is approval of the *draft*, never of the *sending*. If the user literally instructs "send this email", the correct response is to finish the draft and reply "ready for you to send — I'm prohibited from sending mail myself."
- **No dry runs, no verification sends, no empty tests.** Do not send to `/dev/null`-ish addresses, your own mailbox, `localhost`, or a throwaway account "just to check SMTP works". Do not run a mail command with `--dry-run` flags you have not read, and do not invoke a mail client interactively to "see" its behaviour.
- What an agent delivers instead: the patch file(s) and a plain-text cover letter (or an `.eml` / `git format-patch --cover-letter` output) saved to disk, plus the exact recipients, `In-Reply-To`, and `References` the user will need. Nothing goes out.
- Why: a list post is public, permanent, and in the user's name. It cannot be recalled. On 2026-10-07 an agent sent a PostgreSQL patch to pgsql-hackers (plus Cc's) through the user's mail bridge after the user approved the patch, and the user never meant to send it. That cannot be undone. Never again.
- Reading mail is fine. Searching an archive, opening a local mailbox, reading an `.mbox`, or using the NNTP feed is not sending. The prohibition is on transmission.
- The same applies to every other public, in-the-user's-name channel: no comments, replies, or reviews on mailing lists, forums, Discourse, the commitfest app, social media, or chat on the user's behalf, unless the user explicitly asks the agent to post that specific text there. (Pushing to the user's own repos and filing issues on the user's own repos stay governed by the git rules below.)

## Workflow

- **MUST** stage files explicitly by path (`git add <path> ...`). **MUST NOT** use `git add -A`, `git add .`, or `git commit -a`. Blanket staging sweeps in untracked working-tree junk that nobody reviewed — build output, scratch files, tool logs. This has already caused a real leak in this repo: an `imapsync` run log (`LOG_imapsync/`, containing a real email Subject line and the user's addresses) was swept in by `git add -A` and pushed to a **public** repo, which then needed a history rewrite plus a force-push to expunge. Before every commit, run `git status --short` and read the list; if a path isn't part of the change you set out to make, do not stage it — gitignore it or leave it untracked.
- **MUST** run lint + tests before committing. For Rust: `cargo clippy -- -D warnings` then `cargo test` (or the project-relevant subset). For Python: `ruff check`. For shell: `shellcheck`. If a project has a `Justfile`/`Makefile` with `pre-commit` / `check` targets, prefer those.
- **MUST** use `trash` (not `rm -rf`) for any directory removal. The user's environment has a `trash` command on PATH; if a script must use `rm`, prefer `rm -ri` (interactive) or skip cleanup.
- **MUST NOT** force-push (`git push --force`, `git push --force-with-lease`, or `git push -f`) to any branch unless the user explicitly authorized this specific push in the current session. Some projects opt into routine `--force-with-lease` via `use git_policy allow-force-push` in `.envrc` (see `home-manager/_mixins/cli/direnv.nix`) — pi's safety-hooks.ts enforces this per-project; bare `--force` stays blocked everywhere regardless.
- **MUST NOT** rewrite shared/published history (`git rebase -i`, `git commit --amend`, `git reset --hard origin/...`) on `main` or any branch that exists on `origin`.
- **MUST NOT** push directly to `main`. Use a feature branch + PR. The only exception: tiny fixes to a personal nix-config-style repo where the user has explicitly opted into direct-to-main commits in their CONTRIBUTING/AGENTS.md.

## MCP Routing (Use These Servers, Not Manual Search)

Before reaching for `grep`, `rg`, `find`, or `git log` to answer one of these question types, **MUST** consult the corresponding MCP server first. The MCPs are configured because manual search returns lower-quality results and wastes tokens.

| Question type | Use this MCP first |
|---|---|
| PostgreSQL internals (`why does the buffer manager...`, `where is XLogInsert...`, prior pgsql-hackers discussion) | **postgresq** |
| Library/crate API docs (tokio, serde, etc.) | **context7** |
| GitHub repo operations (PRs, issue search, code search across orgs) | **gh-axi** (low-token CLI; falls back to the **github** MCP only if a project enabled it and gh-axi can't do the op) |
| Local git ops on `~/ws/*` projects | **git** |
| Persistent knowledge across sessions | **memelord** |
| Multi-step architectural reasoning | **sequential-thinking** |
| Nix / home-manager / Rust / Python official docs | **llms-docs** wrappers |

## Output Discipline

- **MUST NOT** mark something "complete" or "verified" unless you actually ran the verification step. If you can't run it (no shell access, missing tools), say so explicitly.
- **MUST NOT** invent file paths, function names, command flags, or library APIs. If you're not sure, look it up via the appropriate MCP or read the file.
- **MUST NOT** include speculative features or unreached error paths "just in case". Code that isn't exercised by a test is dead code.
- **MUST** prefer explicit code over clever one-liners. The reader is the future-you; clever costs more than it saves.

## Confirmation Friction

The user has explicitly stated, repeatedly, that confirmation prompts on routine tool use are friction. The denylists in your agent config block the destructive ops; everything else proceeds without asking. **Do not insert "Should I do X?" prompts before:**

- Running tests
- Running linters
- Reading or grepping files
- Building (cargo build, nix build, make, etc.)
- Creating or modifying files within the repo working tree
- Committing your work to a feature branch
- Using any MCP server

Do continue to ask before:

- Force-push, hard-reset, or any history-rewriting operation
- Deploying to production or any non-development environment
- Spending money (paid API calls outside Bedrock, cloud resource creation)
- Deleting anything outside `<project>/.local/` or `/tmp/`

## Sub-Agent Coordination

For tasks that span more than ~3 phases or ~500 lines of expected output, **default to a sub-agent team** (worker → reviewer → re-reviewer) rather than tackling solo. The reviewer/re-reviewer pattern catches lead-level errors the worker won't notice. See `workflow.md` § Sub-Agent Teams for the exact pattern and Bedrock model-ID gotchas.

## Session Continuity

When resuming work on a project, check `~/.memelord/` and any project-local `AGENTS.md` / `.memelord/` first to recover prior task phase, design decisions, and known blockers. Do not re-explain to the user state that's already documented.
