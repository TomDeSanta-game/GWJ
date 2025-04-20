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
@onready var upgrades_label = get_node_or_null("UpgradesDisplay/UpgradesLabel")
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
var upgrades = {}
var game_running: bool = false

var enemy_speed: float = 70.0
var time_since_last_spawn: float = 0.0

var store_instance = null
var store_scene = null
var store_visible = false

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

var temp_in_store: bool = false

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
		upgrades = high_score_manager.get_player_upgrades().duplicate()
		if Log:
			Log.debug("GC: Got money: " + str(money) + " and upgrades: " + str(upgrades))
	else:
		if Log:
			Log.error("GC: High score manager doesn't have required methods")
		money = 0
		upgrades = {"multi_shot": 1}
	
	if launcher:
		if Log:
			Log.debug("GC: _ready called, launcher reference: " + str(launcher != null))
			Log.debug("GC: launcher node path: " + str(launcher.get_path()))
			Log.debug("GC: launcher script instance_id: " + str(launcher.get_instance_id()))
		
		launcher_path = launcher.get_path()
		
		if "multi_shot_count" in launcher:
			launcher.multi_shot_count = upgrades.get("multi_shot", 1)
			if Log:
				Log.debug("GC: Setting initial multi_shot_count to: " + str(launcher.multi_shot_count))
	else:
		if Log:
			Log.debug("GC: launcher is null!")
	
	if not SignalBus.game_over_triggered.is_connected(_on_game_ended):
		SignalBus.game_over_triggered.connect(_on_game_ended)
	
	if not SignalBus.score_changed.is_connected(_on_score_changed):
		SignalBus.score_changed.connect(_on_score_changed)
	
	if not SignalBus.money_changed.is_connected(_on_money_changed):
		SignalBus.money_changed.connect(_on_money_changed)
	
	if not SignalBus.upgrades_changed.is_connected(_on_upgrades_changed):
		SignalBus.upgrades_changed.connect(_on_upgrades_changed)
	
	if upgrades.size() == 0:
		upgrades = {"multi_shot": 1}
	
	update_launcher_with_upgrades()
	
	SignalBus.emit_upgrades_changed(upgrades)
	
	randomize()
	
	setup_input_map()
	connect_signals()
	spawn_initial_enemies()
	update_high_score_display()
	update_money_display()
	
	create_simple_store()
	
	SignalBus.emit_upgrades_changed(upgrades)
	
	if launcher and Log:
		Log.debug("GC: Final launcher multi_shot_count: " + str(launcher.multi_shot_count))

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
	
	if not SignalBus.upgrades_changed.is_connected(func(new_upgrades): upgrades = new_upgrades; update_upgrades_display()):
		SignalBus.upgrades_changed.connect(func(new_upgrades): upgrades = new_upgrades; update_upgrades_display())

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
	
	if InputMap.has_action("open"):
		InputMap.erase_action("open")
		
	InputMap.add_action("open")
	var open_key = InputEventKey.new()
	open_key.keycode = KEY_E
	open_key.pressed = true
	InputMap.action_add_event("open", open_key)

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

func _input(event):
	if event is InputEventKey and event.pressed and !event.is_echo() and event.keycode == KEY_E:
		toggle_store_direct()

func update_pause_state():
	var store = $CanvasLayer.get_node_or_null("StoreControl")
	get_tree().paused = store and store.visible
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_store_direct():
	if store_instance == null or !is_instance_valid(store_instance):
		create_simple_store()
		if store_instance == null:
			if Log:
				Log.error("GC: Failed to create store instance")
			return
	
	store_visible = !store_visible
	store_instance.visible = store_visible
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var parent = store_instance.get_parent()
	if parent and parent.visible != store_visible:
		parent.visible = store_visible
	
	if store_visible:
		if Log:
			Log.debug("GC: Opening store with money:", money, " upgrades:", upgrades)
			if store_instance.has_method("update_with_player_data"):
				store_instance.update_with_player_data(money, upgrades)
				Log.debug("GC: Updated store with player data")
			else:
				store_instance.player_money = money
				store_instance.player_upgrades = upgrades.duplicate()
				if store_instance.has_method("update_money_display"):
					store_instance.update_money_display()
				if store_instance.has_method("setup_price_displays"):
					store_instance.setup_price_displays()
				Log.debug("GC: Manually set store data")
		get_viewport().set_input_as_handled()
	else:
		if Log:
			Log.debug("GC: Closing store")
		get_tree().paused = store_visible
		if Log:
			Log.debug("GC: Pause state set to", store_visible)

func get_upgrades():
	return upgrades
	
func set_upgrades(new_upgrades):
	if Log:
		Log.debug("GC: Setting upgrades to: " + str(new_upgrades))
	upgrades = new_upgrades.duplicate()
	if Log:
		Log.debug("GC: Set upgrades to: ", upgrades)
	update_launcher_with_upgrades()
	SignalBus.emit_upgrades_changed(upgrades)

func update_upgrades_display():
	if not upgrades_label:
		return
		
	var upgrade_text = "Upgrades: "
	for upgrade in upgrades:
		upgrade_text += upgrade + ": " + str(upgrades[upgrade]) + " "
	upgrades_label.text = upgrade_text

