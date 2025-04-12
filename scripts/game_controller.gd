extends Node

@export var shape_scene: PackedScene
@export var spawn_timer: float = 1.5
@export var max_score_width: float = 300.0
@export var game_difficulty: float = 1.0

var score: int = 0
var is_game_over: bool = false
var enemy_speed: float = 80.0
var time_since_last_spawn: float = 0.0
var level_number: int = 1
var shapes_destroyed: int = 0
var shapes_for_next_level: int = 20
var backgrounds = [
	Color(0.7, 0.85, 1.0, 1), # Sky blue
	Color(0.5, 0.7, 0.9, 1),  # Deep blue
	Color(0.3, 0.5, 0.8, 1),  # Evening blue
	Color(0.2, 0.3, 0.6, 1),  # Night blue
	Color(0.1, 0.1, 0.2, 1)   # Night
]

func _ready() -> void:
	randomize()
	setup_input_map()
	connect_signals()
	spawn_initial_enemies()
	add_floating_clouds()
	setup_level_visuals(level_number)

func connect_signals() -> void:
	SignalBus.shapes_popped.connect(_on_shapes_popped)
	SignalBus.grid_game_over.connect(_on_game_over)
	SignalBus.score_changed.connect(update_score_display)

func spawn_initial_enemies() -> void:
	for i in range(5):
		spawn_enemy()

func _process(delta: float) -> void:
	if is_game_over:
		return
		
	handle_enemy_spawning(delta)
	update_difficulty(delta)

func handle_enemy_spawning(delta: float) -> void:
	time_since_last_spawn += delta
	if time_since_last_spawn >= spawn_timer / game_difficulty:
		spawn_enemy()
		time_since_last_spawn = 0.0

func update_difficulty(delta: float) -> void:
	game_difficulty += delta * 0.01
	enemy_speed = 80.0 + (game_difficulty * 20.0)
	
	# Check if we should advance to the next level
	if shapes_destroyed >= shapes_for_next_level:
		advance_level()

func advance_level() -> void:
	level_number += 1
	shapes_destroyed = 0
	shapes_for_next_level = 20 + (level_number * 5)
	
	# Update game visuals for new level
	setup_level_visuals(level_number)

func setup_level_visuals(level: int) -> void:
	# Update background gradient based on level
	var bg_index = min(level - 1, backgrounds.size() - 1)
	var background = $Background as TextureRect
	
	if background and background.texture:
		var gradient_texture = background.texture as GradientTexture2D
		if gradient_texture:
			var gradient = gradient_texture.gradient
			if bg_index < backgrounds.size():
				gradient.colors[0] = backgrounds[bg_index]
				gradient.colors[1] = backgrounds[bg_index].darkened(0.3)
	
	# Scale enemy spawn rate with level
	spawn_timer = max(1.5 - (level * 0.1), 0.5)
	
	# Add more floating clouds on levels with sky
	if level <= 3:
		add_floating_clouds()

func setup_input_map() -> void:
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		InputMap.action_add_event("fire", event)

func spawn_enemy() -> void:
	if not shape_scene:
		return
		
	var shape := shape_scene.instantiate()
	
	var x_pos := randf_range(50, 590)
	shape.position = Vector2(x_pos, -50)
	
	configure_enemy(shape)
	
	add_child(shape)

func configure_enemy(enemy) -> void:
	enemy.add_to_group("Enemies")
	enemy.is_enemy = true
	enemy.target_position = Vector2(320, 720)
	enemy.move_speed = enemy_speed
	
	# Increase health for harder enemies based on level
	if level_number > 3 and randf() < 0.2:
		enemy.health = 2
		enemy.scale = Vector2(1.2, 1.2)
	
	if level_number > 5 and randf() < 0.1:
		enemy.health = 3
		enemy.scale = Vector2(1.4, 1.4)

func _on_shapes_popped(count: int) -> void:
	shapes_destroyed += 1
	
	# Simplified scoring without combo multiplier
	var level_multiplier = 1.0 + ((level_number - 1) * 0.2)
	var points = int(10 * level_multiplier)
	
	score += points
	SignalBus.score_changed.emit(score)

func update_score_display(new_score: int) -> void:
	var score_display := get_node_or_null("ScoreDisplay")
	if not score_display:
		return
		
	var score_fill := score_display.get_node_or_null("ScoreFill") as ColorRect
	if not score_fill:
		return
		
	var percentage: float = min(1.0, float(new_score) / 1000.0)
	var new_width: float = max_score_width * percentage
	
	var tween = create_tween()
	tween.tween_property(score_fill, "size:x", new_width, 0.3)
	tween.tween_property(score_fill, "position:x", -max_score_width/2, 0)

