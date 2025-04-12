extends Node2D

@export var shape_scene: PackedScene
@export var launch_speed: float = 600.0
@export var cooldown_time: float = 0.5

var current_shape: RigidBody2D = null
var can_launch: bool = true
var cooldown_timer: float = 0.0
var aim_distance: float = 60.0
var aim_line_length: float = 60.0

func _ready():
	spawn_new_shape()

func _process(delta):
	if cooldown_timer > 0:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_launch = true
	
	update_aim_direction()
	
	if Input.is_action_just_pressed("fire") and can_launch and current_shape:
		launch_shape()

func update_aim_direction():
	var mouse_pos = get_viewport().get_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	$LauncherDirection.rotation = direction.angle()
	
	if current_shape:
		current_shape.position = direction * aim_distance
		current_shape.rotation = direction.angle() + PI/2

func spawn_new_shape():
	if not shape_scene:
		return
		
	current_shape = shape_scene.instantiate()
	current_shape.freeze = true
	current_shape.position = Vector2(0, -aim_distance)
	add_child(current_shape)

func launch_shape():
	if not current_shape:
		return
		
	can_launch = false
	cooldown_timer = cooldown_time
	
	var launch_direction = (current_shape.position - global_position).normalized()
	
	current_shape.freeze = false
	current_shape.linear_velocity = launch_direction * launch_speed
	
	var launched_shape = current_shape
	current_shape = null
	
	# Immediately spawn a new shape
	spawn_new_shape()
	
	# Apply a little rotation to make it more dynamic
	launched_shape.angular_velocity = randf_range(-2, 2)
