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

func _ready() -> void:
	randomize()
	setup_input_map()
	connect_signals()
	spawn_initial_enemies()
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

func _on_shapes_popped(count: int) -> void:
	shapes_destroyed += 1
	
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
	flash.color = Color(1, 0.5, 0.3, 0.3)  
	flash.size = get_viewport().size
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
	
	var mouth = Sprite2D.new()
	var mouth_width = 40
	var mouth_height = 20
	var mouth_img = Image.create(mouth_width, mouth_height, false, Image.FORMAT_RGBA8)
	mouth_img.fill(Color(0, 0, 0, 0))
	
	for x in range(mouth_width):
		var progress = float(x) / mouth_width
		var y_pos = 10 - sin(progress * PI) * 5
		
		for y in range(mouth_height):
			var dist = abs(y - y_pos)
			if dist < 2:
				var alpha = 1.0 - dist / 2.0
				mouth_img.set_pixel(x, y, Color(0.8, 0.3, 0.3, alpha))
	
	mouth.texture = ImageTexture.create_from_image(mouth_img)
	mouth.position = Vector2(0, 15)
	skull.add_child(mouth)
	
	var sweat = Sprite2D.new()
	var sweat_size = 10
	var sweat_img = Image.create(sweat_size, sweat_size, false, Image.FORMAT_RGBA8)
	sweat_img.fill(Color(0, 0, 0, 0))
	
	for x in range(sweat_size):
		for y in range(sweat_size):
			var normalized_x = float(x) / sweat_size
			var normalized_y = float(y) / sweat_size
			var in_drop = false
			
			if normalized_y > 0.3:
				var width = 0.4 * sin(normalized_y * PI)
				if abs(normalized_x - 0.5) < width:
					in_drop = true
			elif normalized_x > 0.3 && normalized_x < 0.7 && normalized_y < 0.3:
				in_drop = true
				
			if in_drop:
				var alpha = 1.0 - (Vector2(x, y).distance_to(Vector2(sweat_size/2, sweat_size/2)) / (sweat_size/2))
				sweat_img.set_pixel(x, y, Color(0.7, 0.9, 1.0, alpha * 0.8))
	
	sweat.texture = ImageTexture.create_from_image(sweat_img)
	sweat.position = Vector2(40, -10)
	skull.add_child(sweat)
	
	var sweat_tween = create_tween()
	sweat_tween.set_loops(0)  
	sweat_tween.tween_property(sweat, "position", Vector2(40, 0), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	sweat_tween.tween_property(sweat, "position", Vector2(40, -10), 0.0)
	sweat_tween.tween_property(sweat, "visible", false, 0.0)
	sweat_tween.tween_interval(0.8)
	sweat_tween.tween_property(sweat, "visible", true, 0.0)
	
	var glow = Sprite2D.new()
	var glow_img2 = Image.create(face_size, face_size, false, Image.FORMAT_RGBA8)
	glow_img2.fill(Color(0, 0, 0, 0))
	
	for x in range(face_size):
		for y in range(face_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius * 1.2 && dist > radius * 0.8:
				var factor = 1.0 - abs((dist - radius) / (radius * 0.2))
				glow_img2.set_pixel(x, y, Color(1.0, 0.5, 0.3, factor * 0.4))
	
	glow.texture = ImageTexture.create_from_image(glow_img2)
	glow.z_index = -1
	skull.add_child(glow)
	
	var skull_tween = create_tween()
	skull_tween.set_loops(0)  
	skull_tween.tween_property(skull, "position", Vector2(0, -45), 1.5).set_trans(Tween.TRANS_SINE)
	skull_tween.tween_property(skull, "position", Vector2(0, -55), 1.5).set_trans(Tween.TRANS_SINE)
	
	var glow_tween = create_tween()
	glow_tween.set_loops(0)  
	glow_tween.tween_property(glow, "scale", Vector2(1.15, 1.15), 2.0).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow, "scale", Vector2(0.95, 0.95), 2.0).set_trans(Tween.TRANS_SINE)
	
	var game_over_label = Label.new()
	game_over_label.text = "Game Over"
	game_over_label.add_theme_font_size_override("font_size", 24)
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4, 0.8))
	game_over_label.position = Vector2(-60, 50)
	skull.add_child(game_over_label)

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
			add_heart_particle(restart_hint)
	)

func add_heart_particle(parent: Node2D) -> void:
	var heart = Sprite2D.new()
	var heart_size = 12
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
	
	var angle = randf() * 2 * PI
	var distance = randf_range(30, 60)
	heart.position = Vector2(cos(angle) * distance, sin(angle) * distance)
	heart.scale = Vector2(0.1, 0.1)
	heart.modulate.a = 0.0
	parent.add_child(heart)
	
	var tween = create_tween()
	tween.tween_property(heart, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(heart, "modulate:a", 0.8, 0.3)
	tween.tween_property(heart, "position", heart.position + Vector2(0, -40), 1.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.8).set_delay(0.7)
	tween.tween_callback(heart.queue_free)

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

func safe_tween(target_node: Node = null) -> Tween:
	var tween = create_tween()
	if tween == null:
		if target_node:
			tween = target_node.create_tween()
	
	return tween 
