extends CharacterBody3D

signal new_velocity

@export_subgroup("Properties")
@export var max_ground_speed := 13.0
@export var acceleration := 50.5
@export var floor_drag := 40.0

@export var air_acceleration := 10.5
@export var air_drag := 0.0

@export var gravity_acceleration := 25.0 #9.8
@export var terminal_velocity := 40.0

@export var jump_strength := 12.0
@export var coyote_seconds := 0.1
@export var wall_coyote_seconds := 0.1
@export var jump_queue_seconds := 0.5 

@export var wall_climb_speed := 1.0

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

var was_on_floor_last_frame := false
var most_recent_wall
var most_recent_jump_time := 0.0
var jump_cooldown = coyote_seconds


@export var has_double_jump := true 
# This is exported so killing enemies can refresh doublejump. Maybe instead have a "touched ground" signal that updates abilities to refresh.
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
@onready var watching = $Watching
@onready var was_on_floor_watch = watching.watch_condition(is_on_floor, coyote_seconds)
@onready var was_on_wall_watch = watching.watch_condition(is_on_wall, wall_coyote_seconds)

@export var crosshair:TextureRect

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	weapon = weapons[weapon_index] # Weapon must never be nil
	initiate_change_weapon(weapon_index)


func _physics_process(delta):
	movement_velocity = get_real_velocity() # else you could have high "velocity" while running into a wall or falling into the ground.
	if is_on_wall():
		most_recent_wall = get_slide_collision(0)
	
	handle_controls(delta)
	
	if is_on_floor() or is_on_wall():
		# refresh abilities
		has_double_jump = true
		has_roo_reverse = true
	
	# apply gravity and lock to terminal velocity
	movement_velocity.y = clamp( movement_velocity.y - gravity_acceleration * delta, -terminal_velocity, terminal_velocity)
	
	# Movement
	var applied_velocity: Vector3
	
	applied_velocity = movement_velocity # velocity.lerp(movement_velocity, delta*10) # minor smoothing I guess. Doesn't seem needed.
	
	was_on_floor_last_frame = is_on_floor() # must be before move_and_slide
	
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
	
	if is_on_floor() and not was_on_floor_last_frame: # Just landed
		Audio.play("sounds/land.ogg")
		camera.position.y = -0.1
	
	# Falling/respawning
	if position.y < -150:
		get_tree().reload_current_scene()
	
	emit_signal("new_velocity", velocity)

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
	# veer seems to add a lot of deceleration. Even with 0 air drag, quickly slowed to a low base speed ~10
	var veer = 0;

	if is_on_floor() and was_on_floor_last_frame:# watching.was_true(was_on_floor_watch, 0.1): #meant to facilitate bhopping
		source_engine_braking(_delta, floor_drag)
		
		var horizontal_velocity = Vector2(movement_velocity.x, movement_velocity.z)
		if horizontal_velocity.length() > max_ground_speed:
			print("Overspeed", horizontal_velocity.length())
			horizontal_velocity = horizontal_velocity.lerp(horizontal_velocity.normalized() * max_ground_speed, 10*_delta)
			print("after lerp", horizontal_velocity)
			movement_velocity = Vector3(horizontal_velocity[0], movement_velocity.y, horizontal_velocity[1])
			
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

	if is_on_wall() and not is_on_floor() and input_vector.length() > 0.1 and not Input.is_action_pressed("control"):
		var wall_normal = most_recent_wall.get_normal()
		# wall climb, if facing directly at wall and looking up
		
		var up_down_look_angle = camera.global_basis.z.normalized().y # -1 is up, 1 is down
		if Input.is_action_pressed("move_forward") and wall_normal.dot(input_vector) < -0.5 and up_down_look_angle < 0:
			movement_velocity.y += -up_down_look_angle * wall_climb_speed

		# wall run
		var wall_velocity = most_recent_wall.get_remainder()
		var slide_velocity = movement_velocity.slide(wall_normal)
		movement_velocity = slide_velocity + wall_velocity - wall_normal

		movement_velocity.y = max(movement_velocity.y, 0) # consider making it run upwards first and accelerate downwards, like a jump with low grav, so you arc on the wall.
	
	handle_jumping(input_vector)
				
	if Input.is_action_just_pressed("F"):
		if has_roo_reverse:
			movement_velocity = -movement_velocity
			has_roo_reverse = false
	
	# Crouching
	if Input.is_action_just_pressed("control"):
		movement_velocity.x = 0
		movement_velocity.z = 0
		if not is_on_floor():
			movement_velocity.y = -terminal_velocity
	
	action_weapon_toggle()

func source_engine_braking(_delta, braking_decel: float):	
	if braking_decel > 0.0:	
		braking_decel = clamp(braking_decel, 0, movement_velocity.length() / _delta)
		var decel_vector = movement_velocity.normalized() * braking_decel * _delta
		movement_velocity -= decel_vector

func handle_jumping(input_vector):
	var time_since_most_recent_jump = Time.get_ticks_msec()/1000.0 - most_recent_jump_time
	var still_on_cooldown = time_since_most_recent_jump < jump_cooldown
	
	if not Input.is_action_pressed("jump") or still_on_cooldown:
		return
	
	var was_on_floor = watching.was_true(was_on_floor_watch, coyote_seconds)
	var was_on_wall = watching.was_true(was_on_wall_watch, wall_coyote_seconds)
	
	var is_in_air = not was_on_floor and not was_on_wall
	
	if not is_in_air:
		do_jump(input_vector)
	elif has_double_jump and Input.is_action_just_pressed("jump"):
		# Holding jump is enough for bhopping, but pressing jump is needed for airjumps
		has_double_jump = false
		do_jump(input_vector)

func do_jump(input_vector):
	most_recent_jump_time = Time.get_ticks_msec()/1000.0
	Audio.play("sounds/jump_a.ogg, sounds/jump_b.ogg, sounds/jump_c.ogg")
	
	# redirect horizontal_velocity momentum to have same length but be in input direction
	var horizontal_velocity = Vector2(movement_velocity.x, movement_velocity.z)
	horizontal_velocity = horizontal_velocity.length() * input_vector
	movement_velocity = Vector3(horizontal_velocity.x, jump_strength, horizontal_velocity.z)

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
