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
	Color(0.92, 0.95, 0.98, 1), 
	Color(0.85, 0.91, 0.98, 1),  
	Color(0.94, 0.82, 0.75, 1),  
	Color(0.85, 0.72, 0.85, 1),  
	Color(0.7, 0.78, 0.85, 1)   
]

var recent_kills: int = 0
var recent_kill_positions: Array = []
var kill_timer: Timer

func _ready() -> void:
	randomize()
	setup_input_map()
	connect_signals()
	spawn_initial_enemies()
	setup_level_visuals(level_number)
	setup_kill_timer()

func connect_signals() -> void:
	SignalBus.shapes_popped.connect(_on_shapes_popped)
	SignalBus.game_over_triggered.connect(_on_game_over)
	SignalBus.score_changed.connect(update_score_display)

func spawn_initial_enemies() -> void:
	# Reduced initial enemy count for better spacing
	for i in range(3):
		# Enforce spacing for initial enemies by using spawn positions far apart
		var x_pos = 150 + i * 170
		var spawn_pos = Vector2(x_pos, -50 - i * 40)
		
		var shape := shape_scene.instantiate()
		shape.position = spawn_pos
		configure_enemy(shape)
		add_child(shape)
		
		# Add a small delay between spawns to allow physics to settle
		await get_tree().create_timer(0.1).timeout

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
	
	if shapes_destroyed >= shapes_for_next_level:
		advance_level()

func advance_level() -> void:
	level_number += 1
	shapes_destroyed = 0
	shapes_for_next_level = 20 + (level_number * 5)
	
	setup_level_visuals(level_number)

func setup_level_visuals(level: int) -> void:
	var bg_index = min(level - 1, backgrounds.size() - 1)
	var background = $Background as TextureRect
	
	if background and background.texture:
		var gradient_texture = background.texture as GradientTexture2D
		if gradient_texture:
			var gradient = gradient_texture.gradient
			if bg_index < backgrounds.size():
				gradient.colors[0] = backgrounds[bg_index]
				gradient.colors[1] = backgrounds[bg_index].darkened(0.3)
	
	spawn_timer = max(1.5 - (level * 0.1), 0.5)

func setup_input_map() -> void:
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = true
		InputMap.action_add_event("fire", mouse_event)
		
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_SPACE
		key_event.pressed = true
		InputMap.action_add_event("fire", key_event)

func spawn_enemy() -> void:
	if not shape_scene:
		return
		
	var shape := shape_scene.instantiate()
	
	# Find a suitable spawn position with minimum separation
	var spawn_pos := find_suitable_spawn_position()
	shape.position = spawn_pos
	
	configure_enemy(shape)
	
	add_child(shape)

func find_suitable_spawn_position() -> Vector2:
	var min_spacing := 150.0  # Significantly increased from 100.0
	var max_attempts := 25   # Increased from 15 to give more chances to find suitable position
	var attempts := 0
	var x_pos := randf_range(70, 570)  # Reduced spawn area to avoid edge cases
	var spawn_pos := Vector2(x_pos, -50)
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	while attempts < max_attempts:
		var too_close := false
		
		for enemy in enemies:
			if spawn_pos.distance_to(enemy.position) < min_spacing:
				too_close = true
				break
				
		if not too_close or enemies.size() == 0:
			break
			
		# Try another position with better distribution
		x_pos = 70 + (570 - 70) * (float(attempts) / float(max_attempts - 1))
		spawn_pos = Vector2(x_pos, -50)
		attempts += 1
		
		# If we're still getting positions too close, try a different y offset
		if attempts > max_attempts / 2:
			spawn_pos.y = -50 - (attempts - max_attempts / 2) * 20

	return spawn_pos

func configure_enemy(enemy) -> void:
	enemy.add_to_group("Enemies")
	enemy.is_enemy = true
	enemy.target_position = Vector2(320, 720)
	enemy.move_speed = enemy_speed
	
	if level_number > 3 and randf() < 0.2:
		enemy.health = 2
		enemy.scale = Vector2(1.2, 1.2)
	
	if level_number > 5 and randf() < 0.1:
		enemy.health = 3
		enemy.scale = Vector2(1.4, 1.4)

func setup_kill_timer() -> void:
	kill_timer = Timer.new()
	kill_timer.wait_time = 0.5
	kill_timer.one_shot = true
	kill_timer.timeout.connect(_on_kill_timer_timeout)
	add_child(kill_timer)

func _on_kill_timer_timeout() -> void:
	if recent_kills > 1:
		var center = Vector2.ZERO
		for pos in recent_kill_positions:
			center += pos
		center /= recent_kill_positions.size()
		
		create_cluster_explosion(recent_kills, center)
	
	recent_kills = 0
	recent_kill_positions.clear()

func _on_shapes_popped(count: int) -> void:
	shapes_destroyed += 1
	
	var level_multiplier = 1.0 + ((level_number - 1) * 0.2)
	var points = int(10 * level_multiplier)
	
	var shapes = get_tree().get_nodes_in_group("shapes")
	for shape in shapes:
		if shape.is_queued_for_deletion() and not shape.is_enemy:
			recent_kill_positions.append(shape.global_position)
	
	recent_kills += count
	
	if recent_kills >= 2:
		var center = Vector2.ZERO
		for pos in recent_kill_positions:
			center += pos
		center /= recent_kill_positions.size()
		
		create_cluster_explosion(recent_kills, center)
		
		recent_kills = 0
		recent_kill_positions.clear()
		
		if not kill_timer.is_stopped():
			kill_timer.stop()
	else:
		if not kill_timer.is_stopped():
			kill_timer.stop()
		kill_timer.start()
	
	if count > 1:
		points *= count
	
	score += points
	SignalBus.emit_score_changed(score)

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
	tween.tween_property(score_fill, "position:x", -max_score_width/2.0, 0)

func _on_game_over() -> void:
	if is_game_over:
		return
		
	is_game_over = true
	show_game_over_screen()
	pause_game()

func pause_game() -> void:
	get_tree().paused = true

func create_cluster_explosion(count: int, position: Vector2 = Vector2.ZERO) -> void:
	if position == Vector2.ZERO:
		var positions = []
		var shapes = get_tree().get_nodes_in_group("shapes")
		for shape in shapes:
			if not shape.is_queued_for_deletion():
				positions.append(shape.global_position)
		
		if positions.size() == 0 and recent_kill_positions.size() > 0:
			positions = recent_kill_positions
		
		if positions.size() > 0:
			position = Vector2.ZERO
			for pos in positions:
				position += pos
			position /= positions.size()
		else:
			position = Vector2(320, 360)
			
	# No explosion effects - just audio feedback
	var explosion_volume = -10.0 + min(count * 2, 10)
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	var sound_paths = ["res://assets/sounds/hit.wav", "res://assets/sounds/launch.wav"]
	for path in sound_paths:
		if ResourceLoader.exists(path):
			audio_player.stream = load(path)
			audio_player.pitch_scale = 0.7
			audio_player.volume_db = explosion_volume
			audio_player.play()
			audio_player.finished.connect(audio_player.queue_free)
			break

func check_enemies_reached_bottom() -> void:
	var enemies := get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.position.y > 700:
			_on_game_over()
			return

func safe_tween(target_node: Node = null) -> Tween:
	var tween = create_tween()
	if tween == null:
		if target_node:
			tween = target_node.create_tween()
	
	return tween

func show_game_over_screen() -> void:
	var game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.text = "GAME OVER"
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	game_over_label.position = Vector2(320 - 150, 360 - 24)
	add_child(game_over_label)