func create_simple_store():
	store_scene = preload("res://scenes/Store.tscn")
	if store_scene:
		if Log:
			Log.debug("GC: Creating store instance")
		store_instance = store_scene.instantiate()
		store_instance.name = "StoreControl"
		store_instance.visible = false
		store_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		
		if "player_money" in store_instance:
			store_instance.player_money = money
		if "player_upgrades" in store_instance:
			store_instance.player_upgrades = upgrades.duplicate()
		
		if Log:
			Log.debug("GC: Setup complete, adding to canvas layer")
		if canvas_layer:
			canvas_layer.add_child(store_instance)
			store_visible = false
		else:
			if Log:
				Log.error("GC: No canvas layer found to add store to!")
	else:
		if Log:
			Log.error("GC: Failed to load store scene!")

func update_launcher_with_upgrades():
	if launcher and is_instance_valid(launcher):
		if Log:
			Log.debug("GC: Updating launcher with upgrades: ", upgrades)
		
		if "multi_shot" in upgrades:
			launcher.multi_shot_count = upgrades["multi_shot"]
			if Log:
				Log.debug("GC: Set launcher.multi_shot_count directly to: ", launcher.multi_shot_count)
		
		if "launch_speed" in upgrades:
			var base_speed = 350.0
			var speed_increment = 50.0
			launcher.launch_speed = base_speed + (upgrades.get("launch_speed", 0) * speed_increment)
			if Log:
				Log.debug("GC: Updated launch_speed to: ", launcher.launch_speed)
			
		if "cooldown" in upgrades:
			var base_cooldown = 0.5
			var cooldown_reduction = 0.05
			launcher.cooldown_time = max(0.1, base_cooldown - (upgrades.get("cooldown", 0) * cooldown_reduction))
			if Log:
				Log.debug("GC: Updated cooldown_time to: ", launcher.cooldown_time)
		
		if Log:
			Log.debug("GC: Forcing launcher to update with upgrades: ", upgrades)
		if launcher.has_method("_on_upgrades_changed"):
			launcher._on_upgrades_changed(upgrades)
			if Log:
				Log.debug("GC: Verified multi_shot_count is now: ", launcher.multi_shot_count)
		else:
			if Log:
				Log.error("GC: ERROR - launcher does not have _on_upgrades_changed method")
	else:
		if Log:
			Log.warning("GC: WARNING - No valid launcher found to update")

func _on_multi_shot_purchased():
	if not upgrades.has("multi_shot"):
		upgrades["multi_shot"] = 1
	
	upgrades["multi_shot"] += 1
	
	if launcher:
		launcher.multi_shot_count = upgrades["multi_shot"] 
	
	SignalBus.emit_upgrades_changed(upgrades)

func _on_game_ended():
	game_running = false
	
func _on_score_changed(new_score):
	score = new_score
	update_score_display(new_score)

func _on_money_changed(new_money):
	money = new_money
	update_money_display()

func _on_upgrades_changed(new_upgrades):
	if Log:
		Log.debug("GC: _on_upgrades_changed received: ", new_upgrades)
	upgrades = new_upgrades.duplicate()
	update_upgrades_display()
	
	if launcher and is_instance_valid(launcher):
		if Log:
			Log.debug("GC: Launcher exists, updating...")
		if "multi_shot" in upgrades and launcher.has_method("_on_upgrades_changed"):
			launcher._on_upgrades_changed(upgrades)
			
			if Log:
				Log.debug("GC: Verifying multi_shot_count in launcher: " + str(launcher.multi_shot_count))
			if Log:
				Log.debug("GC: Launcher multi_shot_count after update: ", launcher.multi_shot_count)
	else:
		if Log:
			Log.debug("GC: Launcher is not valid in _on_upgrades_changed")
	
	update_launcher_with_upgrades()

func handle_enemy_spawning(_delta):
	pass

func update_difficulty(_delta):
	pass

func advance_level():
	pass

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

func set_money(new_money):
	money = new_money
	update_money_display()
	if Log:
		Log.debug("GC: Set money to: ", money)

func force_multishot_upgrade():
	if Log:
		Log.debug("GC: Force upgrading multi-shot")
	upgrades["multi_shot"] = 3
	
	if launcher and is_instance_valid(launcher):
		launcher.multi_shot_count = upgrades["multi_shot"]
		if Log:
			Log.debug("GC: Force-set launcher.multi_shot_count to:", launcher.multi_shot_count)
		
		if launcher.has_method("_on_upgrades_changed"):
			launcher._on_upgrades_changed(upgrades)
	
	SignalBus.emit_upgrades_changed(upgrades)
	return true

func force_launch_speed_upgrade():
	if Log:
		Log.debug("GC: Force upgrading launch speed")
	upgrades["launch_speed"] = 3
	
	if launcher and is_instance_valid(launcher):
		launcher.launch_speed = 350.0 + (upgrades["launch_speed"] * 50.0)
		if Log:
			Log.debug("GC: Force-set launcher.launch_speed to:", launcher.launch_speed)
		
		if launcher.has_method("_on_upgrades_changed"):
			launcher._on_upgrades_changed(upgrades)
	
	SignalBus.emit_upgrades_changed(upgrades)
	return true

func _on_item_pressed(item_index):
	if item_index == 0:
		_on_multi_shot_purchased()
