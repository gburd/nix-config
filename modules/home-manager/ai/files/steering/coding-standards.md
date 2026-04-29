# Coding Standards

## Philosophy

- **No speculative features** — Don't add features, flags, or configuration unless actively needed
- **No premature abstraction** — Don't create utilities until you've written the same code three times
- **Clarity over cleverness** — Prefer explicit, readable code over dense one-liners
- **Justify new dependencies** — Each dependency is attack surface and maintenance burden
- **No phantom features** — Don't document or validate features that aren't implemented
- **Replace, don't deprecate** — When a new implementation replaces an old one, remove the old one entirely
- **Verify at every level** — Set up automated guardrails (linters, type checkers, pre-commit hooks, tests) as the first step
- **Bias toward action** — Decide and move for anything easily reversed; ask before committing to interfaces, data models, architecture
- **Finish the job** — Handle edge cases you can see, clean up what you touched, flag adjacent breakage. Don't invent new scope.

## Hard Limits

1. ≤100 lines/function, cyclomatic complexity ≤8
2. ≤5 positional params
3. 100-char line length
4. Absolute imports only — no relative (`..`) paths
5. Google-style docstrings on non-trivial public APIs

## Zero Warnings Policy

Fix every warning from every tool — linters, type checkers, compilers, tests. If a warning truly can't be fixed, add an inline ignore with a justification comment.

## Comments

Code should be self-documenting. No commented-out code — delete it. If you need a comment to explain WHAT the code does, refactor the code instead.

## Error Handling

- Fail fast with clear, actionable messages
- Never swallow exceptions silently
- Include context (what operation, what input, suggested fix)

## Testing

- **Test behavior, not implementation.** If a refactor breaks your tests but not your code, the tests were wrong.
- **Test edges and errors, not just the happy path.** Empty inputs, boundaries, malformed data, missing files, network failures.
- **Mock boundaries, not logic.** Only mock things that are slow, non-deterministic, or external.
- **Verify tests catch failures.** Break the code, confirm the test fails, then fix.

## Reviewing Code

Evaluate in order: architecture → code quality → tests → performance. For each issue: describe concretely with file:line references, present options with tradeoffs, recommend one, and ask before proceeding.
