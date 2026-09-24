extends SceneTree

const TURN_FLOW_SCRIPT: GDScript = preload("res://scripts/game/classes/TurnFlow.gd")

class FakeGameManager extends Node:
	var players: Dictionary = {}
	var player_order: Array = []
	var current_player_index: int = 0
	var game_over: bool = false
	var turn_pickup_completed: bool = false
	var claim_window_active: bool = false
	var claim_deadline_unix: int = 0
	var claim_window_id: int = 0
	var claim_opened_by_peer_id: int = -1
	var claim_offer_peer_id: int = -1
	var claim_last_passed_peer_id: int = -1
	var discard_top: Card = Card.new(Card.Suit.HEARTS, 7, 5)
	var claimed_by_peer_id: int = -1

	func _init() -> void:
		for peer_id in [1, 2, 3, 4]:
			var player: Player = Player.new()
			player.peer_id = peer_id
			player.name = "Player %d" % peer_id
			players[peer_id] = player
			player_order.append(player)

	func get_current_player_peer_id() -> int:
		return (player_order[current_player_index] as Player).peer_id

	func replenish_deck_if_empty() -> bool:
		return false

	func draw_card_from_deck_for_peer(_peer_id: int) -> Card:
		return Card.new(Card.Suit.CLUBS, 4, 5)

	func mark_turn_pickup_completed() -> void:
		turn_pickup_completed = true

	func get_discard_top_card() -> Card:
		return discard_top

	func open_claim_window(opened_by_peer_id: int, duration_seconds: int) -> int:
		claim_window_id += 1
		claim_window_active = true
		claim_opened_by_peer_id = opened_by_peer_id
		claim_deadline_unix = int(Time.get_unix_time_from_system()) + duration_seconds
		return claim_window_id

	func take_discard_top_for_peer(peer_id: int) -> Card:
		var card: Card = discard_top
		discard_top = null
		claimed_by_peer_id = peer_id
		return card

	func update_claim_status_rows(_eligible: Array, _passed: Array, _last_discard: int, _claimant: int, _force_pass: bool) -> void:
		pass

	func clear_claim_window() -> void:
		claim_window_active = false
		claim_deadline_unix = 0
		claim_opened_by_peer_id = -1
		claim_offer_peer_id = -1

