extends Node

@onready var Log = get_node_or_null("/root/Log")

@export var shape_scene: PackedScene
@export var spawn_timer: float = 2.0
@export var max_score_width: float = 300.0
@export var game_difficulty: float = 1.5
@export var high_score_panel_scene: PackedScene
@export var explosion_scene: PackedScene
@export var powerup_scene: PackedScene

@onready var scene_manager = get_node("/root/SceneManager")
@onready var score_fill = get_node_or_null("ScoreDisplay/ScoreFill")
@onready var score_label = get_node_or_null("ScoreDisplay/ScoreLabel")
@onready var current_score_label = get_node_or_null("CurrentScoreDisplay/CurrentScoreLabel")
@onready var high_score_label = get_node_or_null("HighScoreDisplay/HighScoreLabel") 
@onready var crown_icon = get_node_or_null("HighScoreDisplay/CrownIcon")
@onready var launcher = get_node_or_null("Launcher")
@onready var canvas_layer = $CanvasLayer
@onready var background = $Background as TextureRect
@onready var main_camera = $MainCamera
var high_score_manager = null

var score: int = 0
var is_game_over: bool = false
var level_number: int = 1
var shapes_destroyed: int = 0
var shapes_for_next_level: int = 10
var game_running: bool = false

var enemy_speed: float = 70.0
var time_since_last_spawn: float = 0.0

var launcher_path = ""

var game_scene: Node

var current_min_difficulty: float = 0.0
var current_max_difficulty: float = 0.0
var current_difficulty: float = 0.0 

var spawn_positions: Array[Vector2] = []
var despawn_position_y: float = 0.0

var score_multiplier: float = 1.0

var total_score_this_game: float = 0.0
var current_shapes: Array = []

var combo_count: int = 0
var combo_timer: float = 0
var max_combo_time: float = 2.0
var combo_label: Label

var level_themes = [
	{"bg": Color(0.15, 0.2, 0.4), "accent": Color(0.6, 0.8, 1.0)},
	{"bg": Color(0.4, 0.15, 0.15), "accent": Color(1.0, 0.6, 0.6)},
	{"bg": Color(0.15, 0.4, 0.2), "accent": Color(0.6, 1.0, 0.7)},
	{"bg": Color(0.4, 0.3, 0.1), "accent": Color(1.0, 0.9, 0.5)},
	{"bg": Color(0.2, 0.2, 0.3), "accent": Color(0.7, 0.7, 1.0)}
]

var achievements = {
	"first_blood": {"name": "First Blood", "desc": "Destroy your first enemy", "unlocked": false},
	"combo_master": {"name": "Combo Master", "desc": "Reach a 10x combo", "unlocked": false},
	"level_5": {"name": "Getting Started", "desc": "Reach level 5", "unlocked": false},
	"score_10k": {"name": "Point Collector", "desc": "Score 10,000 points", "unlocked": false},
	"special_killer": {"name": "Special Forces", "desc": "Destroy 10 special enemies", "unlocked": false}
}

var special_enemies_destroyed: int = 0
var bullet_time_active: bool = false
var bullet_time_duration: float = 0.0
var bullet_time_max: float = 5.0
var screen_shake_active: bool = false
var screen_shake_intensity: float = 0.0
var screen_shake_duration: float = 0.0

var combo_upgrades = {
	3: "speed_boost",
	5: "damage_boost",
	8: "bullet_time",
	12: "score_multiplier",
	15: "magnet_effect",
	20: "multi_shot",
	25: "explosion_radius"
}

var active_upgrades = {}
var upgrade_durations = {
	"speed_boost": 5.0,
	"damage_boost": 8.0,
	"bullet_time": 3.0,
	"score_multiplier": 10.0,
	"magnet_effect": 7.0,
	"multi_shot": 6.0,
	"explosion_radius": 12.0
}

var upgrade_timers = {}
var upgrade_effects = {
	"speed_boost": 1.0,
	"damage_boost": 1.0,
	"bullet_time": 1.0,
	"score_multiplier": 1.0,
	"magnet_effect": 0.0,
	"multi_shot": 0,
	"explosion_radius": 1.0
}

