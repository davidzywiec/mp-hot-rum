extends PanelContainer
class_name CardView

const BASE_SIZE: Vector2 = Vector2(92.0, 132.0)
const BASE_CORNER_FONT_SIZE: int = 16
const BASE_CENTER_FONT_SIZE: int = 34
const BASE_MARGIN_SIDE: int = 8
const BASE_MARGIN_VERTICAL: int = 6

@onready var margin_container: MarginContainer = $Margin
@onready var rank_top_label: Label = $Margin/VB/TopRow/RankTop
@onready var suit_top_label: Label = $Margin/VB/TopRow/SuitTop
@onready var center_label: Label = $Margin/VB/Center
@onready var suit_bottom_label: Label = $Margin/VB/BottomRow/SuitBottom
@onready var rank_bottom_label: Label = $Margin/VB/BottomRow/RankBottom

var _card: Card
var _last_scale: float = 1.0

func _ready() -> void:
	_apply_style()
	apply_scale_ratio(_last_scale)
	_refresh_content()

func set_card(card: Card) -> void:
	_card = card
	_refresh_content()

func get_card() -> Card:
	return _card

func apply_scale_ratio(scale_ratio: float) -> void:
	var safe_scale: float = maxf(0.01, scale_ratio)
	_last_scale = safe_scale
	custom_minimum_size = BASE_SIZE * safe_scale

	# Child node refs are onready; skip theme overrides until the node is fully ready.
	if not is_node_ready():
		return
	if margin_container == null:
		return

	var side_margin: int = maxi(1, int(round(float(BASE_MARGIN_SIDE) * safe_scale)))
	var vertical_margin: int = maxi(1, int(round(float(BASE_MARGIN_VERTICAL) * safe_scale)))
	margin_container.add_theme_constant_override("margin_left", side_margin)
	margin_container.add_theme_constant_override("margin_right", side_margin)
	margin_container.add_theme_constant_override("margin_top", vertical_margin)
	margin_container.add_theme_constant_override("margin_bottom", vertical_margin)

	var corner_size: int = maxi(7, int(round(BASE_CORNER_FONT_SIZE * safe_scale)))
	var center_size: int = maxi(12, int(round(BASE_CENTER_FONT_SIZE * safe_scale)))
	rank_top_label.add_theme_font_size_override("font_size", corner_size)
	suit_top_label.add_theme_font_size_override("font_size", corner_size)
	center_label.add_theme_font_size_override("font_size", center_size)
	suit_bottom_label.add_theme_font_size_override("font_size", corner_size)
	rank_bottom_label.add_theme_font_size_override("font_size", corner_size)

func _refresh_content() -> void:
	if not is_node_ready() or _card == null:
		return

	var rank: String = _rank_text(_card.number)
	var suit: String = _suit_text(_card.suit)
	var color: Color = _suit_color(_card.suit)

	rank_top_label.text = rank
	suit_top_label.text = suit
	center_label.text = "%s %s" % [rank, suit]
	suit_bottom_label.text = suit
	rank_bottom_label.text = rank

	rank_top_label.modulate = color
	suit_top_label.modulate = color
	center_label.modulate = color
	suit_bottom_label.modulate = color
	rank_bottom_label.modulate = color

func _apply_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.98, 0.96)
	style.border_color = Color(0.1, 0.1, 0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

func _rank_text(number: int) -> String:
	match number:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		_:
			return str(number)

func _suit_text(suit: int) -> String:
	match suit:
		Card.Suit.HEARTS:
			return "H"
		Card.Suit.DIAMONDS:
			return "D"
		Card.Suit.CLUBS:
			return "C"
		Card.Suit.SPADES:
			return "S"
		_:
			return "?"

func _suit_color(suit: int) -> Color:
	match suit:
		Card.Suit.HEARTS, Card.Suit.DIAMONDS:
			return Color(0.76, 0.16, 0.2)
		_:
			return Color(0.08, 0.08, 0.08)
