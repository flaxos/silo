#!/usr/bin/env bash
# tools/run_observer.sh — Launch Project SILO Observability HTTP Server
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" &> /dev/null; then
    if [ -x "/home/flax/bin/godot" ]; then
        GODOT_BIN="/home/flax/bin/godot"
    else
        echo "[ERROR] Godot executable not found in PATH or /home/flax/bin/godot"
        exit 1
    fi
fi

cd "$PROJECT_ROOT"

echo "=========================================================="
echo " Project SILO — Launching Observability Server"
echo "=========================================================="
echo " Executable : $GODOT_BIN"
echo " Root       : $PROJECT_ROOT"
echo " Arguments  : $@"
echo "=========================================================="

exec "$GODOT_BIN" --headless -s tools/observer_server.gd -- "$@"