var upgrade_max_levels = {
	"speed_boost": 3,
	"damage_boost": 3,
	"bullet_time": 2,
	"score_multiplier": 4,
	"magnet_effect": 2,
	"multi_shot": 2,
	"explosion_radius": 3
}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_running = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	combo_label = Label.new()
	add_child(combo_label)
	combo_label.position = Vector2(600, 150)
	combo_label.add_theme_color_override("font_color", Color(1, 0.5, 0, 1))
	combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	combo_label.add_theme_font_size_override("font_size", 32)
	combo_label.text = ""
	combo_label.visible = false
	
	var setup_autoloads = load("res://scripts/setup_autoloads.gd").new()
	add_child(setup_autoloads)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(setup_autoloads):
		remove_child(setup_autoloads)
		setup_autoloads.queue_free()
	
	high_score_manager = get_node_or_null("/root/HighScoreManager")
	if high_score_manager == null:
		if Log:
			Log.error("GC: HighScoreManager not found after setup, creating manually")
		high_score_manager = load("res://scripts/high_score_manager.gd").new()
		high_score_manager.name = "HighScoreManager"
		call_deferred("add_high_score_manager", high_score_manager)
	
	if launcher:
		if Log:
			Log.debug("GC: _ready called, launcher reference: " + str(launcher != null))
			Log.debug("GC: launcher node path: " + str(launcher.get_path()))
			Log.debug("GC: launcher script instance_id: " + str(launcher.get_instance_id()))
		
		launcher_path = launcher.get_path()
	else:
		if Log:
			Log.debug("GC: launcher is null!")
	
	if not SignalBus.game_over_triggered.is_connected(_on_game_ended):
		SignalBus.game_over_triggered.connect(_on_game_ended)
	
	if not SignalBus.score_changed.is_connected(_on_score_changed):
		SignalBus.score_changed.connect(_on_score_changed)
	
	randomize()
	
	setup_input_map()
	connect_signals()
	apply_level_theme()
	setup_background()
	get_viewport().size_changed.connect(adjust_background_size)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	spawn_initial_enemies()
	update_high_score_display()

func add_high_score_manager(node):
	add_child(node)
	if node.has_method("_ready"):
		node._ready()

func connect_signals():
	if not SignalBus.shapes_popped.is_connected(_on_shapes_popped):
		SignalBus.shapes_popped.connect(_on_shapes_popped)
	
	if not SignalBus.game_over_triggered.is_connected(_on_game_over):
		SignalBus.game_over_triggered.connect(_on_game_over)
	
	if not SignalBus.score_changed.is_connected(update_score_display):
		SignalBus.score_changed.connect(update_score_display)
	
	if not SignalBus.shape_launched.is_connected(_on_shape_launched):
		SignalBus.shape_launched.connect(_on_shape_launched)
	
	if not SignalBus.high_scores_updated.is_connected(func(_high_scores): update_high_score_display()):
		SignalBus.high_scores_updated.connect(func(_high_scores): update_high_score_display())
	
	if not SignalBus.special_enemy_destroyed.is_connected(_on_special_enemy_destroyed):
		SignalBus.special_enemy_destroyed.connect(_on_special_enemy_destroyed)
	
	if not SignalBus.bullet_time_activated.is_connected(_on_bullet_time_activated):
		SignalBus.bullet_time_activated.connect(_on_bullet_time_activated)

func setup_input_map():
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
	
	if not InputMap.has_action("bullet_time"):
		InputMap.add_action("bullet_time")
		
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_SHIFT
		key_event.pressed = true
		InputMap.action_add_event("bullet_time", key_event)

func _process(delta):
	if is_game_over:
		return
	
	if screen_shake_active:
		process_screen_shake(delta)
	
	if bullet_time_active:
		process_bullet_time(delta)
	
	if combo_count > 0:
		combo_timer += delta
		if combo_timer > max_combo_time:
			end_combo()
	
	# Process active upgrades
	process_active_upgrades(delta)
	
	# Apply magnet effect if active
	var magnet_radius = upgrade_effects["magnet_effect"]
	if magnet_radius > 0 and is_instance_valid(launcher):
		attract_enemies_to_launcher(magnet_radius)
	
	# Apply explosion radius to all new explosions
	var explosion_scale = upgrade_effects["explosion_radius"]
	var explosions = get_tree().get_nodes_in_group("Explosions")
	for explosion in explosions:
		if not explosion.is_in_group("ScaledExplosions"):
			explosion.scale *= explosion_scale
			explosion.add_to_group("ScaledExplosions")
		
	time_since_last_spawn += delta
	if time_since_last_spawn >= spawn_timer / game_difficulty:
		spawn_enemy()
		time_since_last_spawn = 0.0
	
	game_difficulty += delta * 0.01
	enemy_speed = 70.0 + (game_difficulty * 10.0)
	
	if shapes_destroyed >= shapes_for_next_level:
		level_up()

