extends Node2D  

var launch_sound
var cooldown_timer
var launcher_direction
var trajectory_sprite

var shape_scene = preload("res://scenes/Shape.tscn")
var current_shape = null
var can_launch = true
var cooldown_time = 1.0
var trajectory_points = 10
var trajectory_length = 300
var launch_speed = 1200.0
var reticle_visible = true
var last_shape_type = -1
var last_shape_color = -1
var max_aim_distance = 500.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	setup_required_nodes()
	
	for child in get_children():
		if child is Line2D:
			child.visible = false
			child.queue_free()
	
	spawn_shape()
	create_aim_indicator()
	
	if current_shape:
		current_shape.position = position

func setup_required_nodes():
	launch_sound = get_node_or_null("LaunchSound")
	if not launch_sound:
		launch_sound = AudioStreamPlayer.new()
		launch_sound.name = "LaunchSound"
		var sound_stream = preload("res://assets/sounds/launch.wav") if ResourceLoader.exists("res://assets/sounds/launch.wav") else null
		if sound_stream:
			launch_sound.stream = sound_stream
		add_child(launch_sound)
	
	cooldown_timer = get_node_or_null("CooldownTimer")
	if not cooldown_timer:
		cooldown_timer = Timer.new()
		cooldown_timer.name = "CooldownTimer"
		cooldown_timer.one_shot = true
		cooldown_timer.wait_time = cooldown_time
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
		add_child(cooldown_timer)
	
	launcher_direction = get_node_or_null("LauncherDirection")
	if not launcher_direction:
		launcher_direction = Node2D.new()
		launcher_direction.name = "LauncherDirection"
		
		var line = Line2D.new()
		line.points = [Vector2.ZERO, Vector2(0, -30)]
		line.width = 2.0
		line.default_color = Color(1, 1, 1, 0.5)
		launcher_direction.add_child(line)
		
		add_child(launcher_direction)

func create_aim_indicator():
	var existing_line = get_node_or_null("TrajectoryLine")
	if existing_line:
		existing_line.queue_free()
	
	var existing_indicator = get_node_or_null("TrajectorySprite")
	if existing_indicator:
		existing_indicator.queue_free()
		
	trajectory_sprite = Node2D.new()
	trajectory_sprite.name = "TrajectorySprite"
	trajectory_sprite.z_index = 1000
	add_child(trajectory_sprite)
	
	var line = Line2D.new()
	line.name = "AimLine"
	line.width = 3
	line.default_color = Color(0.5, 0.5, 0.5, 0.6)
	line.z_index = 1000
	line.points = [Vector2.ZERO, Vector2(0, 500)]
	trajectory_sprite.add_child(line)

func update_aim_direction():
	if not is_instance_valid(trajectory_sprite):
		create_aim_indicator()
		return
		
	trajectory_sprite.visible = true
	
	var mouse_pos = get_global_mouse_position()
	var launch_position = global_position + Vector2(0, -30)
	
	if mouse_pos.y > launch_position.y:
		mouse_pos.y = launch_position.y
	
	var direction = (mouse_pos - launch_position).normalized()
	var distance = min(launch_position.distance_to(mouse_pos), max_aim_distance)
	
	trajectory_sprite.global_position = launch_position
	
	var line = trajectory_sprite.get_node_or_null("AimLine")
	if line:
		line.points = [Vector2.ZERO, direction * distance]

func _process(delta):  
	if current_shape and is_instance_valid(current_shape) and !current_shape.has_launched:
		current_shape.global_position = global_position
	
	if !current_shape or !is_instance_valid(current_shape):
		spawn_shape()
	
	if not trajectory_sprite:
		create_aim_indicator()
	
	update_aim_direction()
	
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	if launcher_direction:
		launcher_direction.rotation = direction.angle() + PI/2

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			launch_shape()

func launch_shape():
	if !can_launch or !current_shape:
		return
	
	var mouse_pos = get_global_mouse_position()
	var launch_position = global_position + Vector2(0, -30)
	var direction = (mouse_pos - launch_position).normalized()
	
	var shape = current_shape
	if shape:
		shape.global_transform = Transform2D(0, launch_position)
		
		shape.apply_central_impulse(direction * launch_speed * 5)
		shape.linear_velocity = direction * launch_speed * 2
		
		var rotation_direction = 1 if randf_range(-1, 1) > 0 else -1
		var rotation_speed = randf_range(5, 10) * rotation_direction
		shape.angular_velocity = rotation_speed
		
		shape.set_launched(true)
		
		if launch_sound:
			launch_sound.pitch_scale = 1.0
			launch_sound.play()
	
	can_launch = false
	current_shape = null
	
	if cooldown_timer:
		cooldown_timer.start(cooldown_time)
	
	spawn_shape_immediate()

func spawn_shape_immediate():
	var shape = shape_scene.instantiate()
	
	var new_type = randi() % 3
	while new_type == last_shape_type:
		new_type = randi() % 3
	
	var new_color = randi() % 6
	while new_color == last_shape_color:
		new_color = randi() % 6
	
	shape.shape_type = new_type
	shape.color = new_color
	
	last_shape_type = new_type
	last_shape_color = new_color
	
	add_child(shape)
	shape.scale = Vector2(0.9, 0.9)
	shape.z_index = 5
	current_shape = shape
	
	shape.add_to_group("launcher_shapes")
	
	return shape

func spawn_shape():
	can_launch = true
	if is_instance_valid(current_shape):
		return current_shape
	
	return spawn_shape_immediate()

func _on_cooldown_timer_timeout():
	can_launch = true
