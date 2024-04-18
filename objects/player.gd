extends CharacterBody3D

@export_subgroup("Properties")
#@export var max_movement_speed := 15.0
@export var acceleration := 70.5
@export var floor_drag := 40.0

@export var air_acceleration := 20.5
@export var air_drag := 0.0

@export var gravity_acceleration := 25.0 #9.8
@export var terminal_velocity := 40.0

@export var jump_strength := 15.0
@export var coyote_seconds := 0.2
@export var jump_queue_seconds := 0.5 

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

var weapon: Weapon
var weapon_index := 0

var mouse_sensitivity = 700
var gamepad_sensitivity := 0.075

var mouse_captured := true

var movement_velocity: Vector3
var rotation_target: Vector3

var input_mouse: Vector2

var was_on_floor := false

var has_double_jump := true
var has_roo_reverse := true

var container_offset = Vector3(1.2, -1.1, -2.75)

var tween:Tween

signal health_updated

@onready var camera = $Head/Camera
@onready var raycast = $Head/Camera/RayCast
@onready var muzzle = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var sound_footsteps = $SoundFootsteps
@onready var blaster_cooldown = $Cooldown

@export var crosshair:TextureRect

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	weapon = weapons[weapon_index] # Weapon must never be nil
	initiate_change_weapon(weapon_index)

func _physics_process(delta):
	movement_velocity = get_real_velocity() # else you could have high "velocity" while running into a wall or falling into the ground.
	
	handle_controls(delta)
	
	if is_on_floor():
		# refresh abilities
		has_double_jump = true
		has_roo_reverse = true
		
		movement_velocity.y = max(movement_velocity.y, 0.0)
	
	movement_velocity.y = clamp( movement_velocity.y - gravity_acceleration * delta, -terminal_velocity, terminal_velocity)
	
	
	# Movement
	var applied_velocity: Vector3
	
	applied_velocity = movement_velocity # velocity.lerp(movement_velocity, delta*10) # minor smoothing I guess. Doesn't seem needed.
	
	velocity = applied_velocity
	move_and_slide()
	
	# Rotation
	camera.rotation.z = lerp_angle(camera.rotation.z, -input_mouse.x * 25 * delta, delta * 5)	
	
	camera.rotation.x = lerp_angle(camera.rotation.x, rotation_target.x, delta * 25)
	rotation.y = lerp_angle(rotation.y, rotation_target.y, delta * 25)
	
	container.position = lerp(container.position, container_offset - (applied_velocity / 30), delta * 10)
	
	# Movement sound
	sound_footsteps.stream_paused = true
	
	if is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			sound_footsteps.stream_paused = false
	
	# Landing
	camera.position.y = lerp(camera.position.y, 0.0, delta * 5)
	
	if is_on_floor() and not was_on_floor: # Just landed
		Audio.play("sounds/land.ogg")
		camera.position.y = -0.1
	
	was_on_floor = is_on_floor()
	
	# Falling/respawning
	if position.y < -150:
		get_tree().reload_current_scene()

# Mouse movement

func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		input_mouse = event.relative / mouse_sensitivity
		
		rotation_target.y -= event.relative.x / mouse_sensitivity
		rotation_target.x -= event.relative.y / mouse_sensitivity

