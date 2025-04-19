extends Node2D  

@export var shape_scene: PackedScene = preload("res://scenes/Shape.tscn")
@export var launch_speed: float = 500.0  
@export var cooldown_time: float = 1.5  

var current_shape: Node = null  
var can_launch: bool = true  
var cooldown_timer: float = 0.0  
var aim_direction: Vector2 = Vector2.UP  
var multi_shot_count: int = 1
var trajectory_line: Line2D
var trajectory_time: float = 0.0
var max_trajectory_length: float = 500.0

func _ready():  
	current_shape = null
	can_launch = true
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	multi_shot_count = 2
	print("LAUNCHER INIT: Setting multi_shot_count to 2")
	
	var gc = get_node_or_null("/root/MainNew/GameController")
	if gc and "upgrades" in gc and "multi_shot" in gc.upgrades:
		if gc.upgrades["multi_shot"] >= 2:
			multi_shot_count = gc.upgrades["multi_shot"]
	print("LAUNCHER INIT: multi_shot_count initialized to:", multi_shot_count)
	
	for child in get_children():
		if child is Line2D:
			child.visible = false
			child.queue_free()
		elif "Trajectory" in child.name or "Line" in child.name:
			child.visible = false
			child.queue_free()
	
	trajectory_line = Line2D.new()
	trajectory_line.name = "TrajectoryPointer"
	trajectory_line.width = 3.0
	trajectory_line.default_color = Color(0.6, 0.6, 0.6, 0.5)
	trajectory_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trajectory_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trajectory_line)
	
	call_deferred("spawn_shape_instantly")
	
	if not SignalBus.upgrades_changed.is_connected(_on_upgrades_changed):
		SignalBus.upgrades_changed.connect(_on_upgrades_changed)

func _process(delta):  
	if not can_launch:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_launch = true
	
	trajectory_time += delta * 2.0
	
	var dir_line = get_node_or_null("LauncherDirection")
	if dir_line:
		dir_line.visible = false
		
	var reticle = get_node_or_null("LauncherReticle")
	if reticle:
		reticle.visible = false
	
	aim_direction = (get_global_mouse_position() - global_position).normalized()
	
	update_trajectory(delta)
	
	if not current_shape or not is_instance_valid(current_shape):
		spawn_shape_instantly()
	
	if Input.is_action_just_pressed("fire"):
		if can_launch and current_shape != null:
			launch_shape()

func update_trajectory(_delta):
	var mouse_distance = global_position.distance_to(get_global_mouse_position())
	var line_length = min(mouse_distance * 0.9, max_trajectory_length)
	
	var points = []
	var pos = Vector2.ZERO
	
	points.append(pos)
	pos += aim_direction * line_length
	points.append(pos)
	
	trajectory_line.points = points
	
	var pulse_alpha = 0.3 + 0.2 * sin(trajectory_time * 2.0)
	trajectory_line.default_color = Color(0.6, 0.6, 0.6, pulse_alpha)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if can_launch and current_shape != null:
				launch_shape()

func _on_upgrades_changed(upgrades):
	print("LAUNCHER: Received upgrades: ", upgrades)
	
	if "multi_shot" in upgrades:
		multi_shot_count = upgrades["multi_shot"]
	else:
		multi_shot_count = 2
	
	print("LAUNCHER: multi_shot_count is now: ", multi_shot_count)
	
	var launch_speed_level = upgrades.get("launch_speed", 0)
	launch_speed = 350.0 + (launch_speed_level * 50.0)
	
	var cooldown_level = upgrades.get("cooldown", 0)
	cooldown_time = max(0.1, 0.5 - (cooldown_level * 0.05))
	
	print("LAUNCHER: Final values - multi_shot: ", multi_shot_count, ", speed: ", launch_speed, ", cooldown: ", cooldown_time)

func launch_shape():
	if not can_launch or not current_shape or not is_instance_valid(current_shape):
		return
		
	var shape = current_shape
	current_shape = null
	
	shape.freeze = false
	shape.launched = true
	shape.has_launched = true
	shape.gravity_scale = 0.3
	
	var impulse = aim_direction * launch_speed
	shape.linear_velocity = impulse
	shape.apply_central_impulse(impulse)
	
	print("Launching shapes. multi_shot_count = ", multi_shot_count)
	
	if multi_shot_count >= 2:
		var additional_shots = multi_shot_count - 1
		print("Additional shots: ", additional_shots)
		for i in range(additional_shots):
			var new_shape = shape_scene.instantiate()
			if new_shape:
				new_shape.shape_type = randi() % 3
				new_shape.color = randi() % 6
				get_parent().add_child(new_shape)
				new_shape.position = global_position
				
				new_shape.freeze = false
				new_shape.launched = true
				new_shape.has_launched = true
				new_shape.gravity_scale = 0.3
				
				var angle_offset = randf_range(-0.3, 0.3)
				var new_impulse = impulse.rotated(angle_offset) 
				new_shape.linear_velocity = new_impulse
				new_shape.apply_central_impulse(new_impulse)
				
				print("Created additional shape ", i+1, " of ", additional_shots)
	
	can_launch = false
	cooldown_timer = cooldown_time
	
	SignalBus.emit_shape_launched(shape)
	
	call_deferred("spawn_shape_instantly")

func spawn_shape_instantly():
	if current_shape and is_instance_valid(current_shape):
		return
		
	var shape = shape_scene.instantiate() 
	if shape:
		shape.shape_type = randi() % 3
		shape.color = randi() % 6
		get_parent().add_child(shape)
		shape.position = global_position
		current_shape = shape
