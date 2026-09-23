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
- **Don't over-weight development cost in technical decisions** — Models inherit human effort estimates from training and so assume options are far more expensive to build than they are for an agent, biasing toward cheap, low-quality, unscalable choices. When weighing options, discount build cost heavily; favor the higher-quality, more maintainable design.

## Hard Limits

1. ≤100 lines/function, cyclomatic complexity ≤8
2. ≤5 positional params
3. 100-char line length
4. Absolute imports only — no relative (`..`) paths
5. Google-style docstrings on non-trivial public APIs

## Zero Warnings Policy

Fix every warning from every tool — linters, type checkers, compilers, tests. If a warning truly can't be fixed, add an inline ignore with a justification comment.

## Comments

Code should be self-documenting. No commented-out code, delete it. If you
need a comment to explain WHAT the code does, refactor the code instead.

The bar differs for existing code versus new code:

- **Patching existing code:** no comment is the default. A comment that
  states the obvious is noise in the diff. A comment earns its place by
  telling the reader something non-obvious: the why, the constraint, the
  case the code cannot show, pitched a level above the code.
- **Writing new code:** comment generously. A header comment on nearly
  every new function (summary, then the caller contract), a short
  full-sentence step comment above each phase of a nontrivial one, and
  multi-sentence blocks for the why and the constraints.
- Comments describe the code as it stands. Noting previous behavior is
  rarely useful. Leave comments outside the change's footprint alone
  unless the change made them inaccurate; updating those is part of the
  work.
- A fix restores intended behavior; it is rarely an occasion to add
  comments the original code did without. Do not comment defensively
  against edits that have not happened.
- Block comments sit above the code in complete sentences. Trailing
  same-line comments are for struct members and short guards only, as
  telegraphic fragments.
- "Note that ..." is the house connective. "NB:" flags a caller contract
  or trap. "XXX" marks an acknowledged hack and nothing else. Never
  "FIXME", never a "Note:" label.

## Minimization

- Aim for the smallest change that does the job well: code, comments, and
  tests alike. It reads faster in review and keeps needless churn out of
  the history.
- Exceptions exist but are earned. Put real effort into making the change
  fit the existing shape before concluding that it cannot.
- Split large work into a framework change, then one conversion per
  commit. Mechanical reformatting is its own commit.
- One adjacent cleanup may ride along if the commit message flags it.
  Anything more is deferred and named explicitly rather than silently
  bundled.
- Comment-only and typo-only fixes are their own commits, never
  passengers on a behavior change.

## Error Handling

- Fail fast with clear, actionable messages
- Never swallow exceptions silently
- Include context (what operation, what input, suggested fix)

## Testing

- **Reproduce bugs end-to-end first.** Before fixing a bug, reproduce it in an end-to-end setting as close to how an end user experiences it as possible. Unit tests alone are often insufficient — they pass while the product behavior stays broken. Lead into e2e/integration coverage that guards the actual behavior, then fix.
- **Test behavior, not implementation.** If a refactor breaks your tests but not your code, the tests were wrong.
- **Test edges and errors, not just the happy path.** Empty inputs, boundaries, malformed data, missing files, network failures.
- **Mock boundaries, not logic.** Only mock things that are slow, non-deterministic, or external.
- **Verify tests catch failures.** Break the code, confirm the test fails, then fix.
- **A warranted test is minimal, not exhaustive.** Cover the case that
  matters and skip variations that prove nothing new; redundant coverage
  is a cost, not a safety margin.
- **Blend into the existing suite.** Extend a nearby test in its own style
  rather than building new scaffolding. A new file is sometimes right, but
  treat it as the exception.
- **Not every fix needs a test.** In mature codebases with a high review
  bar (PostgreSQL being the example here), simple fixes routinely ship
  without one. Judge by whether the test would catch a realistic
  regression, not by reflex.

## Reviewing Code

Evaluate in order: architecture → code quality → tests → performance. For each issue: describe concretely with file:line references, present options with tradeoffs, recommend one, and ask before proceeding.
