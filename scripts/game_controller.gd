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
	
	var x_pos := randf_range(50, 590)
	shape.position = Vector2(x_pos, -50)
	
	configure_enemy(shape)
	
	add_child(shape)

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

func show_game_over_screen() -> void:
	var game_over_display := create_game_over_container()
	add_game_over_skull(game_over_display)
	add_restart_button(game_over_display)
	add_child(game_over_display)
	
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
	
	var pulse_tween = create_tween()
	pulse_tween.set_loops(0)  
	pulse_tween.tween_property(bg, "color", Color(0.3, 0.0, 0.0, 0.8), 1.0)
	pulse_tween.tween_property(bg, "color", Color(0.2, 0.0, 0.0, 0.8), 1.0)
	
	return container

func create_game_over_effects() -> void:
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
	
	var camera = get_node_or_null("MainCamera")
	if camera:
		var shake_amount = 5.0
		var original_pos = camera.position
		
		var shake_tween = safe_tween(camera)
		if shake_tween:
			shake_tween.tween_property(camera, "position", original_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount, 0.05)
			shake_tween.tween_property(camera, "position", original_pos, 0.05)
	
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.0, 0.0, 0.95)
	flash.size = get_viewport().size * 2
	flash.position = -get_viewport().size
	flash.z_index = 100
	get_tree().root.add_child(flash)
	
	var flash_tween = safe_tween(flash)
	if flash_tween:
		flash_tween.tween_property(flash, "color:a", 0, 0.5)
		flash_tween.tween_callback(flash.queue_free)

