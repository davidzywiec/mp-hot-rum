extends PanelContainer

class_name PlayerCard

@onready
var username_label : Label = $Label

const MDTheme: GDScript = preload("res://scripts/ui/morning_digest_theme.gd")

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
	style.bg_color = MDTheme.BG_CARD
	style.border_color = MDTheme.ACCENT_GREEN if _ready_state else MDTheme.ACCENT_RED
	style.set_border_width_all(2)
	style.corner_radius_top_left = MDTheme.RADIUS_CARD
	style.corner_radius_top_right = MDTheme.RADIUS_CARD
	style.corner_radius_bottom_right = MDTheme.RADIUS_CARD
	style.corner_radius_bottom_left = MDTheme.RADIUS_CARD
	style.shadow_color = MDTheme.ACCENT_GREEN_BG if _ready_state else MDTheme.ACCENT_RED_BG
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)

	if username_label != null:
		username_label.add_theme_color_override("font_color", MDTheme.TEXT_PRIMARY)