func level_up():
	level_number += 1
	shapes_destroyed = 0
	shapes_for_next_level = 10 + (level_number * 2)
	score_multiplier = 1.0 + (level_number * 0.1)
	
	apply_level_theme()
	
	var level_up_label = Label.new()
	level_up_label.text = "LEVEL " + str(level_number)
	level_up_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.9))
	level_up_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.2, 0.3, 0.7))
	level_up_label.add_theme_font_size_override("font_size", 32)
	level_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Use the pixel font
	var pixel_font = load("res://assets/fonts/pixel_font.ttf")
	if pixel_font:
		level_up_label.add_theme_font_override("font", pixel_font)
	
	# Position at left side of screen
	level_up_label.position = Vector2(50, 80)
	level_up_label.modulate.a = 0
	add_child(level_up_label)
	
	var tween = create_tween()
	tween.tween_property(level_up_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.4)
	# Move down the screen
	tween.tween_property(level_up_label, "position:y", level_up_label.position.y + 100, 0.5).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(level_up_label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(level_up_label.queue_free)
	
	if level_number == 5 and not achievements["level_5"]["unlocked"]:
		# Add a small delay before showing achievement
		await get_tree().create_timer(0.1).timeout
		unlock_achievement("level_5")

func apply_level_theme():
	var theme_index = (level_number - 1) % level_themes.size()
	var current_theme = level_themes[theme_index]
	
	if background:
		var tween = create_tween()
		tween.tween_property(background, "modulate", current_theme.bg, 1.0)
	
	var score_fill_style = score_fill.get("theme_override_styles/panel")
	if score_fill_style:
		score_fill_style.bg_color = current_theme.accent

func spawn_initial_enemies():
	var screen_center_x = 550
	for i in range(3):
		var shape = shape_scene.instantiate()
		shape.position = Vector2(screen_center_x + (i - 1) * 100, -50 - i * 40)
		shape.shape_type = i % 3
		shape.color = randi() % 6
		configure_enemy(shape)
		add_child(shape)
		await get_tree().create_timer(0.25).timeout

func spawn_enemy():
	if not shape_scene:
		return
		
	var shape = shape_scene.instantiate()
	shape.position = find_suitable_spawn_position()
	shape.shape_type = randi() % 3
	shape.color = randi() % 6
	configure_enemy(shape)
	add_child(shape)
	
	# Apply multi_shot upgrade if active
	var multi_shot_count = upgrade_effects["multi_shot"]
	if multi_shot_count > 0:
		for i in range(multi_shot_count):
			var extra_shape = shape_scene.instantiate()
			extra_shape.position = find_suitable_spawn_position()
			extra_shape.shape_type = randi() % 3
			extra_shape.color = randi() % 6
			configure_enemy(extra_shape)
			add_child(extra_shape)
	
	# Original extra shape spawn logic
	if level_number > 3 and randf() < 0.2:
		for i in range(min(level_number - 3, 3)):
			if randf() < 0.3:
				var extra_shape = shape_scene.instantiate()
				extra_shape.position = find_suitable_spawn_position()
				extra_shape.shape_type = randi() % 3
				extra_shape.color = randi() % 6
				configure_enemy(extra_shape)
				add_child(extra_shape)

func find_suitable_spawn_position():
	var enemies = get_tree().get_nodes_in_group("Enemies")
	if enemies.size() == 0:
		return Vector2(550, -50)
		
	var screen_center_x = 550
	var min_spacing = 180.0
	var max_attempts = 12
	var spawn_width = 500
	
	for attempt in range(max_attempts):
		var x_pos = screen_center_x + ((-spawn_width/2) + (spawn_width * (float(attempt) / float(max_attempts - 1))))
		var extra_height = 0
		if attempt > max_attempts / 2:
			extra_height = (attempt - max_attempts / 2) * 50
		var y_pos = -50 - extra_height
		var spawn_pos = Vector2(x_pos, y_pos)
		
		var too_close = false
		for enemy in enemies:
			if spawn_pos.distance_to(enemy.position) < min_spacing:
				too_close = true
				break
				
		if not too_close:
			return spawn_pos
			
	return Vector2(550, -200 - randf() * 200)

func configure_enemy(enemy):
	enemy.add_to_group("Enemies")
	enemy.add_to_group("shapes")
	enemy.is_enemy = true
	enemy.target_position = Vector2(550, 720)
	enemy.move_speed = enemy_speed
	
	enemy.rotation_speed = randf_range(-2.0, 2.0)
	
	if enemy is RigidBody2D:
		enemy.lock_rotation = false
		enemy.angular_velocity = randf_range(-3.0, 3.0)
		enemy.angular_damp = 0.0
		
	if level_number > 2 and randf() < 0.15:
		configure_special_enemy(enemy)
	elif level_number > 3 and randf() < 0.2:
		enemy.health = 2
		enemy.scale = Vector2(1.2, 1.2)
		if "point_value" in enemy:
			enemy.point_value = 2
	elif level_number > 5 and randf() < 0.15:
		enemy.health = 3
		enemy.scale = Vector2(1.4, 1.4)
		if "point_value" in enemy:
			enemy.point_value = 3
	
	if level_number > 2 and randf() < 0.05:
		enemy.modulate = Color(1.0, 0.8, 0.2)
		if "point_value" in enemy:
			enemy.point_value = enemy.point_value * 2

func configure_special_enemy(enemy):
	enemy.is_special = true
	enemy.special_type = randi() % 3
	
	if enemy.special_type == 0:
		enemy.modulate = Color(0.9, 0.5, 1.0)
		enemy.health = 2
		enemy.scale = Vector2(1.1, 1.1)
		enemy.point_value = 3
		enemy.add_to_group("Splitters")
	elif enemy.special_type == 1:
		enemy.modulate = Color(0.7, 0.7, 0.7)
		enemy.health = 4
		enemy.scale = Vector2(1.3, 1.3)
		enemy.point_value = 5
		enemy.add_to_group("Armored")
	elif enemy.special_type == 2:
		enemy.modulate = Color(1.0, 0.4, 0.3)
		enemy.health = 1
		enemy.scale = Vector2(1.2, 1.2)
		enemy.point_value = 4
		enemy.explosion_radius = 150
		enemy.add_to_group("Bombers")

func _on_shapes_popped(count):
	shapes_destroyed += 1
	
	if not achievements["first_blood"]["unlocked"]:
		unlock_achievement("first_blood")
	
	update_combo()
	
	var multiplier = count if count > 1 else 1
	
	if count > 3:
		multiplier = 3 + sqrt(count - 3)
	
	var combo_multiplier = min(combo_count * 0.2, 2.0)
	
	# Apply damage boost and score multiplier from upgrades
	var damage_bonus = upgrade_effects["damage_boost"]
	var score_bonus = upgrade_effects["score_multiplier"]
	
	var final_score = int((1.0 + ((level_number - 1) * 0.2)) * multiplier * score_multiplier * (1.0 + combo_multiplier) * damage_bonus * score_bonus)
	score += final_score
	
	if score >= 10000 and not achievements["score_10k"]["unlocked"]:
		unlock_achievement("score_10k")
	
	SignalBus.emit_score_changed(score)
	
	if combo_count >= 5:
		shake_screen(combo_count * 0.5, 0.2)

func update_combo():
	combo_timer = 0
	combo_count += 1
	
	if combo_count >= 10 and not achievements["combo_master"]["unlocked"]:
		unlock_achievement("combo_master")
	
	# Check for combo-based upgrades
	check_combo_upgrades()
	
	combo_label.text = str(combo_count) + "x"
	combo_label.visible = true
	combo_label.position = Vector2(50, 120)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Use the pixel font
	var pixel_font = load("res://assets/fonts/pixel_font.ttf")
	if pixel_font:
		combo_label.add_theme_font_override("font", pixel_font)
	
	var tween = create_tween()
	tween.kill() # Stop any existing tween
	tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.1)
	
	if combo_count >= 5:
		combo_label.add_theme_font_size_override("font_size", min(28 + min(combo_count, 20), 40))
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.5 + min(combo_count * 0.05, 0.5), 0.0, 1.0))
		
		# Make combo notification move down after a delay
		await get_tree().create_timer(0.5).timeout
		var move_tween = create_tween()
		move_tween.tween_property(combo_label, "position:y", combo_label.position.y + 80, 0.4)

