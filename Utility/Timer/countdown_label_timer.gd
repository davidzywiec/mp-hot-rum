class_name CountDownLabelTimer
extends Label

@onready var timer: Timer = $Timer

var label_text: String = "Default placeholder"
var timer_countdown: float = 5.0

func _ready() -> void:
	setup_timer()

func _physics_process(delta: float) -> void:
	set_label_text()
	
func start_timer() -> void:
	timer.start()

func stop_timer() -> void:
	timer.stop()
	
func get_time_remaining() -> float:
	return timer.time_left
	
func setup_timer() -> void:
	timer.wait_time = timer_countdown
	set_label_text()
	
func set_label_text() -> void:
	if timer.is_stopped():
		self.text = "%s %d" % [label_text, timer.wait_time]
	else:
		self.text = "%s %d" % [label_text, timer.time_left]

func configure(text: String, countdown: float) -> void:
	label_text = text
	timer_countdown = countdown
	if is_inside_tree(): # ready already ran
		setup_timer()
