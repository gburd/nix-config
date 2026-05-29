#!/usr/bin/env python3
"""Idempotent overlay patch for hermes-agent's bundled Anthropic SDK.

hermes routes Claude-on-Bedrock requests through the Anthropic SDK's
``AnthropicBedrock`` client (``anthropic/lib/bedrock/_auth.py``), which signs
every request with SigV4 and therefore requires resolvable IAM credentials.
Our hosts only carry a Bedrock *bearer token* (``AWS_BEARER_TOKEN_BEDROCK``),
which Bedrock's HTTPS endpoint accepts directly as an ``Authorization: Bearer``
header (verified: POST .../model/<id>/invoke returns HTTP 200).

This script injects a short-circuit at the very top of ``get_auth_headers``:
when ``AWS_BEARER_TOKEN_BEDROCK`` is set we return a bearer ``Authorization``
header and skip SigV4 entirely; otherwise the original upstream SigV4 code
runs unchanged. The injection is guarded by a marker so re-running it (after
every ``pipx upgrade`` on home-manager activation) is a no-op.

Usage:  patch_bedrock_bearer.py <pipx-venv-dir>
        e.g. ~/.local/share/pipx/venvs/hermes-agent

Exit status is always 0 for "nothing to do" / "already patched" / "patched";
non-zero only on unexpected IO errors. The patch is intentionally
best-effort: if the SDK layout changes we warn and leave the file untouched
rather than corrupt it.
"""
from __future__ import annotations

import glob
import os
import sys

MARKER = "[nix-config] AWS_BEARER_TOKEN_BEDROCK support"

SNIPPET = (
    "    # " + MARKER + " — injected by modules/home-manager/ai/hermes.nix\n"
    "    import os as _os\n"
    '    _bedrock_bearer = _os.environ.get("AWS_BEARER_TOKEN_BEDROCK", "").strip()\n'
    "    if _bedrock_bearer:\n"
    '        return {"Authorization": "Bearer " + _bedrock_bearer}\n'
)


def patch_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        src = fh.read()

    if MARKER in src:
        return f"already patched: {path}"

    lines = src.splitlines(keepends=True)

    # Locate the function definition.
    def_idx = next(
        (i for i, ln in enumerate(lines) if ln.lstrip().startswith("def get_auth_headers(")),
        None,
    )
    if def_idx is None:
        return f"SKIP (get_auth_headers not found — SDK changed?): {path}"

    # Find the line that closes the signature: balance parentheses starting at
    # the def line until depth returns to zero on a line ending in ':'.
    depth = 0
    end_idx = None
    for j in range(def_idx, len(lines)):
        depth += lines[j].count("(") - lines[j].count(")")
        if depth <= 0 and lines[j].rstrip().endswith(":"):
            end_idx = j
            break
    if end_idx is None:
        return f"SKIP (could not find signature end): {path}"

    lines.insert(end_idx + 1, SNIPPET)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("".join(lines))
    return f"patched: {path}"


def main() -> int:
    if len(sys.argv) < 2:
        print("[hermes-patch] usage: patch_bedrock_bearer.py <pipx-venv-dir>", file=sys.stderr)
        return 2

    venv = sys.argv[1]
    targets = glob.glob(
        os.path.join(venv, "lib", "python*", "site-packages", "anthropic", "lib", "bedrock", "_auth.py")
    )
    if not targets:
        print("[hermes-patch] anthropic bedrock _auth.py not found — skipping")
        return 0

    for path in targets:
        try:
            print("[hermes-patch] " + patch_file(path))
        except OSError as exc:  # pragma: no cover
            print(f"[hermes-patch] ERROR patching {path}: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
