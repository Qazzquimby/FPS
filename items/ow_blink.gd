extends Item

@export var distance = 5
@export var height_gain = 1
@export var max_blinks = 3

var current_blinks = max_blinks

func run_physics_process(_delta, player):
	if Input.is_action_just_pressed("M2"):
		if current_blinks > 0:
			current_blinks -= 1
			
			Audio.play("sounds/tracer_blink.ogg")
			var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			var input_vector = Vector3(input.x, 0, input.y).normalized()
			if input_vector == Vector3.ZERO:
				input_vector = Vector3(0, 0, -1)
			
			var rotated_to_facing = player.transform.basis * input_vector
			player.position += rotated_to_facing * distance
			
			player.position.y += height_gain
			player.movement_velocity.y = 0
			
			# if player has momentum opposite of the blink direction, cancel that part of the momentum (not all momentum, sideways is fine)
			if player.movement_velocity.dot(rotated_to_facing) < 0:
				var momentum_opposite_blink = player.movement_velocity.dot(rotated_to_facing)
				player.movement_velocity -= momentum_opposite_blink * rotated_to_facing
			


func _on_player_touch_surface():
	current_blinks = max_blinks