func handle_controls(_delta):
	# Mouse capture
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		
		input_mouse = Vector2.ZERO
	
	# Movement
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_vector = Vector3(input.x, 0, input.y).normalized()
	input_vector = transform.basis * input_vector # turn in direction of camera
	
	var temp_y = movement_velocity.y # keep y unchanged by was movement

	# source engine uses this but im not sure whats the point	
	#var veer = movement_velocity.x*input_vector.x + movement_velocity.z*input_vector.z
	var veer = 0;

	if is_on_floor():
		source_engine_braking(_delta, floor_drag)
		#movement_velocity = lerp(movement_velocity, input_vector * max_movement_speed, acceleration * _delta / max_movement_speed)
		movement_velocity += input_vector * (acceleration-veer) * _delta
	else:
		source_engine_braking(_delta, air_drag)
		movement_velocity += input_vector * (air_acceleration-veer) * _delta
		
	movement_velocity.y = temp_y
		
	# Rotation
	var rotation_input := Input.get_vector("camera_right", "camera_left", "camera_down", "camera_up")
	
	rotation_target -= Vector3(-rotation_input.y, -rotation_input.x, 0).limit_length(1.0) * gamepad_sensitivity
	rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
	

	action_shoot()

	# wall running
	if is_on_wall():
		var wall_normal = get_slide_collision(0).get_normal()
		var wall_velocity = get_slide_collision(0).get_remainder()
		var slide_velocity = movement_velocity.slide(wall_normal)
		movement_velocity = slide_velocity + wall_velocity - wall_normal

		movement_velocity.y = max(movement_velocity.y, 0) # consider making it run upwards first and accelerate downwards, like a jump with low grav, so you arc on the wall.

	print(is_on_floor(), " ", is_on_wall())
	
	# Jumping	
	if Input.is_action_just_pressed("jump"):
		var is_double_jump = not is_on_floor() and not is_on_wall()
		
		if has_double_jump or not is_double_jump:
			Audio.play("sounds/jump_a.ogg, sounds/jump_b.ogg, sounds/jump_c.ogg")
			movement_velocity.y = jump_strength;
			# redirect horizontal momentum to have same length but be in input direction
			var horizontal_momentum = Vector3(movement_velocity.x, 0, movement_velocity.z)
			horizontal_momentum = horizontal_momentum.length() * input_vector
			movement_velocity = Vector3(horizontal_momentum.x, movement_velocity.y, horizontal_momentum.z)
		
		if is_double_jump:
			has_double_jump = false
				
	if Input.is_action_just_pressed("F"):
		if has_roo_reverse:
			movement_velocity = -movement_velocity
			has_roo_reverse = false
	
	# Crouching
	if Input.is_action_just_pressed("control"):
		if not is_on_floor():
			movement_velocity.y = -terminal_velocity
	
	action_weapon_toggle()

func source_engine_braking(_delta, braking_decel: float):	
	braking_decel = clamp(braking_decel, 0, movement_velocity.length() / _delta)
	var decel_vector = movement_velocity.normalized() * braking_decel * _delta
	movement_velocity -= decel_vector

# Shooting
func action_shoot():
	if Input.is_action_pressed("shoot"):
	
		if !blaster_cooldown.is_stopped(): return # Cooldown for shooting
		
		Audio.play(weapon.sound_shoot)
		
		#container.position.z += 0.25 # Knockback of weapon visual
		#camera.rotation.x += 0.025 # Knockback of camera
		
		var knockback = camera.global_basis.z.normalized() * weapon.knockback
		movement_velocity += knockback
		
		muzzle.play("default")
		muzzle.rotation_degrees.z = randf_range(-45, 45)
		muzzle.scale = Vector3.ONE * randf_range(0.40, 0.75)
		muzzle.position = container.position - weapon.muzzle_position
		
		blaster_cooldown.start(weapon.cooldown)
		
		# Shoot the weapon, amount based on shot count
		for n in weapon.shot_count:
			raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
			raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
			raycast.force_raycast_update()
			if !raycast.is_colliding(): continue # Don't create impact when raycast didn't hit
			var collider = raycast.get_collider()
			
			# Hitting an enemy
			if collider.has_method("damage"):
				collider.damage(weapon.damage)
			
			# Creating an impact animation
			var impact = preload("res://objects/impact.tscn")
			var impact_instance = impact.instantiate()
			
			impact_instance.play("shot")
			
			var tree = get_tree()
			if tree:
				tree.root.add_child(impact_instance)
			
			impact_instance.position = raycast.get_collision_point() + (raycast.get_collision_normal() / 10)
			impact_instance.look_at(camera.global_transform.origin, Vector3.UP, true) 

func action_weapon_toggle():
	if Input.is_action_just_pressed("weapon_toggle"):
		
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		
		Audio.play("sounds/weapon_change.ogg")

# Initiates the weapon changing animation (tween)
func initiate_change_weapon(index):
	weapon_index = index	
	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon) # Changes the model

# Switches the weapon model (off-screen)
func change_weapon():
	weapon = weapons[weapon_index]

	# Step 1. Remove previous weapon model(s) from container
	for n in container.get_children():
		container.remove_child(n)
	
	# Step 2. Place new weapon model in container
	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)
	
	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	
	# Step 3. Set model to only render on layer 2 (the weapon camera)
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
		
	# Set weapon data
	raycast.target_position = Vector3(0, 0, -1) * weapon.max_distance
	crosshair.texture = weapon.crosshair
