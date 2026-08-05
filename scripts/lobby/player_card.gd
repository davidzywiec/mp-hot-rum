extends PanelContainer

class_name PlayerCard

@onready
var username_label : Label = $Label

const MDTheme: GDScript = preload("res://scripts/ui/morning_digest_theme.gd")
const TILE_READY_GLOW_COLOR := Color(0.290, 0.620, 1.0, 0.18)

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
	style.border_color = MDTheme.ACCENT_BLUE if _ready_state else MDTheme.BORDER_DEFAULT
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = MDTheme.RADIUS_CARD
	style.corner_radius_top_right = MDTheme.RADIUS_CARD
	style.corner_radius_bottom_right = MDTheme.RADIUS_CARD
	style.corner_radius_bottom_left = MDTheme.RADIUS_CARD
	style.shadow_color = TILE_READY_GLOW_COLOR if _ready_state else MDTheme.SHADOW_CARD
	style.shadow_size = 8 if _ready_state else 4
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)

	if username_label != null:
		username_label.add_theme_color_override("font_color", MDTheme.TEXT_PRIMARY)
