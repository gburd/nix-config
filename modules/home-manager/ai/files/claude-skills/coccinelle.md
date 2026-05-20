# Coccinelle — C Semantic Patching

Use `spatch` (Coccinelle) for structured code transformations and searches across C codebases. It understands C at the AST level.

## Commands

```bash
spatch --sp-file rule.cocci --dir src/           # Apply transformation
spatch --sp-file rule.cocci --dir src/ --dry-run # Preview only
spatch --sp-file find.cocci --dir src/ -o /dev/null  # Search only
```

## SmPL Quick Reference

```
@@ expression E; @@          # Metavariable block
- old(E)                      # Remove line matching pattern
+ new(E)                      # Add replacement
... when != X                 # "without intervening X"
*suspicious_line(...)         # Report (search mode, no edit)
```

## Common Patterns

**Rename function:** `- old_fn( + new_fn( ...)`
**Find null-after-use:** `*p = ...; ... when != p = E  *if (p == NULL) {...}`
**Add error check:** `p = malloc(...); + if (!p) return -ENOMEM;`
**API migration:** `- deprecated_api(E1, E2) + new_api(E1, E2, 0)`

## When to Use

- Refactoring C code (dbsql, libdb, openldap)
- Finding structural bug patterns
- Enforcing coding conventions at scale
- Migrating deprecated APIs
