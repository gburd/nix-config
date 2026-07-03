---
name: release-tagging
description: >
  Date-based release tagging conventions for this maintainer's personal repos
  (nix-config and other single-author repos). Use this skill ONLY when actually
  cutting a release or creating/pushing a git tag — the commit→push→tag→push-tag
  flow, the vYYYY.MM.DD[.N] format, and the deliberate maintainer exceptions to
  the "never push to main / never force-push" rules. Triggers on: "tag a
  release", "cut a release", "ship this", "create a tag", "vYYYY.MM.DD".
---

# Release Tagging

Date-based annotated tags (this repo + the maintainer's other personal repos):

- Format `vYYYY.MM.DD`; append `.N` for same-day re-releases (`v2026.05.29.1`).
- Always annotated (`git tag -a ... -m`), never lightweight.
- Order: merge to `main` → `git push origin main` → create tag → push tag.
  Tag message = one-line summary of what shipped.
- Push to BOTH remotes: `git push origin main` AND the Codeberg mirror
  (`git push codeberg +main:refs/heads/main`), then push the tag to both.
- Pushing a tag triggers the Build & Publish workflow (drafts a release, builds
  ISOs, un-drafts) — check the run after tagging.
- "Never push to main / never force-push" still holds for shared/team repos;
  the direct-to-main+tag flow and force-pushing a mirror are deliberate
  maintainer exceptions for these single-author repos — only when asked.
