extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var server: Node = load("res://scripts/network/ServerHandler.gd").new()
	get_root().add_child(server)
	server.game_manager = get_root().get_node("GameManager")
	server._ensure_turn_flow()
	var first_join: Dictionary = server.register_player("Host", 11)
	if not _expect(bool(first_join.get("ok", false)), "first human can join"):
		return
	var second_join: Dictionary = server.register_player("Guest", 22)
	if not _expect(bool(second_join.get("ok", false)), "second human can join"):
		return
	var unauthorized: Dictionary = server.register_add_ai_player(22, "Medium")
	if not _expect(not bool(unauthorized.get("ok", true)), "only Host may add AI"):
		return
	var added: Dictionary = server.register_add_ai_player(11, "Medium")
	if not _expect(bool(added.get("ok", false)), "Host can add AI"):
		return
	var snapshot: Dictionary = server.get_lobby_snapshot()
	var roster: Array = snapshot.get("players", [])
	if not _expect(roster.size() == 3, "AI counts as third roster seat"):
		return
	if not _expect(int(snapshot.get("host_peer_id", -1)) == 11, "first human is Host"):
		return
	var ai: Dictionary = roster[2]
	if not _expect(bool(ai.get("is_ai", false)) and str(ai.get("difficulty", "")) == "Medium" and bool(ai.get("ready", false)), "AI identity, difficulty, and Ready are public"):
		return
	var ai_id: int = int(ai.get("peer_id", 0))
	if not _expect(ai_id < -1, "AI seat ID cannot collide with a human peer"):
		return
	server._on_peer_disconnected(11)
	if not _expect(int(server.get_lobby_snapshot().get("host_peer_id", -1)) == 22, "Host passes to next connected human"):
		return
	var removed: Dictionary = server.register_remove_ai_player(22, ai_id)
	if not _expect(bool(removed.get("ok", false)), "new Host can remove AI"):
		return
	if not _test_capacity_and_lock(server):
		return
	print("[AI_LOBBY_ROSTER_TEST][PASS]")
	quit(0)

func _test_capacity_and_lock(server: Node) -> bool:
	for difficulty in ["Easy", "Medium", "Hard", "Easy", "Medium"]:
		var added: Dictionary = server.register_add_ai_player(22, difficulty)
		if not _expect(bool(added.get("ok", false)), "Host can fill Lobby with AI"):
			return false
	var full: Dictionary = server.register_player("Late Human", 33)
	if not _expect(not bool(full.get("ok", true)) and str(full.get("reason", "")) == "Lobby full", "full Lobby rejects human without evicting AI"):
		return false
	server.register_ready_flag(22, true)
	var start: Dictionary = server.register_countdown(22, true, 60.0)
	if not _expect(bool(start.get("ok", false)), "Host can start countdown with Ready roster"):
		return false
	var roster: Dictionary = server.get_lobby_snapshot()
	if not _expect(bool(roster.get("roster_locked", false)) and (roster.get("players", []) as Array).size() == 6, "countdown locks full roster"):
		return false
	var late_edit: Dictionary = server.register_remove_ai_player(22, -3)
	if not _expect(not bool(late_edit.get("ok", true)), "Host cannot edit during countdown"):
		return false
	var cancel: Dictionary = server.register_countdown(22, false)
	if not _expect(not bool(cancel.get("ok", true)) and bool(server.get_lobby_snapshot().get("roster_locked", false)), "countdown cannot be canceled to unlock this Game Roster"):
		return false
	return true

func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	printerr("[AI_LOBBY_ROSTER_TEST][FAIL] %s" % description)
	quit(1)
	return false