func check_combo_upgrades():
	for threshold in combo_upgrades.keys():
		if combo_count == threshold:
			var upgrade_type = combo_upgrades[threshold]
			apply_upgrade(upgrade_type)
			break

func end_combo():
	combo_count = 0
	combo_timer = 0
	
	# Fade out combo label
	var tween = create_tween()
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): combo_label.visible = false; combo_label.modulate.a = 1.0)

func apply_upgrade(upgrade_type):
	var upgrade_level = 1
	
	# If already active, increase level
	if upgrade_type in active_upgrades:
		upgrade_level = active_upgrades[upgrade_type] + 1
		if upgrade_level > upgrade_max_levels[upgrade_type]:
			upgrade_level = upgrade_max_levels[upgrade_type]
	
	active_upgrades[upgrade_type] = upgrade_level
	
	# Scale effect based on level
	match upgrade_type:
		"speed_boost":
			upgrade_effects["speed_boost"] = 1.0 + (upgrade_level * 0.3)
			if is_instance_valid(launcher):
				launcher.launch_speed *= upgrade_effects["speed_boost"]
		"damage_boost":
			upgrade_effects["damage_boost"] = 1.0 + (upgrade_level * 0.5)
		"bullet_time":
			upgrade_effects["bullet_time"] = 0.8 - (upgrade_level * 0.2)
			Engine.time_scale = upgrade_effects["bullet_time"]
			bullet_time_active = true
		"score_multiplier":
			upgrade_effects["score_multiplier"] = 1.0 + (upgrade_level * 0.5)
			score_multiplier *= upgrade_effects["score_multiplier"]
		"magnet_effect":
			upgrade_effects["magnet_effect"] = upgrade_level * 100.0
		"multi_shot":
			upgrade_effects["multi_shot"] = upgrade_level
		"explosion_radius":
			upgrade_effects["explosion_radius"] = 1.0 + (upgrade_level * 0.5)
	
	# Start or reset the timer
	if not upgrade_type in upgrade_timers:
		upgrade_timers[upgrade_type] = 0.0
	else:
		upgrade_timers[upgrade_type] = 0.0
	
	# Show upgrade notification
	show_upgrade_notification(upgrade_type, upgrade_level)

