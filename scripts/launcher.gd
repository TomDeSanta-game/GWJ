extends Node2D  

@onready var launch_sound = $LaunchSound
@onready var cooldown_timer = $CooldownTimer
@onready var cooldown_label = $CooldownLabel
@onready var launcher_direction = $LauncherDirection

var shape_scene = preload("res://scenes/Shape.tscn")
var current_shape = null
var can_launch = true
var cooldown_time = 1.0
var trajectory_points = 10
var trajectory_length = 300
var multi_shot_count = 1
var launch_speed = 350.0
var reticle_visible = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	for child in get_children():
		if child is Line2D:
			child.visible = false
			child.queue_free()
	
	if not SignalBus.upgrades_changed.is_connected(_on_upgrades_changed):
		SignalBus.upgrades_changed.connect(_on_upgrades_changed)
	
	spawn_shape()
	setup_trajectory_line()

func setup_trajectory_line():
	var line = Line2D.new()
	line.name = "TrajectoryLine"
	line.width = 3.0
	line.default_color = Color(1, 1, 1, 0.5)
	
	var arrow = Polygon2D.new()
	arrow.name = "TrajectoryArrow"
	arrow.color = Color(1, 1, 1, 0.5)
	arrow.polygon = PackedVector2Array([
		Vector2(0, -10),
		Vector2(20, 0),
		Vector2(0, 10)
	])
	
	add_child(line)
	add_child(arrow)
	update_trajectory_line()

func update_trajectory_line():
	var line = get_node_or_null("TrajectoryLine")
	var arrow = get_node_or_null("TrajectoryArrow")
	
	if not line or not arrow:
		return
	
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	var points = PackedVector2Array()
	var step = trajectory_length / trajectory_points
	
	for i in range(trajectory_points + 1):
		var point = global_position + direction * (step * i)
		points.append(point)
	
	line.points = points
	
	if points.size() > 1:
		arrow.position = points[points.size() - 1]
		arrow.rotation = direction.angle() + PI/2
	
	line.visible = reticle_visible
	arrow.visible = reticle_visible

func _process(delta):  
	if cooldown_timer and cooldown_timer.time_left > 0:
		if cooldown_label:
			cooldown_label.text = "%.1f" % cooldown_timer.time_left
	else:
		if cooldown_label:
			cooldown_label.text = ""
	
	if current_shape and !current_shape.has_launched:
		current_shape.position = position
	
	update_trajectory_line()
	
	# Update launcher direction
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	if launcher_direction:
		launcher_direction.rotation = direction.angle() + PI/2

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			launch_shape()
	
	if event is InputEventMouseMotion:
		reticle_visible = true
		update_trajectory_line()

func launch_shape():
	if !can_launch or !current_shape:
		return
		
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	for i in range(multi_shot_count):
		var shape = current_shape if i == 0 else spawn_shape_instantly()
		
		if shape:
			var launch_angle_spread = 0.1 * i
			var adjusted_direction = direction.rotated(launch_angle_spread if i % 2 == 0 else -launch_angle_spread)
			
			shape.apply_central_impulse(adjusted_direction * launch_speed)
			shape.set_launched(true)
			
			launch_sound.pitch_scale = 1.0 + (i * 0.1)
			launch_sound.play()
	
	can_launch = false
	cooldown_timer.start(cooldown_time)
	
	current_shape = null
	
	if !current_shape:
		get_tree().create_timer(cooldown_time * 0.5).timeout.connect(func(): spawn_shape())

func spawn_shape():
	var shape = shape_scene.instantiate()
	add_child(shape)
	shape.position = position
	current_shape = shape
	return shape

func spawn_shape_instantly():
	var shape = shape_scene.instantiate() 
	add_child(shape)
	shape.position = position
	shape.set_launched(true)
	return shape

func _on_cooldown_timer_timeout():
	can_launch = true

func _on_upgrades_changed(upgrades):
	multi_shot_count = 1 + (upgrades.get("multi_shot", 0))
	launch_speed = 350.0 + (upgrades.get("launch_power", 0) * 50.0)
	cooldown_time = max(0.2, 1.0 - (upgrades.get("cooldown", 0) * 0.15))
	if cooldown_timer:
		cooldown_timer.wait_time = cooldown_time
