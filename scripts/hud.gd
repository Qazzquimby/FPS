extends CanvasLayer

var elapsed_time := 0.0;

@onready var timer_label = $TimerLabel
@onready var speed_label = $SpeedLabel
#@onready var player = $Player

func _ready():
	get_node("../Player").connect("new_velocity", _update_speed)

func _update_speed(new_speed):
	var horizontal_speed = Vector2(new_speed.x, new_speed.z)
	speed_label.text = "%02.1f" % [horizontal_speed.length()]

func _process(delta):
	elapsed_time += delta
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	var milliseconds = int((elapsed_time - int(elapsed_time)) * 1000)
	timer_label.text = "%02d:%02d:%03d" % [minutes, seconds, milliseconds]
	
		
