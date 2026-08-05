#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4}"
LOG_DIR="${LOG_DIR:-"$ROOT_DIR/.tmp/headless-gameplay-smoke"}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-30}"
SERVER_LOG="$LOG_DIR/server.log"
CLIENT_ONE_LOG="$LOG_DIR/client-one.log"
CLIENT_TWO_LOG="$LOG_DIR/client-two.log"
CLIENT_ONE_GODOT_LOG="$LOG_DIR/client-one-godot.log"
CLIENT_TWO_GODOT_LOG="$LOG_DIR/client-two-godot.log"

mkdir -p "$LOG_DIR"
rm -f "$SERVER_LOG" "$CLIENT_ONE_LOG" "$CLIENT_TWO_LOG" "$CLIENT_ONE_GODOT_LOG" "$CLIENT_TWO_GODOT_LOG"

server_pid=""
client_one_pid=""
client_two_pid=""

cleanup() {
	if [[ -n "${client_one_pid:-}" ]] && kill -0 "$client_one_pid" 2>/dev/null; then
		kill "$client_one_pid" 2>/dev/null || true
	fi
	if [[ -n "${client_two_pid:-}" ]] && kill -0 "$client_two_pid" 2>/dev/null; then
		kill "$client_two_pid" 2>/dev/null || true
	fi
	if [[ -n "${server_pid:-}" ]] && kill -0 "$server_pid" 2>/dev/null; then
		kill "$server_pid" 2>/dev/null || true
	fi
}
trap cleanup EXIT

echo "[SMOKE] Starting dedicated server..."
"$GODOT_BIN" --headless --path "$ROOT_DIR" --server --short-countdown --log-file "$SERVER_LOG" >"$SERVER_LOG.stdout" 2>"$SERVER_LOG.stderr" &
server_pid="$!"

sleep 2
if ! kill -0 "$server_pid" 2>/dev/null; then
	echo "[SMOKE][FAIL] Server exited before clients connected."
	cat "$SERVER_LOG.stdout" "$SERVER_LOG.stderr" "$SERVER_LOG" 2>/dev/null || true
	exit 1
fi

echo "[SMOKE] Starting smoke clients..."
"$GODOT_BIN" --headless --path "$ROOT_DIR" --log-file "$CLIENT_ONE_GODOT_LOG" "res://scenes/test/HeadlessSmokeClient.tscn" -- --headless-smoke --player-name=SmokeOne --start-game "--timeout=$TIMEOUT_SECONDS" >"$CLIENT_ONE_LOG" 2>&1 &
client_one_pid="$!"
"$GODOT_BIN" --headless --path "$ROOT_DIR" --log-file "$CLIENT_TWO_GODOT_LOG" "res://scenes/test/HeadlessSmokeClient.tscn" -- --headless-smoke --player-name=SmokeTwo "--timeout=$TIMEOUT_SECONDS" >"$CLIENT_TWO_LOG" 2>&1 &
client_two_pid="$!"

set +e
wait "$client_one_pid"
client_one_status="$?"
wait "$client_two_pid"
client_two_status="$?"
set -e

if [[ "$client_one_status" -ne 0 || "$client_two_status" -ne 0 ]]; then
	echo "[SMOKE][FAIL] One or more smoke clients failed."
	echo "[SMOKE] Logs:"
	echo "  $SERVER_LOG"
	echo "  $SERVER_LOG.stdout"
	echo "  $SERVER_LOG.stderr"
	echo "  $CLIENT_ONE_LOG"
	echo "  $CLIENT_ONE_GODOT_LOG"
	echo "  $CLIENT_TWO_LOG"
	echo "  $CLIENT_TWO_GODOT_LOG"
	exit 1
fi

echo "[SMOKE][PASS] Headless gameplay smoke completed."
echo "[SMOKE] Logs:"
echo "  $SERVER_LOG"
echo "  $SERVER_LOG.stdout"
echo "  $SERVER_LOG.stderr"
echo "  $CLIENT_ONE_LOG"
echo "  $CLIENT_ONE_GODOT_LOG"
echo "  $CLIENT_TWO_LOG"
echo "  $CLIENT_TWO_GODOT_LOG"
