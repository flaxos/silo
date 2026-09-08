#!/usr/bin/env bash
# tools/run_game_server.sh — SILO Operations & Observability Web Server Launcher
# Hosts the authoritative simulation engine and serves the mobile/desktop web client.

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

PORT=8080
for arg in "$@"; do
  if [[ "$arg" =~ ^--port=([0-9]+)$ ]]; then
    PORT="${BASH_REMATCH[1]}"
  fi
done

# Detect network IPs (filtering out docker bridge 172.x and loopback)
LAN_IP=$(ip -4 -o addr show 2>/dev/null | awk '{print $2, $4}' | grep -E '^(en|wl|eth)' | head -n 1 | awk '{print $2}' | cut -d/ -f1 || true)
ZT_IP=$(ip -4 -o addr show 2>/dev/null | awk '{print $2, $4}' | grep -E '^zt' | head -n 1 | awk '{print $2}' | cut -d/ -f1 || true)

# Fallbacks if regex didn't match
if [ -z "$LAN_IP" ]; then
  LAN_IP=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^172\.' | grep -v '^127\.' | grep -v ':' | head -n 1 || true)
fi

echo "=================================================================="
echo "          PROJECT SILO — OPERATIONS REMOTE GAME SERVER            "
echo "=================================================================="
echo " Starting authoritative simulation engine on 0.0.0.0:${PORT}..."
echo ""
echo " 📱 MOBILE UAT ACCESS (Phone / Tablet on same WiFi or ZeroTier):"
if [ -n "$LAN_IP" ]; then
  echo "    ► Local WiFi URL : http://${LAN_IP}:${PORT}/"
fi
if [ -n "$ZT_IP" ]; then
  echo "    ► ZeroTier URL   : http://${ZT_IP}:${PORT}/"
fi
echo ""
echo " 💻 DESKTOP ACCESS:"
echo "    ► Local Browser  : http://localhost:${PORT}/"
echo "    ► REST API Root  : http://localhost:${PORT}/api/"
echo ""
echo " 🎮 MOBILE TESTING QUICKSTART:"
echo "    1. Open the Local WiFi URL on your phone's Safari or Chrome."
echo "    2. The 'Operations Console' opens with active crisis incidents."
echo "    3. Tap an incident, select a directive, tap DISPATCH."
echo "    4. Use the bottom navigation bar to switch between Operations,"
echo "       Physical Silo map (pinch-to-zoom supported), and Telemetry."
echo "=================================================================="
echo ""

exec godot --headless -s tools/observer_server.gd -- "$@"
