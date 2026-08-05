#!/usr/bin/env python3
"""memelord-rollup — collapse memelord's flat memory pile into distilled pattern summaries.

memelord (glommer/memelord) stores per-project memories in a flat SQLite table
(.memelord/memory.db). In practice its Stop-hook auto-detection floods that table
with near-duplicate low-signal rows: on this machine one project had 11,611
memories of which 10,950 were the same "Auto-detected correction with Bash:
Failed approach: ..." template. A flat pile that lopsided drowns the handful of
real insights, and every SessionStart injection / vector search wades through it.

This is the "layered memory" idea (raw L0 -> distilled L1) applied to memelord's
actual store, WITHOUT forking memelord's TypeScript:

  L0 (raw)  = memelord's `memories` table. Left completely untouched.
  L1 (roll) = clusters of near-duplicate raw memories, each distilled by an LLM
              (via your local LiteLLM proxy) into ONE high-signal pattern summary.
              Written to a SEPARATE `rollup_summaries` table in the same DB, so
              memelord never sees it and a memelord upgrade can't break on it.

ponytail: deliberately NOT a 4-tier L0->L3 pyramid. The data (85 distinct
prefixes across 11k rows) is one-dimensionally duplicative; one rollup level
earns its keep, a taxonomy would be speculative. Add deeper tiers only if a
real second clustering dimension shows up.

Clustering is a cheap deterministic signature (category + normalized content
prefix), not embeddings -- memelord already stores embeddings for its own vector
search; re-clustering them here would be redundant work for no gain at this
scale. ponytail: signature-bucket clustering, switch to embedding k-means only
if summaries come out too coarse.

Usage:
  memelord-rollup [--db PATH] [--min-cluster N] [--dry-run] [--no-llm]
  memelord-rollup --show          # print current L1 summaries and exit
  memelord-rollup --stats         # print L0 vs L1 counts and exit

Env (LLM pass; falls back to --no-llm behavior if unset):
  MEMELORD_ROLLUP_BASE_URL   OpenAI-compatible endpoint (default http://127.0.0.1:4000)
  MEMELORD_ROLLUP_API_KEY    proxy key (or path in MEMELORD_ROLLUP_API_KEY_FILE)
  MEMELORD_ROLLUP_MODEL      model id (default claude-haiku-4-5-20251001 -- cheap+fast)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request

DEFAULT_MODEL = "claude-haiku-4-5-20251001"
DEFAULT_BASE_URL = "http://127.0.0.1:4000"
# How many representative raw rows to feed the LLM per cluster (cap tokens/cost).
SAMPLES_PER_CLUSTER = 12
# Skip clusters smaller than this -- a 1-3 row "cluster" isn't a pattern worth
# distilling; those stay as-is in L0.
DEFAULT_MIN_CLUSTER = 8


def normalize(content: str) -> str:
    """Signature for clustering: category-independent, structure-preserving.

    Collapse the volatile bits (JSON payloads, paths, numbers, hashes) so that
    "Failed approach: {command: cd ~/a && git ...}" and
    "Failed approach: {command: cd ~/b && git ...}" land in the same bucket.
    """
    s = content.strip()
    # Auto-detected corrections look like "<header line>\n\nFailed approach:
    # {JSON}\nWorking approach: {JSON}". The only clustering signal is the
    # header ("Auto-detected correction with Bash/Edit/Read/<tool>"); the JSON
    # payloads are noise and, with escaped quotes, resist a clean brace
    # regex. So for these, signature on the header line alone.
    first_line = s.split("\n", 1)[0]
    if first_line.startswith("Auto-detected correction with"):
        return first_line[:120]
    # Everything else: collapse brace payloads / paths / numbers generically.
    s = re.sub(r"\{[^{}]*\}", "{…}", s, flags=re.DOTALL)  # brace payloads
    s = re.sub(r"/[\w./~-]+", "/…", s)                  # paths
    s = re.sub(r"\b[0-9a-f]{7,}\b", "…", s)             # hashes/ids
    s = re.sub(r"\d+", "N", s)                          # numbers
    s = re.sub(r"\s+", " ", s)
    return s[:120]


def cluster(rows: list[sqlite3.Row]) -> dict[tuple[str, str], list[sqlite3.Row]]:
    buckets: dict[tuple[str, str], list[sqlite3.Row]] = {}
    for r in rows:
        key = (r["category"], normalize(r["content"]))
        buckets.setdefault(key, []).append(r)
    return buckets


def ensure_schema(db: sqlite3.Connection) -> None:
    db.execute(
        """CREATE TABLE IF NOT EXISTS rollup_summaries (
             id            TEXT PRIMARY KEY,
             category      TEXT NOT NULL,
             signature     TEXT NOT NULL,
             member_count  INTEGER NOT NULL,
             summary       TEXT NOT NULL,
             sample_ids    TEXT NOT NULL,   -- JSON array of L0 memory ids
             created_at    INTEGER NOT NULL,
             UNIQUE(category, signature)
           )"""
    )
    db.commit()


def llm_summarize(base_url: str, api_key: str, model: str,
                  category: str, samples: list[str]) -> str:
    joined = "\n\n---\n\n".join(samples)
    prompt = (
        f"These are {len(samples)} near-duplicate '{category}' memory entries "
        f"a coding agent recorded. Distill them into ONE terse pattern summary "
        f"(2-4 sentences, no preamble) capturing the recurring lesson: what "
        f"tends to fail/matter and the takeaway. Be concrete.\n\n{joined}"
    )
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 220,
        "temperature": 0.2,
    }).encode()
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/v1/chat/completions",
        data=body,
        headers={"Authorization": f"Bearer {api_key}",
                 "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.load(resp)
    return data["choices"][0]["message"]["content"].strip()


def load_api_key() -> str | None:
    key = os.environ.get("MEMELORD_ROLLUP_API_KEY")
    if key:
        return key
    path = os.environ.get("MEMELORD_ROLLUP_API_KEY_FILE")
    if path and os.path.exists(path):
        return open(path).read().strip()
    return None


def main() -> int:
    if "--selfcheck" in sys.argv:
        _selfcheck()
        return 0
    ap = argparse.ArgumentParser(description="Roll up memelord's flat memory pile.")
    ap.add_argument("--db", default=".memelord/memory.db",
                    help="path to memelord DB (default: .memelord/memory.db)")
    ap.add_argument("--min-cluster", type=int, default=DEFAULT_MIN_CLUSTER)
    ap.add_argument("--dry-run", action="store_true",
                    help="show what would be summarized, write nothing")
    ap.add_argument("--no-llm", action="store_true",
                    help="cluster only; use a mechanical summary, no LLM call")
    ap.add_argument("--show", action="store_true", help="print L1 summaries and exit")
    ap.add_argument("--stats", action="store_true", help="print L0/L1 counts and exit")
    args = ap.parse_args()

    if not os.path.exists(args.db):
        print(f"no memelord DB at {args.db}", file=sys.stderr)
        return 1
    db = sqlite3.connect(args.db)
    db.row_factory = sqlite3.Row
    ensure_schema(db)

    if args.show:
        for r in db.execute("SELECT category, member_count, summary FROM "
                            "rollup_summaries ORDER BY member_count DESC"):
            print(f"[{r['category']} ×{r['member_count']}] {r['summary']}\n")
        return 0
    if args.stats:
        l0 = db.execute("SELECT count(*) c FROM memories").fetchone()["c"]
        l1 = db.execute("SELECT count(*) c FROM rollup_summaries").fetchone()["c"]
        covered = db.execute("SELECT coalesce(sum(member_count),0) c "
                            "FROM rollup_summaries").fetchone()["c"]
        print(f"L0 raw memories: {l0}\nL1 summaries:    {l1}"
              f"\nL0 rows covered: {covered} ({100*covered//max(l0,1)}%)")
        return 0

    rows = db.execute("SELECT id, content, category FROM memories").fetchall()
    buckets = cluster(rows)
    clusters = {k: v for k, v in buckets.items() if len(v) >= args.min_cluster}
    print(f"{len(rows)} raw memories -> {len(buckets)} signatures -> "
          f"{len(clusters)} clusters >= {args.min_cluster}")

    base_url = os.environ.get("MEMELORD_ROLLUP_BASE_URL", DEFAULT_BASE_URL)
    model = os.environ.get("MEMELORD_ROLLUP_MODEL", DEFAULT_MODEL)
    api_key = load_api_key()
    use_llm = not args.no_llm and api_key is not None

    written = 0
    for (category, signature), members in sorted(
            clusters.items(), key=lambda kv: -len(kv[1])):
        samples = [m["content"] for m in members[:SAMPLES_PER_CLUSTER]]
        sample_ids = [m["id"] for m in members]
        if use_llm:
            try:
                summary = llm_summarize(base_url, api_key, model, category, samples)
            except (urllib.error.URLError, KeyError, TimeoutError) as e:
                print(f"  LLM failed ({e}); mechanical fallback for this cluster",
                      file=sys.stderr)
                summary = f"{len(members)} similar '{category}' entries: {signature}"
        else:
            summary = f"{len(members)} similar '{category}' entries: {signature}"

        print(f"  [{category} ×{len(members)}] {summary[:100]}")
        if not args.dry_run:
            db.execute(
                """INSERT INTO rollup_summaries
                     (id, category, signature, member_count, summary, sample_ids, created_at)
                   VALUES (?,?,?,?,?,?,?)
                   ON CONFLICT(category, signature) DO UPDATE SET
                     member_count=excluded.member_count,
                     summary=excluded.summary,
                     sample_ids=excluded.sample_ids,
                     created_at=excluded.created_at""",
                (f"rollup:{category}:{abs(hash(signature))}", category, signature,
                 len(members), summary, json.dumps(sample_ids), int(time.time())),
            )
            written += 1
    if not args.dry_run:
        db.commit()
        print(f"wrote {written} L1 summaries to {args.db} (rollup_summaries table)")
    return 0


def _selfcheck() -> None:
    """Run: python3 rollup.py --selfcheck  (asserts the clustering logic)."""
    # Auto-detected corrections cluster by header/tool, ignoring JSON payloads.
    a = normalize('Auto-detected correction with Bash:\n\nFailed approach: '
                  '{"command":"cd /a && git x"}\nWorking approach: {"command":"cd /b"}')
    b = normalize('Auto-detected correction with Bash:\n\nFailed approach: '
                  '{"command":"nix search y"}\nWorking approach: {"command":"z"}')
    assert a == b, f"same tool must share a signature: {a!r} != {b!r}"
    c = normalize('Auto-detected correction with Edit:\n\nFailed approach: {}')
    assert a != c, "different tools must NOT share a signature"
    # Generic (non-auto-detected) content collapses braces/paths/numbers.
    d = normalize("Config at /home/x/foo.nix uses value 42 and {a:1}")
    e = normalize("Config at /home/y/bar.nix uses value 99 and {b:2}")
    assert d == e, f"paths/numbers/braces must normalize together: {d!r} != {e!r}"
    # Clustering respects min size and category (dict-like rows).
    class Row(dict):
        pass
    rows = ([Row(id=str(i), content="Auto-detected correction with Bash:\n\nx",
                 category="correction") for i in range(10)]
            + [Row(id="z", content="one-off insight", category="insight")])
    buckets = cluster(rows)
    big = [v for v in buckets.values() if len(v) >= 8]
    assert len(big) == 1 and len(big[0]) == 10, f"expected one 10-row cluster, got {sorted(len(v) for v in buckets.values())}"
    print("selfcheck OK")


if __name__ == "__main__":
    sys.exit(main())
