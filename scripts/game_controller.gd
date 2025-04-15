extends Node

@export var shape_scene: PackedScene
@export var spawn_timer: float = 1.5
@export var max_score_width: float = 300.0
@export var game_difficulty: float = 1.0
@export var money_per_hit: int = 25
@export var money_per_shot: int = 10
@export var high_score_panel_scene: PackedScene

var score: int = 0
var money: int = 0
var is_game_over: bool = false
var level_number: int = 1
var shapes_destroyed: int = 0
var shapes_for_next_level: int = 20
var is_shop_open: bool = false

var enemy_speed: float = 80.0
var time_since_last_spawn: float = 0.0

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
	update_high_score_display()
	update_money_display()

func connect_signals() -> void:
	SignalBus.shapes_popped.connect(_on_shapes_popped)
	SignalBus.game_over_triggered.connect(_on_game_over)
	SignalBus.score_changed.connect(update_score_display)
	SignalBus.shape_launched.connect(_on_shape_launched)
	SignalBus.money_changed.connect(func(new_money): update_money_display())
	SignalBus.high_scores_updated.connect(func(_high_scores): update_high_score_display())

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
	
	if not InputMap.has_action("toggle_shop"):
		InputMap.add_action("toggle_shop")
		var shop_key = InputEventKey.new()
		shop_key.keycode = KEY_S
		shop_key.pressed = true
		InputMap.action_add_event("toggle_shop", shop_key)

func _process(delta: float) -> void:
	if is_game_over:
		return
		
	handle_enemy_spawning(delta)
	update_difficulty(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_shop"):
		toggle_shop()

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

func spawn_initial_enemies() -> void:
	for i in range(3):
		var x_pos = 150 + i * 170
		var spawn_pos = Vector2(x_pos, -50 - i * 40)
		
		var shape := shape_scene.instantiate()
		shape.position = spawn_pos
		configure_enemy(shape)
		add_child(shape)
		
		await get_tree().create_timer(0.1).timeout

func handle_enemy_spawning(delta: float) -> void:
	time_since_last_spawn += delta
	if time_since_last_spawn >= spawn_timer / game_difficulty:
		spawn_enemy()
		time_since_last_spawn = 0.0

func spawn_enemy() -> void:
	if not shape_scene:
		return
		
	var shape := shape_scene.instantiate()
	
	var spawn_pos := find_suitable_spawn_position()
	shape.position = spawn_pos
	
	configure_enemy(shape)
	
	add_child(shape)

func find_suitable_spawn_position() -> Vector2:
	var min_spacing := 150.0
	var max_attempts := 25
	var attempts := 0
	var x_pos := randf_range(70, 570)
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
			
		x_pos = 70 + (570 - 70) * (float(attempts) / float(max_attempts - 1))
		spawn_pos = Vector2(x_pos, -50)
		attempts += 1
		
		if attempts > max_attempts / 2:
			spawn_pos.y = -50 - (attempts - max_attempts / 2) * 20

	return spawn_pos

func configure_enemy(enemy) -> void:
	enemy.add_to_group("Enemies")
	enemy.add_to_group("shapes")
	enemy.is_enemy = true
	enemy.target_position = Vector2(320, 720)
	enemy.move_speed = enemy_speed
	
	if level_number > 3 and randf() < 0.2:
		enemy.health = 2
		enemy.scale = Vector2(1.2, 1.2)
	
	if level_number > 5 and randf() < 0.1:
		enemy.health = 3
		enemy.scale = Vector2(1.4, 1.4)

func check_enemies_reached_bottom() -> void:
	var enemies := get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.position.y > 700:
			_on_game_over()
			return

func toggle_shop() -> void:
	if is_shop_open:
		close_shop()
	else:
		open_shop()

func open_shop() -> void:
	var shop = $Store
	if shop:
		shop.visible = true
		shop.scale = Vector2(1.0, 1.0)
		
		shop.anchor_left = 0.5
		shop.anchor_top = 0.5
		shop.anchor_right = 0.5
		shop.anchor_bottom = 0.5
		shop.position = Vector2.ZERO
		
		is_shop_open = true
		get_tree().paused = true
	else:
		print("Shop not found at Main/Store")

func close_shop() -> void:
	var shop = $Store
	if shop:
		shop.visible = false
	is_shop_open = false
	get_tree().paused = false

func _on_shapes_popped(count: int) -> void:
	shapes_destroyed += 1
	
	var level_multiplier = 1.0 + ((level_number - 1) * 0.2)
	var points = int(1 * level_multiplier)
	
	if count > 1:
		points *= count
	
	score += points
	SignalBus.emit_score_changed(score)
	
	money += money_per_hit * count
	SignalBus.emit_money_changed(money)

func _on_shape_launched(_shape: Node) -> void:
	money += money_per_shot
	SignalBus.emit_money_changed(money)

func update_score_display(new_score: int) -> void:
	var score_fill = get_node_or_null("ScoreDisplay/ScoreFill")
	if score_fill:
		var max_width = 400
		var fill_width = clamp(new_score / 1000.0 * max_width, 0, max_width)
		score_fill.set_size(Vector2(fill_width, 30))
		
	var score_label = get_node_or_null("ScoreDisplay/ScoreLabel")
	if score_label:
		score_label.text = "Score: " + str(new_score)
	
	var current_score_label = get_node_or_null("CurrentScoreDisplay/CurrentScoreLabel")
	if current_score_label:
		current_score_label.text = "Score: " + str(new_score)

func safe_tween(target_node: Node = null) -> Tween:
	var tween = create_tween()
	if tween == null and target_node:
		tween = target_node.create_tween()
	
	return tween

func _on_game_over() -> void:
	if is_game_over:
		return
		
	is_game_over = true
	
	var enemies := get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.has_method("destroy"):
			enemy.destroy()
	
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func(): show_game_over_screen())