func add_game_over_skull(container: Node2D) -> void:
	var skull := Node2D.new()
	skull.position = Vector2(0, -50)
	container.add_child(skull)
	
	var background_glow = Sprite2D.new()
	var glow_size = 150
	var glow_img = Image.create(glow_size, glow_size, false, Image.FORMAT_RGBA8)
	glow_img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(glow_size/2, glow_size/2)
	var radius = glow_size/2
	
	for x in range(glow_size):
		for y in range(glow_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var alpha = 1.0 - pow(dist / radius, 1.8)
				glow_img.set_pixel(x, y, Color(1.0, 0.7, 0.3, alpha * 0.3))
	
	background_glow.texture = ImageTexture.create_from_image(glow_img)
	background_glow.scale = Vector2(1.5, 1.5)
	background_glow.z_index = -2
	skull.add_child(background_glow)
	
	var face_sprite = Sprite2D.new()
	var face_size = 120
	var face_img = Image.create(face_size, face_size, false, Image.FORMAT_RGBA8)
	face_img.fill(Color(0, 0, 0, 0))
	
	center = Vector2(face_size/2, face_size/2)
	radius = face_size/2
	
	for x in range(face_size):
		for y in range(face_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var gradient_factor = 1.0 - (dist / radius)
				var color = Color(1.0, 0.9, 0.8, 1.0).lightened(0.1 * gradient_factor)
				face_img.set_pixel(x, y, color)
	
	face_sprite.texture = ImageTexture.create_from_image(face_img)
	face_sprite.position = Vector2(0, 0)
	skull.add_child(face_sprite)
	
	var left_eye = Node2D.new()
	left_eye.position = Vector2(-25, -15)
	skull.add_child(left_eye)
	
	var left_eye_line = Sprite2D.new()
	var eye_width = 25
	var eye_height = 8
	var eye_img = Image.create(eye_width, eye_height, false, Image.FORMAT_RGBA8)
	eye_img.fill(Color(0, 0, 0, 0))
	
	for x in range(eye_width):
		var y_pos = 4 + sin((float(x) / eye_width) * PI) * 3
		for y in range(eye_height):
			var dist = abs(y - y_pos)
			if dist < 2:
				var alpha = 1.0 - dist / 2.0
				eye_img.set_pixel(x, y, Color(0.3, 0.2, 0.2, alpha))
	
	left_eye_line.texture = ImageTexture.create_from_image(eye_img)
	left_eye.add_child(left_eye_line)
	
	for i in range(3):
		var lash = ColorRect.new()
		lash.color = Color(0.3, 0.2, 0.2, 0.7)
		lash.size = Vector2(1, 6)
		lash.position = Vector2(5 + i * 8, -2)
		lash.rotation = -0.5
		left_eye.add_child(lash)
	
	var right_eye = Node2D.new()
	right_eye.position = Vector2(25, -15)
	skull.add_child(right_eye)
	
	var right_eye_line = Sprite2D.new()
	right_eye_line.texture = ImageTexture.create_from_image(eye_img)
	right_eye.add_child(right_eye_line)
	
	for i in range(3):
		var lash = ColorRect.new()
		lash.color = Color(0.3, 0.2, 0.2, 0.7)
		lash.size = Vector2(1, 6)
		lash.position = Vector2(5 + i * 8, -2)
		lash.rotation = -0.5
		right_eye.add_child(lash)
	
	var nose = Node2D.new()
	nose.position = Vector2(0, 0)
	skull.add_child(nose)
	
	var nose_sprite = Sprite2D.new()
	var nose_size = 12
	var nose_img = Image.create(nose_size, nose_size, false, Image.FORMAT_RGBA8)
	nose_img.fill(Color(0, 0, 0, 0))
	
	center = Vector2(nose_size/2, nose_size/2)
	radius = nose_size/2
	
	for x in range(nose_size):
		for y in range(nose_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var alpha = 1.0 - dist / radius
				nose_img.set_pixel(x, y, Color(0.3, 0.2, 0.2, alpha))
	
	nose_sprite.texture = ImageTexture.create_from_image(nose_img)
	nose.add_child(nose_sprite)
	
	var mouth = Sprite2D.new()
	var mouth_width = 70
	var mouth_height = 8
	var mouth_img = Image.create(mouth_width, mouth_height, false, Image.FORMAT_RGBA8)
	mouth_img.fill(Color(0, 0, 0, 0))
	
	for x in range(mouth_width):
		var y_pos = 4 - cos((float(x) / mouth_width) * PI) * 3
		for y in range(mouth_height):
			var dist = abs(y - y_pos)
			if dist < 2:
				var alpha = 1.0 - dist / 2.0
				mouth_img.set_pixel(x, y, Color(0.3, 0.2, 0.2, alpha))
	
	mouth.texture = ImageTexture.create_from_image(mouth_img)
	mouth.position = Vector2(0, 30)
	skull.add_child(mouth)
	
	var animation = skull.create_tween()
	animation.set_loops()
	animation.tween_property(skull, "position", Vector2(0, -60), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_property(skull, "position", Vector2(0, -50), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var rotate_anim = face_sprite.create_tween()
	rotate_anim.set_loops()
	rotate_anim.tween_property(face_sprite, "rotation", 0.05, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rotate_anim.tween_property(face_sprite, "rotation", -0.05, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var glow_anim = background_glow.create_tween()
	glow_anim.set_loops()
	glow_anim.tween_property(background_glow, "scale", Vector2(1.6, 1.6), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_anim.tween_property(background_glow, "scale", Vector2(1.5, 1.5), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func add_restart_button(container: Node2D) -> void:
	var restart_hint := Node2D.new()
	restart_hint.position = Vector2(0, 80)
	container.add_child(restart_hint)
	
	var r_key_bg = Sprite2D.new()
	var key_size = 48
	var key_img = Image.create(key_size, key_size, false, Image.FORMAT_RGBA8)
	key_img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(key_size/2, key_size/2)
	var radius = key_size/2
	
	for x in range(key_size):
		for y in range(key_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var gradient_factor = 1.0 - (dist / radius)
				var color = Color(0.9, 0.7, 0.7, 1.0).lightened(0.1 * gradient_factor)
				key_img.set_pixel(x, y, color)
	
	r_key_bg.texture = ImageTexture.create_from_image(key_img)
	restart_hint.add_child(r_key_bg)
	
	var key_glow = Sprite2D.new()
	var glow_size = key_size * 1.5
	var glow_img = Image.create(glow_size, glow_size, false, Image.FORMAT_RGBA8)
	glow_img.fill(Color(0, 0, 0, 0))
	
	center = Vector2(glow_size/2, glow_size/2)
	radius = glow_size/2
	
	for x in range(glow_size):
		for y in range(glow_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var alpha = 1.0 - pow(dist / radius, 1.5)
				glow_img.set_pixel(x, y, Color(1.0, 0.6, 0.6, alpha * 0.3))
	
	key_glow.texture = ImageTexture.create_from_image(glow_img)
	key_glow.scale = Vector2(1.2, 1.2)
	key_glow.z_index = -1
	restart_hint.add_child(key_glow)
	
	add_r_key_shape(restart_hint)
	
	var restart_label = Label.new()
	restart_label.text = "Restart"
	restart_label.add_theme_font_size_override("font_size", 14)
	restart_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5, 0.8))
	restart_label.position = Vector2(-30, 30)
	restart_hint.add_child(restart_label)
	
	var pulse_tween = create_tween()
	pulse_tween.set_loops(0)  
	pulse_tween.tween_property(r_key_bg, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(r_key_bg, "scale", Vector2(0.95, 0.95), 0.8).set_trans(Tween.TRANS_SINE)
	
	var glow_tween = create_tween()
	glow_tween.set_loops(0)  
	glow_tween.tween_property(key_glow, "scale", Vector2(1.4, 1.4), 1.5).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(key_glow, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
	
	var particles = CPUParticles2D.new()
	particles.position = Vector2(0, 0)
	particles.amount = 20
	particles.lifetime = 1.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 40
	particles.local_coords = true
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 8
	particles.initial_velocity_max = 15
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.7, 0.7, 0.5)
	restart_hint.add_child(particles)
	
	var heart_timer = Timer.new()
	heart_timer.wait_time = 0.8
	heart_timer.autostart = true
	restart_hint.add_child(heart_timer)
	
	heart_timer.timeout.connect(func():
		if randf() > 0.5:  
			add_heart_particle(restart_hint.position)
	)

func add_heart_particle(position: Vector2) -> void:
	var heart = Sprite2D.new()
	
	# Create heart image procedurally instead of preloading
	var heart_size = 16
	var heart_img = Image.create(heart_size, heart_size, false, Image.FORMAT_RGBA8)
	heart_img.fill(Color(0, 0, 0, 0))
	
	var center_x = heart_size / 2
	var center_y = heart_size / 2
	
	for x in range(heart_size):
		for y in range(heart_size):
			var px = float(x - center_x) / (heart_size / 2)
			var py = float(y - center_y) / (heart_size / 2)
			
			var inside_heart = pow(px, 2) + pow(py - 0.5 * sqrt(abs(px)), 2) < 0.6
			
			if inside_heart:
				heart_img.set_pixel(x, y, Color(1.0, 0.5, 0.5, 0.8))
	
	heart.texture = ImageTexture.create_from_image(heart_img)
	heart.position = position
	heart.scale = Vector2(0.5, 0.5)
	heart.modulate = Color(1, 0.5, 0.5, 0.8)
	add_child(heart)
	
	# Re-add the animation tween
	var tween = create_tween()
	tween.tween_property(heart, "position:y", position.y - 50, 0.7)
	tween.parallel().tween_property(heart, "modulate:a", 0, 0.7)
	tween.tween_callback(heart.queue_free)

func handle_game_input(event: InputEvent) -> void:
	if is_game_over and event.is_action_pressed("fire"):
		restart_game()
		
	if is_game_over:
		return
	
	if event.is_action_pressed("fire"):
		var gun = $Gun as Node2D
		if gun and gun.has_method("fire"):
			gun.fire()

func restart_game() -> void:
	is_game_over = false
	score = 0
	level_number = 1
	game_difficulty = 1.0
	enemy_speed = 80.0
	shapes_destroyed = 0
	shapes_for_next_level = 20
	
	remove_all_enemies()
	setup_level_visuals(level_number)
	
	var game_over_label = get_node_or_null("GameOverLabel")
	if game_over_label:
		game_over_label.queue_free()
	
	SignalBus.emit_score_changed(score)
	
	spawn_initial_enemies()

func remove_all_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		enemy.queue_free()

func check_bottom_row() -> void:
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	var game_over = false
	for enemy in enemies:
		if enemy.position.y > 650:
			game_over = true
			break
			
	if game_over:
		SignalBus.emit_game_over()

func create_pixel_fireballs(parent: Node2D, intensity: int) -> void:
	for i in range(intensity * 3):
		var fireball = Sprite2D.new()
		var size = randi_range(8, 16)
		
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		
		for x in range(size):
			for y in range(size):
				var center_x = size / 2
				var center_y = size / 2
				var dist = sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
				
				if dist < size/2:
					var color
					if dist < size/4:
						color = Color(1.0, 0.9, 0.3, 0.8)
					else:
						color = Color(1.0, 0.5, 0.1, 0.8)
					img.set_pixel(x, y, color)
		
		fireball.texture = ImageTexture.create_from_image(img)
		fireball.modulate.a = 0.8
		
		var angle = randf() * 2 * PI
		var distance = randi_range(10, 100) * intensity
		
		fireball.position = Vector2(cos(angle) * distance, sin(angle) * distance)
		parent.add_child(fireball)
		
		var tween = create_tween()
		var target_pos = fireball.position * randf_range(1.5, 3.0)
		var duration = randf_range(0.4, 0.8)
		
		tween.tween_property(fireball, "position", target_pos, duration)
		tween.parallel().tween_property(fireball, "modulate:a", 0.0, duration)
		tween.tween_callback(fireball.queue_free)

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
	
	create_red_flash(position, count)
	
	create_explosion(position, count)
	
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

func shake_entire_screen(intensity: int) -> void:
	var shake_amount = min(10.0 + (intensity * 2.5), 25.0)
	var shake_duration = 0.02
	var shake_cycles = min(intensity + 6, 10)
	
	var viewport = get_viewport()
	if not viewport:
		return
		
	var original_transform = viewport.canvas_transform
	
	var delay = 0.0
	for i in range(shake_cycles):
		var decay = 1.0 - (float(i) / shake_cycles * 0.4)
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount * decay
		
		get_tree().create_timer(delay).timeout.connect(func():
			viewport.canvas_transform = Transform2D(0, original_transform.origin + offset)
		)
		delay += shake_duration
		
		get_tree().create_timer(delay).timeout.connect(func():
			viewport.canvas_transform = original_transform
		)
		delay += shake_duration
	
	get_tree().create_timer(delay + 0.1).timeout.connect(func():
		viewport.canvas_transform = original_transform
	)

func create_red_flash(position: Vector2, intensity: int) -> void:
	var root_viewport = get_viewport()
	if not root_viewport:
		return
		
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.2, 0.2, 0.8)
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().root.add_child(canvas_layer)
	
	canvas_layer.add_child(flash)
	
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	flash.grow_vertical = Control.GROW_DIRECTION_BOTH
	flash.size = root_viewport.size
	
	var vector_shader = Shader.new()
	vector_shader.code = """
	shader_type canvas_item;
	
	uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.2, 0.8);
	uniform float time = 0.0;
	uniform vec2 center = vec2(0.5, 0.5);
	
	void fragment() {
		vec2 uv = UV;
		vec2 centered_uv = uv - center;
		float dist = length(centered_uv);
		
		// Create a radial gradient for more dynamic flash
		float edge = smoothstep(0.4, 0.6, dist);
		COLOR = flash_color;
		COLOR.a *= (1.0 - edge * 0.3);
	}
	"""
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = vector_shader
	shader_material.set_shader_parameter("flash_color", Color(1.0, 0.2, 0.2, 0.8))
	shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	shader_material.set_shader_parameter("time", 0.0)
	flash.material = shader_material
	
	var flash_tween = create_tween()
	flash_tween.tween_interval(0.1)
	flash_tween.tween_property(flash, "color:a", 0.7, 0.1)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.3)
	flash_tween.tween_callback(func():
		canvas_layer.queue_free()
	)
	
	shake_entire_screen(intensity + 2)

func create_explosion(position: Vector2, intensity: int) -> void:
	var explosion_root = Node2D.new()
	explosion_root.position = position
	explosion_root.z_index = 100
	get_tree().root.add_child(explosion_root)
	
	var shockwave_shader = ColorRect.new()
	shockwave_shader.size = Vector2(2000, 2000)
	shockwave_shader.position = Vector2(-1000, -1000)
	shockwave_shader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shockwave_shader.z_index = 100
	explosion_root.add_child(shockwave_shader)
	
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform float time = 0.0;
	uniform vec2 center = vec2(0.5, 0.5);
	uniform float size = 0.3;
	uniform float thickness = 0.05;
	uniform vec4 ring_color : source_color = vec4(1.0, 0.5, 0.1, 0.9);
	uniform vec4 secondary_color : source_color = vec4(1.0, 0.9, 0.3, 0.9);
	
	void fragment() {
		vec2 uv = UV;
		float ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		
		// Create a properly proportioned circle
		vec2 centered_uv = vec2(uv.x - center.x, (uv.y - center.y) * ratio);
		float dist = length(centered_uv);
		
		// Create sharp-edged ring with anti-aliasing for vector look
		float ring_outer = smoothstep(size - 0.002, size, dist);
		float ring_inner = smoothstep(size - thickness - 0.002, size - thickness, dist);
		float main_ring = (1.0 - ring_outer) * ring_inner;
		
		// Add a second, smaller inner ring
		float inner_ring_outer = smoothstep(size * 0.6 - 0.002, size * 0.6, dist);
		float inner_ring_inner = smoothstep(size * 0.6 - thickness/2.0 - 0.002, size * 0.6 - thickness/2.0, dist);
		float secondary_ring = (1.0 - inner_ring_outer) * inner_ring_inner;
		
		// Combine rings with separate colors
		vec4 color = mix(ring_color, secondary_color, secondary_ring);
		float ring_opacity = max(main_ring, secondary_ring * 0.8);
		
		// Add subtle radial lines
		float angle = atan(centered_uv.y, centered_uv.x);
		float lines = abs(sin(angle * 16.0)) * 0.1;
		ring_opacity = min(ring_opacity + lines * ring_opacity, 1.0);
		
		// Apply time fading
		ring_opacity *= (1.0 - time) * 1.2;
		
		color.a *= ring_opacity;
		COLOR = color;
	}
	"""
	
	shader_material.shader = shader
	shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	shader_material.set_shader_parameter("size", 0.15)
	shader_material.set_shader_parameter("thickness", 0.02)
	shader_material.set_shader_parameter("time", 0.0)
	shader_material.set_shader_parameter("ring_color", Color(1.0, 0.3, 0.0, 0.9))
	shader_material.set_shader_parameter("secondary_color", Color(1.0, 0.9, 0.2, 0.9))
	
	shockwave_shader.material = shader_material
	
	var shader_tween = create_tween()
	shader_tween.tween_property(shader_material, "shader_parameter/size", 0.7, 0.8)
	shader_tween.parallel().tween_property(shader_material, "shader_parameter/time", 1.0, 0.8)
	shader_tween.tween_callback(shockwave_shader.queue_free)
	
	create_vector_explosion(explosion_root, intensity)
	create_vector_particles(explosion_root, intensity)
	
	var timer = Timer.new()
	explosion_root.add_child(timer)
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func(): explosion_root.queue_free())
	timer.start()

func create_vector_explosion(parent: Node2D, intensity: int) -> void:
	var burst_count = 8 + (intensity * 2)
	var max_size = 40.0 * intensity
	
	# Create central glow
	var center_glow = ColorRect.new()
	center_glow.size = Vector2(max_size * 0.5, max_size * 0.5)
	center_glow.position = Vector2(-max_size * 0.25, -max_size * 0.25)
	center_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var glow_shader = Shader.new()
	glow_shader.code = """
	shader_type canvas_item;
	
	uniform vec4 center_color : source_color = vec4(1.0, 0.95, 0.2, 0.8);
	uniform vec4 edge_color : source_color = vec4(1.0, 0.3, 0.0, 0.0);
	
	void fragment() {
		vec2 uv = UV * 2.0 - 1.0;
		float dist = length(uv);
		float circle = 1.0 - smoothstep(0.0, 1.0, dist);
		COLOR = mix(edge_color, center_color, circle);
	}
	"""
	
	var glow_material = ShaderMaterial.new()
	glow_material.shader = glow_shader
	glow_material.set_shader_parameter("center_color", Color(1.0, 0.95, 0.2, 0.8))
	glow_material.set_shader_parameter("edge_color", Color(1.0, 0.3, 0.0, 0.0))
	center_glow.material = glow_material
	parent.add_child(center_glow)
	
	var glow_tween = create_tween()
	glow_tween.tween_property(center_glow, "size", Vector2(max_size * 1.5, max_size * 1.5), 0.5)
	glow_tween.parallel().tween_property(center_glow, "position", Vector2(-max_size * 0.75, -max_size * 0.75), 0.5)
	glow_tween.parallel().tween_property(glow_material, "shader_parameter/center_color:a", 0.0, 0.5)
	glow_tween.tween_callback(center_glow.queue_free)
	
	# Create vector shape bursts
	for i in range(burst_count):
		var angle = (2 * PI / burst_count) * i
		var length = 20 + (intensity * 10)
		var width = 4 + (randf() * 4)
		
		var burst = create_vector_burst(angle, length, width)
		parent.add_child(burst)
		
		var burst_tween = create_tween()
		burst_tween.tween_property(burst, "scale", Vector2(2.0, 2.0), 0.4)
		burst_tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.4)
		burst_tween.tween_callback(burst.queue_free)

func create_vector_burst(angle: float, length: float, width: float) -> Node2D:
	var burst = Node2D.new()
	
	var poly = Polygon2D.new()
	var points = []
	
	var tip_x = cos(angle) * length
	var tip_y = sin(angle) * length
	
	var base_x = cos(angle) * (length * 0.2)
	var base_y = sin(angle) * (length * 0.2)
	
	var perp_x = cos(angle + PI/2) * width
	var perp_y = sin(angle + PI/2) * width
	
	points.append(Vector2(tip_x, tip_y))
	points.append(Vector2(base_x + perp_x, base_y + perp_y))
	points.append(Vector2(base_x - perp_x, base_y - perp_y))
	
	poly.polygon = points
	
	# Create gradient from yellow to orange-red
	var gradient = Gradient.new()
	gradient.colors = [Color(1.0, 0.8, 0.2, 1.0), Color(1.0, 0.3, 0.0, 1.0)]
	gradient.offsets = [0.0, 1.0]
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	texture.width = 256
	texture.height = 256
	
	poly.texture = texture
	poly.texture_scale = Vector2(3.0, 3.0)
	poly.texture_offset = Vector2(-128, -128)
	
	burst.add_child(poly)
	
	return burst

func create_vector_particles(parent: Node2D, intensity: int) -> void:
	var particle_count = intensity * 12
	
	for i in range(particle_count):
		var angle = randf() * 2 * PI
		var distance = randf_range(30, 100) * sqrt(intensity)
		var size = randf_range(4, 12)
		
		var shape_type = randi() % 3  # 0: triangle, 1: diamond, 2: small line
		var particle: Node2D
		
		match shape_type:
			0: # Triangle
				particle = Polygon2D.new()
				var points = [
					Vector2(0, -size),
					Vector2(-size * 0.866, size * 0.5),
					Vector2(size * 0.866, size * 0.5)
				]
				particle.polygon = points
				
			1: # Diamond
				particle = Polygon2D.new()
				var points = [
					Vector2(0, -size),
					Vector2(size, 0),
					Vector2(0, size),
					Vector2(-size, 0)
				]
				particle.polygon = points
				
			2: # Line
				particle = Line2D.new()
				particle.add_point(Vector2(0, 0))
				particle.add_point(Vector2(cos(angle) * size, sin(angle) * size))
				particle.width = size / 3
				particle.default_color = Color(1.0, 0.6, 0.2, 0.8)
		
		if shape_type != 2:
			particle.color = Color(1.0, 0.6, 0.2, 0.8)
			
			if randf() > 0.5:
				particle.color = Color(1.0, 0.9, 0.5, 0.8)
		
		particle.position = Vector2.ZERO
		parent.add_child(particle)
		
		var direction = Vector2(cos(angle), sin(angle))
		var target_pos = direction * distance
		var duration = randf_range(0.4, 0.8)
		
		var tween = create_tween()
		tween.tween_property(particle, "position", target_pos, duration)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, duration * 0.8)
		
		if shape_type != 2:  # Add rotation for shapes but not lines
			var rotation_amount = randf_range(-PI, PI)
			tween.parallel().tween_property(particle, "rotation", rotation_amount, duration)
			
		tween.tween_callback(particle.queue_free)

func add_r_key_shape(parent: Node2D) -> void:
	var r_letter = Node2D.new()
	r_letter.position = Vector2(0, 0)
	r_letter.scale = Vector2(0.8, 0.8)  
	parent.add_child(r_letter)
	
	var stem = Sprite2D.new()
	var stem_width = 8
	var stem_height = 24
	var stem_img = Image.create(stem_width, stem_height, false, Image.FORMAT_RGBA8)
	stem_img.fill(Color(0, 0, 0, 0))
	
	for x in range(stem_width):
		for y in range(stem_height):
			stem_img.set_pixel(x, y, Color(0.3, 0.2, 0.2, 1.0))
	
	stem.texture = ImageTexture.create_from_image(stem_img)
	stem.position = Vector2(-10, 0)
	r_letter.add_child(stem)
	
	var top_curve = Sprite2D.new()
	var curve_size = 20
	var curve_img = Image.create(curve_size, curve_size, false, Image.FORMAT_RGBA8)
	curve_img.fill(Color(0, 0, 0, 0))
	
	var curve_center = Vector2(0, curve_size/2)
	var curve_radius = curve_size/2
	
	for x in range(curve_size):
		for y in range(curve_size):
			var point = Vector2(x, y)
			var dist = point.distance_to(curve_center)
			var angle = atan2(y - curve_center.y, x - curve_center.x)
			
			if dist < curve_radius && dist > curve_radius - 8 && angle > -PI/2 && angle < PI/2:
				curve_img.set_pixel(x, y, Color(0.3, 0.2, 0.2, 1.0))
	
	top_curve.texture = ImageTexture.create_from_image(curve_img)
	top_curve.position = Vector2(0, -10)
	r_letter.add_child(top_curve)
	
	var diagonal = Sprite2D.new()
	var diag_width = 20
	var diag_height = 20
	var diag_img = Image.create(diag_width, diag_height, false, Image.FORMAT_RGBA8)
	diag_img.fill(Color(0, 0, 0, 0))
	
	for x in range(diag_width):
		for y in range(diag_height):
			var dist = abs(y - (float(x) / diag_width) * diag_height)
			if dist < 3:
				diag_img.set_pixel(x, y, Color(0.3, 0.2, 0.2, 1.0))
	
	diagonal.texture = ImageTexture.create_from_image(diag_img)
	diagonal.position = Vector2(0, 8)
	r_letter.add_child(diagonal)
