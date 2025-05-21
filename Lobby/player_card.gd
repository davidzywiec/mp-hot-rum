extends ColorRect

class_name player_card

@onready
var username_label : Label = $Label

func set_username(username: String) -> void:
	username_label.text = username

func set_ready(ready_status: bool) -> void:
	if ready_status:
		self.color = '91ff81'
	else:
		self.color = 'ffffff'
