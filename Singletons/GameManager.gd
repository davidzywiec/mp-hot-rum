extends Node

func _ready():
	var args = OS.get_cmdline_args()
	
	if "--server" in args:
		SignalManager.start_server.emit()
	elif "--client" in args:
		SignalManager.join_server.emit()
