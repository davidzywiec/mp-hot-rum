extends Node

class FakeGameManager extends Node:
	var player_order: Array = []
	var current_player_index: int = 0
	var claim_window_active: bool = true
	var claim_deadline_unix: int = 0
	var claim_opened_by_peer_id: int = 1
	var claim_offer_peer_id: int = 2
	var claim_window_id: int = 1
	var claim_last_passed_peer_id: int = -1

	func _init() -> void:
		for peer_id in [1, 2, 3, 4]:
			var player: Player = Player.new()
			player.peer_id = peer_id
			player_order.append(player)

	func get_current_player_peer_id() -> int:
		return 1

	func update_claim_status_rows(_eligible: Array, _passed: Array, _last_discard: int, _claimant: int, _force_pass: bool) -> void:
		pass

	func clear_claim_window() -> void:
		claim_window_active = false
		claim_offer_peer_id = -1

class ProbeServer extends ServerHandler:
	var last_result: Dictionary = {}

	func _ensure_game_manager_bound() -> bool:
		return true

	func _apply_turn_flow_result(result: Dictionary) -> bool:
		last_result = result
		return bool(result.get("ok", false))

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: FakeGameManager = FakeGameManager.new()
	add_child(manager)
	manager.claim_deadline_unix = int(Time.get_unix_time_from_system()) + 4
	var server: ProbeServer = ProbeServer.new()
	add_child(server)
	server.game_manager = manager
	for entry in manager.player_order:
		server.players[(entry as Player).peer_id] = entry
	server._ensure_turn_flow()
	server.turn_flow.last_discard_peer_id = 4
	server._schedule_claim_offer_timeout()
	var timeout_msec: int = Time.get_ticks_msec() + 3000
	while manager.claim_offer_peer_id == 2 and Time.get_ticks_msec() < timeout_msec:
		await get_tree().create_timer(0.1).timeout
	if manager.claim_offer_peer_id != 3 or not bool(server.last_result.get("ok", false)):
		printerr("FAIL: the server did not auto-pass player 2 and offer the card to player 3")
		get_tree().quit(1)
		return
	print("PASS: server offer timer advanced Claim Window priority")
	get_tree().quit(0)