func process_active_upgrades(delta):
	var upgrades_to_remove = []
	
	for upgrade_type in upgrade_timers.keys():
		upgrade_timers[upgrade_type] += delta
		
		if upgrade_timers[upgrade_type] >= upgrade_durations[upgrade_type]:
			end_upgrade(upgrade_type)
			upgrades_to_remove.append(upgrade_type)
	
	for upgrade_type in upgrades_to_remove:
		upgrade_timers.erase(upgrade_type)
		active_upgrades.erase(upgrade_type)

func end_upgrade(upgrade_type):
	match upgrade_type:
		"speed_boost":
			if is_instance_valid(launcher):
				launcher.launch_speed /= upgrade_effects["speed_boost"]
			upgrade_effects["speed_boost"] = 1.0
		"damage_boost":
			upgrade_effects["damage_boost"] = 1.0
		"bullet_time":
			Engine.time_scale = 1.0
			bullet_time_active = false
			upgrade_effects["bullet_time"] = 1.0
		"score_multiplier":
			score_multiplier /= upgrade_effects["score_multiplier"]
			upgrade_effects["score_multiplier"] = 1.0
		"magnet_effect":
			upgrade_effects["magnet_effect"] = 0.0
		"multi_shot":
			upgrade_effects["multi_shot"] = 0
		"explosion_radius":
			upgrade_effects["explosion_radius"] = 1.0

