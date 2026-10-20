# mp-skills — vendored subset of mattpocock/skills

Vendored from [mattpocock/skills](https://github.com/mattpocock/skills)
(MIT), pinned at commit `5beb35b040e3de97e54fa9e386d7e42d15c295c2`
(2026-10-19). Deployed by `modules/home-manager/ai/skills.nix` as per-skill
`mp-<name>` subdirs under every agent's skills root (claude, kiro/pi, maki,
fx).

## Why vendored, not a flake input

The upstream repo is ~40 skills; most are tied to the author's issue-tracker
workflow or TypeScript tooling, or overlap skills this repo already ships.
Taking a curated subset in-tree (rather than a whole-repo flake input) keeps
the deployed set small and lets us adapt the few author-specific lines.

## The subset (9 skills)

| skill | why | extra files |
|---|---|---|
| writing-for-agents | framework for writing skills / AGENTS.md | SKILL-MECHANICS.md |
| diagnosing-bugs | structured hard-bug / perf loop | scripts/hitl-loop.template.sh |
| code-review | standards + correctness review | — |
| research | investigate against primary sources → Markdown | — |
| codebase-design | deep-module design vocabulary | DEEPENING.md, DESIGN-IT-TWICE.md |
| handoff | compact a conversation for another agent | — |
| grilling | adversarial plan/design stress-test | — |
| grill-me | thin wrapper that invokes `grilling` | — |
| git-guardrails | Claude-Code PreToolUse hook blocking destructive git | scripts/block-dangerous-git.sh |

## Local adaptations (diffs from upstream)

- **code-review/SKILL.md**: the two lines coupling it to the author's issue
  tracker (`/setup-matt-pocock-skills`, GitLab `!67`) are rewritten to point
  at this maintainer's GitHub/Codeberg issues via `gh-axi` / the `github`
  MCP, and to skip spec-provenance when a repo has no tracker.

## Notes

- **git-guardrails is redundant here.** This repo already blocks destructive
  git from pi via `pi-extensions/safety-hooks.ts` and the `git-push-guard`
  pre-push hook; the vendored skill is Claude-Code-specific
  (`.claude/settings.json` PreToolUse). Kept because it was explicitly
  requested, but the pi guards are the live defence.
- **grill-me depends on grilling** (it calls the `grilling` skill); both are
  vendored so the reference resolves.

## Updating

Re-fetch at a newer upstream commit, re-apply the code-review adaptation,
update the pin above and in `skills.nix`. Drop the `agents/openai.yaml` files
upstream ships beside each SKILL.md: they are OpenAI-format mirrors our agents
never read, so they are not vendored here.
