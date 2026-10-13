extends Node

const CONFIG_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"
const MASTER_VOLUME_KEY: String = "master_volume"

var master_volume: float = 1.0
var _save_timer: Timer

func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		master_volume = clampf(float(config.get_value(SETTINGS_SECTION, MASTER_VOLUME_KEY, 1.0)), 0.0, 1.0)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(_save)
	add_child(_save_timer)
	_apply_master_volume()

func get_master_volume() -> float:
	return master_volume

func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	_apply_master_volume()
	_save_timer.start()

func _apply_master_volume() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return
	AudioServer.set_bus_volume_linear(master_bus_index, master_volume)

func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(CONFIG_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load player settings before saving: %s" % error_string(load_error))
	config.set_value(SETTINGS_SECTION, MASTER_VOLUME_KEY, master_volume)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("Could not save player settings: %s" % error_string(save_error))
