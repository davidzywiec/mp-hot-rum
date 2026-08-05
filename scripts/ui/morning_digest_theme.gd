class_name MorningDigestTheme
extends RefCounted

const BG_PAGE := Color(0.953, 0.949, 0.929, 1.0)
const BG_CARD := Color(1.0, 1.0, 1.0, 1.0)
const BG_ROW_HOVER := Color(0.973, 0.973, 0.976, 1.0)
const BORDER_DEFAULT := Color(0.878, 0.878, 0.882, 1.0)
const BORDER_STRONG := Color(0.800, 0.800, 0.808, 1.0)
const TEXT_PRIMARY := Color(0.173, 0.173, 0.180, 1.0)
const ACCENT_BLUE := Color(0.290, 0.620, 1.0, 1.0)
const ACCENT_BLUE_BG := Color(0.780, 0.882, 1.0, 0.35)
const ACCENT_BLUE_BORDER := Color(0.475, 0.710, 1.0, 0.5)
const ACCENT_GREEN := Color(0.110, 0.620, 0.360, 1.0)
const ACCENT_GREEN_BG := Color(0.750, 0.930, 0.830, 0.35)
const ACCENT_RED := Color(0.830, 0.230, 0.250, 1.0)
const ACCENT_RED_BG := Color(1.0, 0.800, 0.800, 0.35)
const SHADOW_CARD := Color(0.0, 0.0, 0.0, 0.06)
const RADIUS_CARD := 12
const RADIUS_ITEM := 6

static func apply_button(button: Button, font_size: int = 13) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", make_button_style(BG_ROW_HOVER, BORDER_DEFAULT))
	button.add_theme_stylebox_override("hover", make_button_style(Color(0.937, 0.937, 0.941, 1.0), BORDER_STRONG))
	button.add_theme_stylebox_override("pressed", make_button_style(Color(0.914, 0.914, 0.918, 1.0), BORDER_STRONG))
	button.add_theme_stylebox_override("focus", make_focus_style())
	button.add_theme_stylebox_override("disabled", make_button_style(Color(0.945, 0.945, 0.949, 1.0), BORDER_DEFAULT))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color(0.110, 0.110, 0.118, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.110, 0.110, 0.118, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.600, 0.600, 0.608, 1.0))
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 6)

static func apply_line_edit(line_edit: LineEdit, font_size: int = 13) -> void:
	if line_edit == null:
		return
	line_edit.add_theme_stylebox_override("normal", make_input_style(BG_ROW_HOVER, BORDER_STRONG))
	line_edit.add_theme_stylebox_override("focus", make_input_style(BG_CARD, ACCENT_BLUE, 2))
	line_edit.add_theme_stylebox_override("read_only", make_input_style(BG_ROW_HOVER, BORDER_DEFAULT))
	line_edit.add_theme_color_override("font_color", TEXT_PRIMARY)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.600, 0.600, 0.608, 1.0))
	line_edit.add_theme_color_override("font_selected_color", Color(0.110, 0.110, 0.118, 1.0))
	line_edit.add_theme_color_override("selection_color", Color(0.290, 0.620, 1.0, 0.25))
	line_edit.add_theme_color_override("caret_color", ACCENT_BLUE)
	line_edit.add_theme_font_size_override("font_size", font_size)

static func apply_rich_text_label(text_label: RichTextLabel, font_size: int = 14) -> void:
	if text_label == null:
		return
	text_label.add_theme_color_override("default_color", TEXT_PRIMARY)
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	text_label.add_theme_color_override("font_selected_color", Color(0.110, 0.110, 0.118, 1.0))
	text_label.add_theme_color_override("selection_color", Color(0.290, 0.620, 1.0, 0.25))
	text_label.add_theme_font_size_override("normal_font_size", font_size)
	text_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	text_label.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func apply_panel_container(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", make_panel_style())

static func make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_CARD
	style.border_color = BORDER_DEFAULT
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_CARD)
	style.shadow_color = SHADOW_CARD
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style

static func make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_ITEM)
	style.content_margin_left = 12
	style.content_margin_top = 6
	style.content_margin_right = 12
	style.content_margin_bottom = 6
	return style

static func make_input_style(bg: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(RADIUS_ITEM)
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	return style

static func make_focus_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.290, 0.620, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(RADIUS_ITEM + 1)
	return style
