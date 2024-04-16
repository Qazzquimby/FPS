extends CanvasLayer

var elapsed_time := 0.0;

@onready var timer_label = $TimerLabel

func _process(delta):
	elapsed_time += delta
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	var milliseconds = int((elapsed_time - int(elapsed_time)) * 1000)
	timer_label.text = "%02d:%02d:%03d" % [minutes, seconds, milliseconds]