func show_upgrade_notification(upgrade_type, level):
	var upgrade_name = ""
	var color = Color(1, 1, 1)
	
	match upgrade_type:
		"speed_boost":
			upgrade_name = "SPEED+"
			color = Color(0.3, 0.8, 1.0)
		"damage_boost":
			upgrade_name = "DAMAGE+"
			color = Color(1.0, 0.3, 0.3)
		"bullet_time":
			upgrade_name = "SLOW TIME"
			color = Color(0.8, 0.3, 1.0)
		"score_multiplier":
			upgrade_name = "SCORE+"
			color = Color(1.0, 0.9, 0.3)
		"magnet_effect":
			upgrade_name = "MAGNET"
			color = Color(0.5, 0.5, 1.0)
		"multi_shot":
			upgrade_name = "MULTI"
			color = Color(1.0, 0.6, 0.2)
		"explosion_radius":
			upgrade_name = "BLAST+"
			color = Color(1.0, 0.4, 0.0)
	
	var stars = ""
	for i in range(level):
		stars += "★"
	
	var upgrade_label = Label.new()
	upgrade_label.text = upgrade_name + " " + stars
	upgrade_label.add_theme_color_override("font_color", color)
	upgrade_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.1, 0.1, 0.7))
	upgrade_label.add_theme_font_size_override("font_size", 20)
	upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Use the pixel font
	var pixel_font = load("res://assets/fonts/pixel_font.ttf")
	if pixel_font:
		upgrade_label.add_theme_font_override("font", pixel_font)
	
	# Position on left side
	upgrade_label.position = Vector2(50, 180)
	upgrade_label.modulate.a = 0
	add_child(upgrade_label)
	
	var tween = create_tween()
	tween.tween_property(upgrade_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.5)
	# Move down and fade
	tween.tween_property(upgrade_label, "position:y", upgrade_label.position.y + 70, 0.6).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(upgrade_label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(upgrade_label.queue_free)

func _on_special_enemy_destroyed(enemy_position: Vector2, enemy_type: String):
	score += 200
	update_score_display(score)
	update_combo()
	
	var explosion_position = enemy_position
	if enemy_type == "blue":
		explosion_position = Vector2(explosion_position.x, explosion_position.y)
		var explosion = explosion_scene.instantiate()
		explosion.position = explosion_position
		explosion.scale = Vector2(2, 2)
		explosion.damage_amount = 50
		add_child(explosion)
	
	if enemy_type == "green":
		for i in range(5):
			var small_explosion = explosion_scene.instantiate()
			var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
			small_explosion.position = explosion_position + offset
			small_explosion.scale = Vector2(1, 1)
			small_explosion.damage_amount = 20
			add_child(small_explosion)
	
	if enemy_type == "red":
		var big_explosion = explosion_scene.instantiate()
		big_explosion.position = explosion_position
		big_explosion.scale = Vector2(3, 3)
		big_explosion.damage_amount = 75
		add_child(big_explosion)

func _on_bullet_time_activated():
	bullet_time_active = true
	bullet_time_duration = 0.0
	Engine.time_scale = 0.4

func process_bullet_time(delta):
	bullet_time_duration += delta / Engine.time_scale
	
	if bullet_time_duration >= bullet_time_max:
		bullet_time_active = false
		Engine.time_scale = 1.0

func shake_screen(intensity: float = 10.0, duration: float = 0.3):
	screen_shake_active = true
	screen_shake_intensity = intensity
	screen_shake_duration = duration

func process_screen_shake(delta):
	if screen_shake_duration <= 0:
		screen_shake_active = false
		main_camera.offset = Vector2.ZERO
		return
	
	screen_shake_duration -= delta
	
	var rand_offset = Vector2(
		randf_range(-1, 1) * screen_shake_intensity,
		randf_range(-1, 1) * screen_shake_intensity
	)
	
	main_camera.offset = rand_offset
	screen_shake_intensity = lerp(screen_shake_intensity, 0.0, delta * 2)

func unlock_achievement(achievement_id):
	if achievement_id in achievements:
		achievements[achievement_id]["unlocked"] = true
		
		var achievement_label = Label.new()
		achievement_label.text = "ACHIEVED: " + achievements[achievement_id]["name"]
		achievement_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.9))
		achievement_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.2, 0.0, 0.6))
		achievement_label.add_theme_font_size_override("font_size", 18)
		achievement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Use the pixel font
		var pixel_font = load("res://assets/fonts/pixel_font.ttf")
		if pixel_font:
			achievement_label.add_theme_font_override("font", pixel_font)
		
		# Position on left side of screen
		achievement_label.position = Vector2(50, 150)
		achievement_label.modulate.a = 0
		add_child(achievement_label)
		
		var tween = create_tween()
		tween.tween_property(achievement_label, "modulate:a", 1.0, 0.2)
		tween.tween_interval(0.3)
		# Move down the screen
		tween.tween_property(achievement_label, "position:y", achievement_label.position.y + 120, 0.6).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(achievement_label, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
		tween.tween_callback(achievement_label.queue_free)

func _on_shape_launched(_shape):
	pass

func update_score_display(new_score):
	if score_fill:
		score_fill.set_size(Vector2(clamp(new_score / 1000.0 * 400, 0, 400), 30))
		
	if score_label:
		score_label.text = "Score: " + str(new_score)
	
	if current_score_label:
		current_score_label.text = "Score: " + str(new_score)

func _on_game_over():
	if is_game_over:
		return
		
	is_game_over = true
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.has_method("destroy"):
			enemy.destroy()
	
	create_tween().tween_interval(0.5).finished.connect(show_game_over_screen)

func show_game_over_screen():
	if is_instance_valid(self) and high_score_panel_scene:
		var high_score_panel = high_score_panel_scene.instantiate()
		add_child(high_score_panel)
		
		SignalBus.emit_new_high_score(score, 1)

func update_high_score_display():
	if high_score_label:
		high_score_label.text = "High: 0"
		
		if crown_icon:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(crown_icon, "scale", Vector2(0.6, 0.6), 0.1)
			tween.tween_property(crown_icon, "scale", Vector2(0.5, 0.5), 0.1)

func _on_game_ended():
	game_running = false
	
func _on_score_changed(new_score):
	score = new_score
	update_score_display(new_score)

func _on_viewport_size_changed():
	setup_spawn_positions()
	
	if is_instance_valid(launcher):
		var viewport_rect = get_viewport().get_visible_rect()
		launcher.position.y = viewport_rect.size.y - 50
		launcher.position.x = viewport_rect.size.x / 2

func setup_game_difficulty():
	current_min_difficulty = 0.1
	current_max_difficulty = 0.6
	
	current_difficulty = current_min_difficulty

func setup_spawn_positions():
	spawn_positions.clear()
	
	var viewport_rect = get_viewport().get_visible_rect()
	despawn_position_y = viewport_rect.size.y + 100
	
	var spacing = 150
	var margin = 100
	var positions_count = int((viewport_rect.size.x - 2 * margin) / spacing)
	
	for i in range(positions_count):
		var x_pos = margin + i * spacing
		spawn_positions.append(Vector2(x_pos, -50))

func setup_launcher():
	if is_instance_valid(launcher):
		launcher.queue_free()
	
	if shape_scene:
		launcher = shape_scene.instantiate()
		add_child(launcher)
		
		var viewport_rect = get_viewport().get_visible_rect()
		launcher.position = Vector2(viewport_rect.size.x / 2, viewport_rect.size.y - 50)

func _on_enemy_destroyed(enemy_position: Vector2):
	score += 100
	update_score_display(score)
	update_combo()
	
	if randf() < 0.2:  # 20% chance
		var powerup = powerup_scene.instantiate()
		powerup.position = enemy_position
		add_child(powerup)
	
	var explosion = explosion_scene.instantiate()
	explosion.position = enemy_position
	explosion.scale = Vector2(1, 1)
	explosion.damage_amount = 25
	add_child(explosion)

func _on_enemy_reached_bottom(enemy):
	if is_instance_valid(enemy):
		current_shapes.erase(enemy)
		
		if not is_game_over:
			is_game_over = true

func attract_enemies_to_launcher(radius):
	if not is_instance_valid(launcher):
		return
		
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var launcher_pos = launcher.global_position
	
	for enemy in enemies:
		var distance = enemy.global_position.distance_to(launcher_pos)
		if distance < radius:
			var direction = (launcher_pos - enemy.global_position).normalized()
			var force = (1.0 - (distance / radius)) * 300.0
			
			if enemy is RigidBody2D:
				enemy.apply_central_force(direction * force)
			else:
				enemy.position += direction * force * get_process_delta_time()

func setup_background():
	if background:
		background.anchor_right = 1.0
		background.anchor_bottom = 1.0
		background.expand_mode = 1
		background.stretch_mode = 6  # STRETCH_KEEP_ASPECT_COVERED
		adjust_background_size()

func adjust_background_size():
	if background:
		var viewport_size = get_viewport().get_visible_rect().size
		background.size = viewport_size
		background.position = Vector2(0, 0)
		
		# Force a redraw for proper scaling
		if background.texture:
			var current_texture = background.texture
			background.texture = null
			await get_tree().process_frame
			background.texture = current_texture
