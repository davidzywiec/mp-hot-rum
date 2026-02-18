extends Resource
class_name CardPointRules

@export_range(0, 100, 1) var ace_points: int = 15
@export_range(0, 100, 1) var two_points: int = 20
@export_range(0, 100, 1) var three_to_nine_points: int = 5
@export_range(0, 100, 1) var ten_to_king_points: int = 10

func get_points_for_number(number: int) -> int:
	if number == 1:
		return ace_points
	if number == 2:
		return two_points
	if number >= 3 and number <= 9:
		return three_to_nine_points
	if number >= 10 and number <= 13:
		return ten_to_king_points
	return 0
