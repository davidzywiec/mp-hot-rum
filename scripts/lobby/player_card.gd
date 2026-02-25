extends PanelContainer

class_name PlayerCard

@onready
var username_label : Label = $Label

const TILE_BG_COLOR := Color(0.102, 0.157, 0.239, 0.95)
const TILE_BORDER_COLOR := Color(0.168, 0.227, 0.329, 1.0)
const TILE_READY_BORDER_COLOR := Color(0.38, 0.84, 0.44, 1.0)
const TILE_READY_GLOW_COLOR := Color(0.28, 0.63, 0.33, 0.35)

var _ready_state: bool = false

func _ready() -> void:
	_apply_tile_style()

func set_username(username: String) -> void:
	username_label.text = username

func set_ready(ready_status: bool) -> void:
	_ready_state = ready_status
	_apply_tile_style()

func _apply_tile_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TILE_BG_COLOR
	style.border_color = TILE_READY_BORDER_COLOR if _ready_state else TILE_BORDER_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = TILE_READY_GLOW_COLOR if _ready_state else Color(0, 0, 0, 0.18)
	style.shadow_size = 8 if _ready_state else 4
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)

	if username_label != null:
		username_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98, 1.0))
