extends Node

const DEFAULT_SERVER_ADDRESS: String = "127.0.0.1"
const DEFAULT_TIMEOUT_SECONDS: float = 20.0
const SETTLE_SECONDS: float = 0.25

var server_address: String = DEFAULT_SERVER_ADDRESS
var player_name: String = "SmokeClient"
var starts_game: bool = false
var add_ai_difficulty: String = ""
var timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS

var connected: bool = false
var failed: bool = false
var latest_state: Dictionary = {}
var latest_players: Array = []
var private_hand: Array = []
var took_turn: bool = false
var observed_turn_advance: bool = false
var turn_peer_id: int = -1
var next_turn_peer_id: int = -1
var passed_claim_window_id: int = -1

func _ready() -> void:
	_parse_args()
	print("[SMOKE][%s] Starting headless smoke client. starts_game=%s server=%s" % [
		player_name,
		str(starts_game),
		server_address
	])
	SignalManager.server_connected.connect(_on_connected)
	SignalManager.failed_connection.connect(_on_failed_connection)
	Game_State_Manager.player_state_updated.connect(_on_player_state_updated)
	Game_State_Manager.game_state_updated.connect(_on_game_state_updated)
	Game_State_Manager.private_hand_updated.connect(_on_private_hand_updated)
	call_deferred("_run")

func _parse_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg: String = str(raw_arg)
		if arg.begins_with("--server-address="):
			server_address = arg.trim_prefix("--server-address=")
		elif arg.begins_with("--player-name="):
			player_name = arg.trim_prefix("--player-name=")
		elif arg == "--start-game":
			starts_game = true
		elif arg.begins_with("--add-ai="):
			add_ai_difficulty = arg.trim_prefix("--add-ai=")
		elif arg.begins_with("--timeout="):
			timeout_seconds = maxf(1.0, float(arg.trim_prefix("--timeout=")))

func _run() -> void:
	Network_Manager.join_server(server_address)
	if not await _wait_until(func() -> bool: return connected or failed, timeout_seconds):
		_fail("Timed out connecting to server.")
		return
	if failed:
		_fail("Connection failed.")
		return

	var peer_id: int = multiplayer.get_unique_id()
	Network_Manager.rpc_id(1, "register_player", player_name, peer_id)
	Network_Manager.rpc_id(1, "register_ready_flag", peer_id, true)
	if not add_ai_difficulty.is_empty():
		Network_Manager.rpc_id(1, "register_add_ai_player", add_ai_difficulty)
	print("[SMOKE][%s] Registered as peer %d." % [player_name, peer_id])

	if starts_game:
		if not await _wait_until(func() -> bool: return latest_players.size() >= 2, timeout_seconds):
			_fail("Timed out waiting for both smoke clients to register.")
			return
		Network_Manager.rpc_id(1, "register_countdown", peer_id, true, 1)
		print("[SMOKE][%s] Requested game start countdown." % player_name)

	if not await _wait_until(func() -> bool:
		return int(latest_state.get("round_number", 0)) >= 1 and int(latest_state.get("current_player_peer_id", -1)) != -1
	, timeout_seconds):
		_fail("Timed out waiting for initial game state.")
		return

	if not await _wait_until(func() -> bool: return not private_hand.is_empty(), timeout_seconds):
		_fail("Timed out waiting for private hand.")
		return
	if not add_ai_difficulty.is_empty():
		var ai_peer_id: int = -1
		for raw_player in latest_players:
			var player: Dictionary = raw_player
			if bool(player.get("is_ai", false)):
				ai_peer_id = int(player.get("peer_id", -1))
				break
		if ai_peer_id == -1 or not GameManager.players.has(ai_peer_id) or not (GameManager.players[ai_peer_id] as Player).is_ai:
			_fail("Client Game roster did not retain AI identity.")
			return
		if (GameManager.players[ai_peer_id] as Player).difficulty != add_ai_difficulty:
			_fail("Client Game roster did not retain AI difficulty.")
			return

	turn_peer_id = int(latest_state.get("current_player_peer_id", -1))
	if turn_peer_id == peer_id:
		await _take_smoke_turn(peer_id)
	else:
		print("[SMOKE][%s] Peer %d is observing current turn peer %d." % [player_name, peer_id, turn_peer_id])

	if starts_game:
		if not await _wait_until(func() -> bool: return observed_turn_advance, timeout_seconds):
			_fail("Timed out waiting for smoke turn to advance.")
			return
		print("[SMOKE][%s] Observed turn advance from %d to %d." % [player_name, turn_peer_id, next_turn_peer_id])
	else:
		if not await _wait_until(func() -> bool: return took_turn or observed_turn_advance, timeout_seconds):
			_fail("Timed out waiting for local turn or observed turn advance.")
			return

	_pass("Headless gameplay smoke client completed.")

func _take_smoke_turn(peer_id: int) -> void:
	print("[SMOKE][%s] Taking smoke turn as peer %d." % [player_name, peer_id])
	Network_Manager.rpc_id(1, "register_take_from_pile")
	if not await _wait_until(func() -> bool: return bool(latest_state.get("turn_pickup_completed", false)), timeout_seconds):
		_fail("Timed out waiting for pickup completion.")
		return
	if private_hand.is_empty():
		_fail("Cannot discard because private hand is empty after pickup.")
		return
	var discard_payload: Dictionary = private_hand[0]
	Network_Manager.rpc_id(1, "register_discard_card", discard_payload)
	took_turn = true

func _on_connected() -> void:
	connected = true

func _on_failed_connection() -> void:
	failed = true

func _on_player_state_updated(players_data: Array) -> void:
	latest_players = players_data

func _on_game_state_updated(state: Dictionary) -> void:
	var previous_peer_id: int = int(latest_state.get("current_player_peer_id", -1))
	latest_state = state
	var current_peer_id: int = int(latest_state.get("current_player_peer_id", -1))
	if not add_ai_difficulty.is_empty() and bool(latest_state.get("claim_window_active", false)) and current_peer_id != multiplayer.get_unique_id():
		var claim_window_id: int = int(latest_state.get("claim_window_id", -1))
		var offer_peer_id: int = int(latest_state.get("claim_offer_peer_id", multiplayer.get_unique_id()))
		if claim_window_id != passed_claim_window_id and offer_peer_id == multiplayer.get_unique_id():
			passed_claim_window_id = claim_window_id
			Network_Manager.rpc_id(1, "register_pass_pile")
	if turn_peer_id != -1 and previous_peer_id == turn_peer_id and current_peer_id != -1 and current_peer_id != turn_peer_id:
		observed_turn_advance = true
		next_turn_peer_id = current_peer_id

func _on_private_hand_updated(cards: Array) -> void:
	private_hand = cards

func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if bool(predicate.call()):
			return true
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		elapsed += SETTLE_SECONDS
	return bool(predicate.call())

func _pass(message: String) -> void:
	print("[SMOKE][%s][PASS] %s" % [player_name, message])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("[SMOKE][%s][FAIL] %s" % [player_name, message])
	get_tree().quit(1)