func _initialize() -> void:
	var manager: FakeGameManager = FakeGameManager.new()
	var flow: TurnFlow = TURN_FLOW_SCRIPT.new()
	flow.configure(manager, manager.players)
	flow.last_discard_peer_id = 4
	var draw_result: Dictionary = flow.apply_move(1, {"type": "draw_from_deck", "claim_window_seconds": 30})
	if not bool(draw_result.get("ok", false)) or not manager.claim_window_active:
		_fail("Drawing from the Deck did not open the Claim Window")
		manager.free()
		return

	var early_claim: Dictionary = flow.apply_move(3, {"type": "claim_pile"})
	if bool(early_claim.get("ok", false)) or manager.discard_top == null:
		_fail("Player 3 claimed before player 2 had a claim-or-pass opportunity")
		manager.free()
		return
	var early_pass: Dictionary = flow.apply_move(3, {"type": "pass_claim"})
	if bool(early_pass.get("ok", false)) or manager.claim_offer_peer_id != 2:
		_fail("Player 3 passed before player 2 had a claim-or-pass opportunity")
		manager.free()
		return

	var first_pass: Dictionary = flow.apply_move(2, {"type": "pass_claim"})
	var second_claim: Dictionary = flow.apply_move(3, {"type": "claim_pile"})
	if not bool(first_pass.get("ok", false)) or not bool(second_claim.get("ok", false)) or manager.claimed_by_peer_id != 3:
		_fail("Player 3 could not claim after player 2 passed")
		manager.free()
		return

	manager.free()

	var wrap_manager: FakeGameManager = FakeGameManager.new()
	wrap_manager.current_player_index = 2
	var wrap_flow: TurnFlow = TURN_FLOW_SCRIPT.new()
	wrap_flow.configure(wrap_manager, wrap_manager.players)
	wrap_flow.last_discard_peer_id = 2
	wrap_flow.apply_move(3, {"type": "draw_from_deck", "claim_window_seconds": 30})
	if wrap_flow.eligible_claim_peer_ids() != [4, 1] or wrap_manager.claim_offer_peer_id != 4:
		_fail("Claim order did not wrap from player 4 to player 1")
		wrap_manager.free()
		return
	if bool(wrap_flow.apply_move(1, {"type": "claim_pile"}).get("ok", false)):
		_fail("Player 1 claimed before player 4 when turn order wrapped")
		wrap_manager.free()
		return
	wrap_flow.apply_move(4, {"type": "pass_claim"})
	if wrap_manager.claim_offer_peer_id != 1 or not bool(wrap_flow.apply_move(1, {"type": "claim_pile"}).get("ok", false)):
		_fail("Player 1 could not claim after player 4 passed")
		wrap_manager.free()
		return
	wrap_manager.free()

	var timeout_manager: FakeGameManager = FakeGameManager.new()
	var timeout_flow: TurnFlow = TURN_FLOW_SCRIPT.new()
	timeout_flow.configure(timeout_manager, timeout_manager.players)
	timeout_flow.last_discard_peer_id = 4
	timeout_flow.apply_move(1, {"type": "draw_from_deck", "claim_window_seconds": 30})
	var global_deadline: int = timeout_manager.claim_deadline_unix
	if not is_equal_approx(timeout_flow.claim_offer_timeout_seconds(float(global_deadline) - 30.0), 15.0):
		_fail("The first of two eligible players did not receive half the 30-second window")
		timeout_manager.free()
		return
	var timeout_result: Dictionary = timeout_flow.apply_move(0, {
		"type": "timeout_claim_offer",
		"claim_window_id": timeout_manager.claim_window_id,
		"claim_offer_peer_id": 2
	})
	if not bool(timeout_result.get("ok", false)) or timeout_manager.claim_offer_peer_id != 3 or timeout_manager.claim_deadline_unix != global_deadline:
		_fail("Player 2 timeout did not pass the offer to player 3 under the original deadline")
		timeout_manager.free()
		return
	if not is_equal_approx(timeout_flow.claim_offer_timeout_seconds(float(global_deadline) - 25.0), 25.0):
		_fail("The last eligible player did not receive the remaining window time")
		timeout_manager.free()
		return
	if bool(timeout_flow.apply_move(0, {
		"type": "timeout_claim_offer",
		"claim_window_id": timeout_manager.claim_window_id,
		"claim_offer_peer_id": 2
	}).get("ok", false)):
		_fail("A stale offer timeout changed the next player's opportunity")
		timeout_manager.free()
		return
	timeout_flow.apply_move(3, {"type": "pass_claim"})
	if timeout_manager.claim_window_active:
		_fail("The Claim Window stayed open after all eligible players passed")
		timeout_manager.free()
		return
	timeout_manager.free()

	var two_player_manager: FakeGameManager = FakeGameManager.new()
	two_player_manager.players.erase(3)
	two_player_manager.players.erase(4)
	two_player_manager.player_order.resize(2)
	var two_player_flow: TurnFlow = TURN_FLOW_SCRIPT.new()
	two_player_flow.configure(two_player_manager, two_player_manager.players)
	two_player_flow.last_discard_peer_id = 2
	two_player_flow.apply_move(1, {"type": "draw_from_deck", "claim_window_seconds": 30})
	if two_player_manager.claim_window_active:
		_fail("The Claim Window opened even though the only Non-turn Player discarded the card")
		two_player_manager.free()
		return
	two_player_manager.free()

	var expired_manager: FakeGameManager = FakeGameManager.new()
	var expired_flow: TurnFlow = TURN_FLOW_SCRIPT.new()
	expired_flow.configure(expired_manager, expired_manager.players)
	expired_flow.last_discard_peer_id = 4
	expired_flow.apply_move(1, {"type": "draw_from_deck", "claim_window_seconds": 30})
	expired_manager.claim_deadline_unix = int(Time.get_unix_time_from_system()) - 1
	expired_flow.apply_move(2, {"type": "claim_pile"})
	if expired_manager.claim_window_active or expired_manager.claimed_by_peer_id != -1:
		_fail("A claim succeeded after the global Claim Window deadline")
		expired_manager.free()
		return
	expired_manager.free()

	print("PASS: Claim Window offers, passes, and times out in turn order")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
