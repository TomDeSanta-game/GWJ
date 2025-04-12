extends Node

@export var shape_scene: PackedScene
@export var spawn_timer: float = 1.5
@export var max_score_width: float = 300.0
@export var game_difficulty: float = 1.0

var score: int = 0
var is_game_over: bool = false
var enemy_speed: float = 80.0
var time_since_last_spawn: float = 0.0

func _ready() -> void:
	randomize()
	setup_input_map()
	
	SignalBus.shapes_popped.connect(_on_shapes_popped)
	SignalBus.grid_game_over.connect(_on_game_over)
	
	for i in range(5):
		spawn_enemy()
	
	SignalBus.score_changed.connect(update_score_display)

func _process(delta: float) -> void:
	if is_game_over:
		return
		
	time_since_last_spawn += delta
	if time_since_last_spawn >= spawn_timer:
		spawn_enemy()
		time_since_last_spawn = 0.0
		
	game_difficulty += delta * 0.01
	enemy_speed = 80.0 + (game_difficulty * 20.0)

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
	
	shape.add_to_group("Enemies")
	
	shape.is_enemy = true
	shape.target_position = Vector2(320, 720)
	shape.move_speed = enemy_speed
	
	add_child(shape)

func _on_shapes_popped(count: int) -> void:
	var points := count * count * 10
	score += points
	SignalBus.score_changed.emit(score)

func update_score_display(new_score: int) -> void:
	var score_display := get_node_or_null("ScoreDisplay")
	if not score_display:
		return
		
	var score_fill := score_display.get_node("ScoreFill") as ColorRect
	if not score_fill:
		return
		
	var percentage: float = min(1.0, float(new_score) / 1000.0)
	var new_width: float = max_score_width * percentage
	
	score_fill.size.x = new_width
	score_fill.position.x = -max_score_width/2

func _on_game_over() -> void:
	if is_game_over:
		return
		
	is_game_over = true
	SignalBus.grid_game_over.emit()
	
	get_tree().paused = true
	
	var game_over_display := Node2D.new()
	game_over_display.position = Vector2(320, 390)
	
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.0, 0.0, 0.8)
	bg.size = Vector2(400, 300)
	bg.position = Vector2(-200, -150)
	game_over_display.add_child(bg)
	
	var skull := Node2D.new()
	skull.position = Vector2(0, -50)
	game_over_display.add_child(skull)
	
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
	
	var restart_hint := Node2D.new()
	restart_hint.position = Vector2(0, 80)
	game_over_display.add_child(restart_hint)
	
	var r_key := ColorRect.new()
	r_key.color = Color(0.8, 0.8, 0.8, 1)
	r_key.size = Vector2(40, 40)
	r_key.position = Vector2(-20, -20)
	restart_hint.add_child(r_key)
	
	var r_line1 := ColorRect.new()
	r_line1.color = Color(0, 0, 0, 1)
	r_line1.size = Vector2(5, 30)
	r_line1.position = Vector2(-10, -15)
	restart_hint.add_child(r_line1)
	
	var r_line2 := ColorRect.new()
	r_line2.color = Color(0, 0, 0, 1)
	r_line2.size = Vector2(15, 5)
	r_line2.position = Vector2(-10, -15)
	restart_hint.add_child(r_line2)
	
	var r_line3 := ColorRect.new()
	r_line3.color = Color(0, 0, 0, 1)
	r_line3.size = Vector2(15, 5)
	r_line3.position = Vector2(-10, 0)
	restart_hint.add_child(r_line3)
	
	var r_line4 := ColorRect.new()
	r_line4.color = Color(0, 0, 0, 1)
	r_line4.size = Vector2(5, 5)
	r_line4.position = Vector2(0, 0)
	restart_hint.add_child(r_line4)
	
	var r_line5 := ColorRect.new()
	r_line5.color = Color(0, 0, 0, 1)
	r_line5.size = Vector2(5, 10)
	r_line5.position = Vector2(5, 5)
	restart_hint.add_child(r_line5)
	
	add_child(game_over_display)

func _input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.keycode == KEY_R and event.pressed:
		get_tree().reload_current_scene()
		get_tree().paused = false
		
func check_enemies_reached_bottom() -> void:
	var enemies := get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.position.y > 700:
			_on_game_over()
			return
