extends Node

func _ready() -> void:
	if not OS.has_feature("server"):
		printerr("Dedicated server scene run without server feature; quitting.")
		get_tree().quit()
		return
	Network_Manager.start_server()