func _on_game_over() -> void:
	if is_game_over:
		return
		
	is_game_over = true
	show_game_over_screen()
	pause_game()

func pause_game() -> void:
	get_tree().paused = true

func show_game_over_screen() -> void:
	var game_over_display := create_game_over_container()
	add_game_over_skull(game_over_display)
	add_restart_button(game_over_display)
	add_child(game_over_display)
	
	# Add additional visual effects
	create_game_over_effects()
	
	game_over_display.scale = Vector2(0.5, 0.5)
	game_over_display.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(game_over_display, "scale", Vector2(1.0, 1.0), 0.3)
	tween.parallel().tween_property(game_over_display, "modulate", Color(1, 1, 1, 1), 0.3)

func create_game_over_container() -> Node2D:
	var container := Node2D.new()
	container.position = Vector2(320, 390)
	
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.0, 0.0, 0.8)
	bg.size = Vector2(400, 300)
	bg.position = Vector2(-200, -150)
	container.add_child(bg)
	
	# Add visual pulsing effect to background
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(bg, "color", Color(0.3, 0.0, 0.0, 0.8), 1.0)
	pulse_tween.tween_property(bg, "color", Color(0.2, 0.0, 0.0, 0.8), 1.0)
	
	# Add borders to container
	var border_width = 4
	var border_color = Color(0.8, 0.1, 0.1, 0.9)
	
	var top_border = ColorRect.new()
	top_border.color = border_color
	top_border.size = Vector2(400 + border_width*2, border_width)
	top_border.position = Vector2(-200 - border_width, -150 - border_width)
	container.add_child(top_border)
	
	var bottom_border = ColorRect.new()
	bottom_border.color = border_color
	bottom_border.size = Vector2(400 + border_width*2, border_width)
	bottom_border.position = Vector2(-200 - border_width, 150)
	container.add_child(bottom_border)
	
	var left_border = ColorRect.new()
	left_border.color = border_color
	left_border.size = Vector2(border_width, 300 + border_width*2)
	left_border.position = Vector2(-200 - border_width, -150 - border_width)
	container.add_child(left_border)
	
	var right_border = ColorRect.new()
	right_border.color = border_color
	right_border.size = Vector2(border_width, 300 + border_width*2)
	right_border.position = Vector2(200, -150 - border_width)
	container.add_child(right_border)
	
	return container

func create_game_over_effects() -> void:
	# Create particles across the screen
	var particles = CPUParticles2D.new()
	particles.position = Vector2(320, 360)
	particles.amount = 40
	particles.lifetime = 4.0
	particles.preprocess = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(320, 360)
	particles.direction = Vector2(0, -1)
	particles.spread = 20
	particles.gravity = Vector2(0, 20)
	particles.initial_velocity_min = 20
	particles.initial_velocity_max = 50
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.7, 0.1, 0.1, 0.7)
	add_child(particles)
	
	# Add flash effect
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.3)
	flash.size = Vector2(640, 720)
	flash.z_index = 50
	add_child(flash)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.5)
	flash_tween.tween_callback(flash.queue_free)
	
	# Add screen shake
	var camera = get_node_or_null("MainCamera")
	if camera:
		var original_pos = camera.position
		var shake_tween = create_tween()
		for i in range(10):
			var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			shake_tween.tween_property(camera, "position", original_pos + offset, 0.05)
		shake_tween.tween_property(camera, "position", original_pos, 0.1)

func add_game_over_skull(container: Node2D) -> void:
	var skull := Node2D.new()
	skull.position = Vector2(0, -50)
	container.add_child(skull)
	
	var skull_circle := ColorRect.new()
	skull_circle.color = Color(0.9, 0.9, 0.9, 1)
	skull_circle.size = Vector2(80, 100)
	skull_circle.position = Vector2(-40, -50)
	skull.add_child(skull_circle)
	
	var left_eye := ColorRect.new()
	left_eye.color = Color(0, 0, 0, 1)
	left_eye.size = Vector2(20, 20)
	left_eye.position = Vector2(-30, -30)
	skull.add_child(left_eye)
	
	var right_eye := ColorRect.new()
	right_eye.color = Color(0, 0, 0, 1)
	right_eye.size = Vector2(20, 20)
	right_eye.position = Vector2(10, -30)
	skull.add_child(right_eye)
	
	var nose := ColorRect.new()
	nose.color = Color(0, 0, 0, 1)
	nose.size = Vector2(10, 15)
	nose.position = Vector2(-5, 0)
	skull.add_child(nose)
	
	# Add pulsing glow to skull
	var glow = ColorRect.new()
	glow.color = Color(1.0, 0.0, 0.0, 0.3)
	glow.size = Vector2(100, 120)
	glow.position = Vector2(-50, -60)
	glow.z_index = -1
	skull.add_child(glow)
	
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 1.0)
	glow_tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 1.0)
	
	# Add animation to the skull
	var skull_tween = create_tween()
	skull_tween.set_loops()
	skull_tween.tween_property(skull, "rotation", 0.1, 1.5)
	skull_tween.tween_property(skull, "rotation", -0.1, 1.5)

