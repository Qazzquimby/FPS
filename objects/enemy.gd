extends Node3D

@export var player: Node3D

@onready var raycast = $RayCast
@onready var muzzle_a = $MuzzleA
@onready var muzzle_b = $MuzzleB

var health := 100
var time := 0.0
var target_position: Vector3
var destroyed := false

# When ready, save the initial position


func _ready():
	target_position = position


func _process(delta):
	self.look_at(player.position + Vector3(0, 0.5, 0), Vector3.UP, true)  # Look at player
	target_position.y += (cos(time * 5) * 1) * delta  # Sine movement (up and down)

	time += delta

	position = target_position

	if position.distance_to(player.position) < 1.5:
		destroy()

func damage(_amount):
	player.has_double_jump = true
	if (_amount > 0):
		destroy()


func destroy():
	Audio.play("sounds/enemy_destroy.ogg")

	destroyed = true
	queue_free()


