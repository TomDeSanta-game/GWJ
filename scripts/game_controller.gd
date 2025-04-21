extends Node

@onready var Log = get_node_or_null("/root/Log")

@export var shape_scene: PackedScene
@export var spawn_timer: float = 2.0
@export var max_score_width: float = 300.0
@export var game_difficulty: float = 1.5
@export var money_per_hit: int = 15
@export var money_per_shot: int = 8
@export var high_score_panel_scene: PackedScene

@onready var scene_manager = get_node("/root/SceneManager")
@onready var score_fill = get_node_or_null("ScoreDisplay/ScoreFill")
@onready var score_label = get_node_or_null("ScoreDisplay/ScoreLabel")
@onready var current_score_label = get_node_or_null("CurrentScoreDisplay/CurrentScoreLabel")
@onready var high_score_label = get_node_or_null("HighScoreDisplay/HighScoreLabel") 
@onready var crown_icon = get_node_or_null("HighScoreDisplay/CrownIcon")
@onready var money_label = get_node_or_null("MoneyDisplay/MoneyLabel")
@onready var coin_icon = get_node_or_null("MoneyDisplay/CoinIcon")
@onready var coin_shine = coin_icon.get_node_or_null("CoinShine") if coin_icon else null
@onready var launcher = get_node_or_null("Launcher")
@onready var canvas_layer = $CanvasLayer
@onready var background = $Background as TextureRect
var high_score_manager = null

var score: int = 0
var money: int = 0
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

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_running = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
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
	
	if high_score_manager != null and high_score_manager.has_method("get_player_money"):
		money = high_score_manager.get_player_money()
		if Log:
			Log.debug("GC: Got money: " + str(money))
	else:
		if Log:
			Log.error("GC: High score manager doesn't have required methods")
		money = 0
	
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
	
	if not SignalBus.money_changed.is_connected(_on_money_changed):
		SignalBus.money_changed.connect(_on_money_changed)
	
	randomize()
	
	setup_input_map()
	connect_signals()
	spawn_initial_enemies()
	update_high_score_display()
	update_money_display()

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
	
	if not SignalBus.money_changed.is_connected(func(new_money): money = new_money; update_money_display()):
		SignalBus.money_changed.connect(func(new_money): money = new_money; update_money_display())
	
	if not SignalBus.high_scores_updated.is_connected(func(_high_scores): update_high_score_display()):
		SignalBus.high_scores_updated.connect(func(_high_scores): update_high_score_display())

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

func _process(delta):
	if is_game_over:
		return
		
	time_since_last_spawn += delta
	if time_since_last_spawn >= spawn_timer / game_difficulty:
		spawn_enemy()
		time_since_last_spawn = 0.0
	
	game_difficulty += delta * 0.01
	enemy_speed = 70.0 + (game_difficulty * 10.0)
	
	if shapes_destroyed >= shapes_for_next_level:
		level_number += 1
		shapes_destroyed = 0
		shapes_for_next_level = 10 + (level_number * 2)
		score_multiplier = 1.0 + (level_number * 0.1)
		money += 25 * level_number
		SignalBus.emit_money_changed(money)

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
		
	if level_number > 3 and randf() < 0.2:
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
		if "money_value" in enemy:
			enemy.money_value = 50
		if "point_value" in enemy:
			enemy.point_value = enemy.point_value * 2

func _on_shapes_popped(count):
	shapes_destroyed += 1
	var multiplier = count if count > 1 else 1
	
	if count > 3:
		multiplier = 3 + sqrt(count - 3)
	
	score += int((1.0 + ((level_number - 1) * 0.2)) * multiplier * score_multiplier)
	SignalBus.emit_score_changed(score)
	
	var effective_count = min(count, 5)
	var bonus = 0
	if count >= 3:
		bonus = count * 5
	
	money += money_per_hit * effective_count + bonus
	SignalBus.emit_money_changed(money)

func _on_shape_launched(_shape):
	money += money_per_shot
	SignalBus.emit_money_changed(money)

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

func update_money_display():
	if not money_label:
		return
		
	var current_money_value = 0
	var current_text = money_label.text
	if current_text.begins_with("Money: $"):
		current_money_value = int(current_text.substr(8))
	
	money_label.text = "Money: $" + str(money)
	
	if money > current_money_value and current_money_value > 0 and coin_icon:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(coin_icon, "position:y", -5, 0.05)
		tween.tween_property(coin_icon, "position:y", 0, 0.05)
		
		if coin_shine:
			tween.parallel().tween_property(coin_shine, "scale", Vector2(0.5, 0.5), 0.075)
			tween.tween_property(coin_shine, "scale", Vector2(0.3, 0.3), 0.075)

func _on_game_ended():
	game_running = false
	
func _on_score_changed(new_score):
	score = new_score
	update_score_display(new_score)

func _on_money_changed(new_money):
	money = new_money
	update_money_display()

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

func _on_enemy_destroyed(enemy):
	if is_instance_valid(enemy):
		current_shapes.erase(enemy)
	
	money += money_per_hit
	update_money_display()

func _on_enemy_reached_bottom(enemy):
	if is_instance_valid(enemy):
		current_shapes.erase(enemy)
		
		if not is_game_over:
			is_game_over = true
