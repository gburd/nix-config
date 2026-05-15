---
name: memelord-init
description: Initialize memelord persistent memory in the current project. Use when starting work in a new project that doesn't have a .memelord/ directory.
---

Set up memelord persistent memory for this project:

1. Check if `.memelord/` already exists in the project root
   - If it does, say "memelord already initialized" and run `memelord status`
   - If not, continue

2. Run `memelord init` in the project root

3. Verify setup by running `memelord status`

4. Tell the user: "Memory initialized. I'll remember corrections, insights, and patterns across sessions."
