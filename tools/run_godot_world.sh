#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    if [[ -x /home/flax/bin/godot ]]; then
        GODOT_BIN=/home/flax/bin/godot
    else
        echo "Godot 4 was not found (set GODOT_BIN or install /home/flax/bin/godot)." >&2
        exit 1
    fi
fi

cd "$PROJECT_ROOT"
exec "$GODOT_BIN" --path "$PROJECT_ROOT" "$@"
