#!/usr/bin/env bash
# Idempotent installer: symlinks each codex/<skill-name>/SKILL.md to
# ~/.codex/prompts/<skill-name>.md so it becomes a /<skill-name> slash command
# in OpenAI Codex.
#
# Re-running is safe: existing correct symlinks are skipped, conflicts are
# surfaced (not overwritten), and missing prompts directory is created.

set -euo pipefail

PROMPTS_DIR="${CODEX_PROMPTS_DIR:-$HOME/.codex/prompts}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PROMPTS_DIR"

installed=0
skipped=0
conflicts=0

for skill_dir in "$HERE"/*/; do
    skill_dir="${skill_dir%/}"
    name="$(basename "$skill_dir")"
    src="$skill_dir/SKILL.md"
    dst="$PROMPTS_DIR/$name.md"

    if [[ ! -f "$src" ]]; then
        continue
    fi

    if [[ -L "$dst" ]]; then
        current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            skipped=$((skipped + 1))
            continue
        fi
        echo "CONFLICT: $dst already symlinks to $current (expected $src)" >&2
        conflicts=$((conflicts + 1))
        continue
    fi

    if [[ -e "$dst" ]]; then
        echo "CONFLICT: $dst exists and is not a symlink — leaving alone" >&2
        conflicts=$((conflicts + 1))
        continue
    fi

    ln -s "$src" "$dst"
    echo "installed: /$name -> $src"
    installed=$((installed + 1))
done

echo
echo "Summary: $installed installed, $skipped already-correct, $conflicts conflicts"

if [[ $conflicts -gt 0 ]]; then
    exit 1
fi