func add_restart_button(container: Node2D) -> void:
	var restart_hint := Node2D.new()
	restart_hint.position = Vector2(0, 80)
	container.add_child(restart_hint)
	
	var r_key := ColorRect.new()
	r_key.color = Color(0.8, 0.8, 0.8, 1)
	r_key.size = Vector2(40, 40)
	r_key.position = Vector2(-20, -20)
	restart_hint.add_child(r_key)
	
	add_r_key_shape(restart_hint)
	
	# Add pulsing effect to restart button
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(r_key, "color", Color(1.0, 0.7, 0.7, 1), 0.8)
	pulse_tween.tween_property(r_key, "color", Color(0.8, 0.8, 0.8, 1), 0.8)
	
	# Add particles around restart button
	var particles = CPUParticles2D.new()
	particles.position = Vector2(0, 0)
	particles.amount = 15
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 30
	particles.local_coords = true
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 10
	particles.initial_velocity_max = 20
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.0
	particles.color = Color(1.0, 0.7, 0.7, 0.5)
	restart_hint.add_child(particles)

func add_r_key_shape(parent: Node2D) -> void:
	var r_line1 := ColorRect.new()
	r_line1.color = Color(0, 0, 0, 1)
	r_line1.size = Vector2(5, 30)
	r_line1.position = Vector2(-10, -15)
	parent.add_child(r_line1)
	
	var r_line2 := ColorRect.new()
	r_line2.color = Color(0, 0, 0, 1)
	r_line2.size = Vector2(15, 5)
	r_line2.position = Vector2(-10, -15)
	parent.add_child(r_line2)
	
	var r_line3 := ColorRect.new()
	r_line3.color = Color(0, 0, 0, 1)
	r_line3.size = Vector2(15, 5)
	r_line3.position = Vector2(-10, 0)
	parent.add_child(r_line3)
	
	var r_line4 := ColorRect.new()
	r_line4.color = Color(0, 0, 0, 1)
	r_line4.size = Vector2(5, 5)
	r_line4.position = Vector2(0, 0)
	parent.add_child(r_line4)
	
	var r_line5 := ColorRect.new()
	r_line5.color = Color(0, 0, 0, 1)
	r_line5.size = Vector2(5, 10)
	r_line5.position = Vector2(5, 5)
	parent.add_child(r_line5)

func _input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.keycode == KEY_R and event.pressed:
		restart_game()

func restart_game() -> void:
	var transition = ColorRect.new()
	transition.color = Color(0, 0, 0, 0)
	transition.size = Vector2(640, 720)
	transition.z_index = 100
	add_child(transition)
	
	var tween = create_tween()
	tween.tween_property(transition, "color", Color(0, 0, 0, 1), 0.5)
	tween.tween_callback(func():
		get_tree().reload_current_scene()
		get_tree().paused = false
	)

func check_enemies_reached_bottom() -> void:
	var enemies := get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.position.y > 700:
			_on_game_over()
			return

func add_floating_clouds():
	# Get the CloudMovement node if it exists, or create one
	var cloud_controller
	if has_node("CloudMovement"):
		cloud_controller = get_node("CloudMovement")
	else:
		cloud_controller = Node2D.new()
		cloud_controller.name = "CloudMovement"
		
		# Load and set the cloud movement script
		var cloud_script = load("res://scripts/cloud_movement.gd")
		cloud_controller.set_script(cloud_script)
		add_child(cloud_controller)
	
	# Let the cloud_movement script handle cloud creation
	# The Cloud class is defined in that script
	for i in range(2):
		cloud_controller.spawn_cloud(Vector2(randf_range(50, 590), randf_range(50, 600))) 
