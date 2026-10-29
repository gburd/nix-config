#!/usr/bin/env python3
"""SessionStart hook for Claude Code / Kiro: inject shared agent memory.

Replaces `memelord hook session-start`. Reads the Claude-Code hook payload
({session_id, cwd, ...}) on stdin, asks the shared memory service for this
project's newest memories, and prints
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ...}}.

Never fails the session: any error prints nothing and exits 0.
env: AGENT_MEMORY_URL (base URL), AGENT_MEMORY_KEY_FILE (sops secret path).
"""
import json
import os
import sys
import urllib.request

INSTRUCTIONS = """# Memory system instructions

You share one persistent memory service with every agent on every host
(MCP server `agent-memory`). Use it:

1. At the start of a task, call memory_search with the request (add the
   project tag below to narrow it). The memories above are only a first pass.
2. When you self-correct, when the user corrects you, or when you learn
   something durable about a codebase, call memory_store. Put the lesson in
   `content`, and in `metadata` set `tags` to include the project tag below
   plus a kind tag (`kind:correction`, `kind:user`, `kind:insight`), and
   `type` to one of user_correction, preference_signal, insight, finding.
   The user should never have to tell you the same thing twice.
3. If a memory above is wrong, fix it: memory_update with its content_hash,
   or memory_delete it, and store the correct version.
"""


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        payload = {}
    base = os.environ.get("AGENT_MEMORY_URL")
    key_file = os.environ.get("AGENT_MEMORY_KEY_FILE")
    if not base or not key_file:
        return 0
    try:
        key = open(key_file, encoding="utf-8").read().strip()
    except OSError:
        return 0
    cwd = payload.get("cwd") or os.getcwd()
    rel = os.path.relpath(cwd, os.path.expanduser("~"))
    tag = "project:" + ("home" if rel == "." else rel)
    try:
        req = urllib.request.Request(
            base + "/api/search/by-tag",
            data=json.dumps({"tags": [tag], "limit": 12}).encode(),
            headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            results = json.load(resp).get("results", [])
    except Exception:
        results = []
    # Budget like memelord's injection: a handful of memories, ~12k chars.
    parts, used = [], 0
    for r in results[:8]:
        m = r.get("memory", {})
        text = m.get("content", "")
        if len(text) > 2000:
            text = text[:2000] + " [...]"
        if used + len(text) > 12000:
            break
        used += len(text)
        parts.append(f"[{m.get('memory_type') or 'note'}] (hash: {m.get('content_hash', '')[:12]})\n{text}")
    context = ("# Memories from past sessions\n\n" + "\n\n".join(parts) + "\n\n" if parts else "")
    context += INSTRUCTIONS + f"\nThis project's tag: `{tag}`\n"
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
