extends Node

func _ready() -> void:
	var args := OS.get_cmdline_args()
	var is_headless := DisplayServer.get_name() == "headless"
	var is_server_feature := OS.has_feature("server") or OS.has_feature("dedicated_server")
	var forced_server := args.has("--server")
	if not (is_server_feature or is_headless or forced_server):
		printerr("Dedicated server scene run without server/headless; quitting.")
		get_tree().quit()
		return
	Network_Manager.start_server()