func pause_game() -> void:
	get_tree().paused = true

func show_game_over_screen() -> void:
	if high_score_panel_scene:
		var high_score_panel = high_score_panel_scene.instantiate()
		add_child(high_score_panel)
		
		var high_score_mgr = get_node("/root/HighScoreManager")
		if high_score_mgr and high_score_mgr.is_high_score(score):
			var position = 0
			var high_scores = high_score_mgr.get_high_scores()
			
			for i in range(high_scores.size()):
				if score > high_scores[i]:
					position = i
					break
				elif i == high_scores.size() - 1 and high_scores.size() < high_score_mgr.MAX_HIGH_SCORES:
					position = high_scores.size()
			
			SignalBus.emit_new_high_score(score, position + 1)
	else:
		print("Error: High Score Panel scene not assigned")

func update_high_score_display() -> void:
	var high_score_label = get_node_or_null("HighScoreDisplay/HighScoreLabel")
	if high_score_label:
		var high_score_mgr = get_node("/root/HighScoreManager")
		if high_score_mgr:
			var high_scores = high_score_mgr.get_high_scores()
			if high_scores.size() > 0:
				high_score_label.text = "High: " + str(high_scores[0])
				
				var crown_icon = get_node_or_null("HighScoreDisplay/CrownIcon")
				if crown_icon:
					var tween = create_tween()
					if tween:
						tween.set_trans(Tween.TRANS_ELASTIC)
						tween.tween_property(crown_icon, "scale", Vector2(0.6, 0.6), 0.3)
						tween.tween_property(crown_icon, "scale", Vector2(0.5, 0.5), 0.3)
			else:
				high_score_label.text = "High: 0"

func update_money_display() -> void:
	var money_label = get_node_or_null("MoneyDisplay/MoneyLabel")
	if money_label:
		var current_money_text = money_label.text
		var current_money_value = 0
		
		if current_money_text.begins_with("Money: $"):
			current_money_value = int(current_money_text.substr(8))
		
		var new_text = "Money: $" + str(money)
		money_label.text = new_text
		
		if money > current_money_value and current_money_value > 0:
			var coin_icon = get_node_or_null("MoneyDisplay/CoinIcon")
			if coin_icon:
				var tween = create_tween()
				if tween:
					tween.set_trans(Tween.TRANS_BOUNCE)
					tween.tween_property(coin_icon, "position:y", -5, 0.2)
					tween.tween_property(coin_icon, "position:y", 0, 0.2)
				
				var shine = coin_icon.get_node_or_null("CoinShine")
				if shine:
					var shine_tween = create_tween()
					if shine_tween:
						shine_tween.tween_property(shine, "scale", Vector2(0.5, 0.5), 0.3)
						shine_tween.tween_property(shine, "scale", Vector2(0.3, 0.3), 0.3)