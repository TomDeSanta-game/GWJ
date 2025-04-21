extends Control

# Script for the level selection menu

# Store level information for easy access - can be used in the future
var levels = [
	{
		"name": "Default",
		"description": "A basic level with clean visuals",
		"scene_path": "res://scenes/MainNew.tscn",
		"difficulty": 1,
		"unlocked": true
	},
	{
		"name": "Truck Interior",
		"description": "Play from inside a moving truck",
		"scene_path": "res://scenes/TruckLevel.tscn",
		"difficulty": 2,
		"unlocked": true
	},
	{
		"name": "Moon Surface",
		"description": "Play on the surface of the moon",
		"scene_path": "res://scenes/MoonLevel.tscn",
		"difficulty": 3,
		"unlocked": true
	}
]

var current_level_index = 0
var main_menu_scene = preload("res://scenes/MainMenu.tscn")
var truck_level_scene = preload("res://scenes/TruckLevel.tscn")
var moon_level_scene = preload("res://scenes/MoonLevel.tscn")
var simple_menu_scene = preload("res://scenes/SimpleMenu.tscn")

func _ready():
	randomize()
	
	if not get_node_or_null("CenterContainer/Panel/VBoxContainer/Buttons/BackButton"):
		Log.error("BackButton not found in expected path")
		return
	
	if not get_node_or_null("CenterContainer/Panel/VBoxContainer/Buttons/PlayButton"):
		Log.error("PlayButton not found in expected path")
		return
	
	print_node_tree()
	
	setup_button_connections()
	
	if not $CenterContainer/Panel/VBoxContainer/Buttons/BackButton.pressed.is_connected(_on_back_button_pressed):
		Log.error("BackButton signal not connected")
	
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

func print_node_tree(node = self, indent = 0):
	if node == null:
		return
	var indentation = ""
	for i in range(indent):
		indentation += "  "
	Log.debug(indentation + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		print_node_tree(child, indent + 1)

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_M:
			get_tree().change_scene_to_packed(main_menu_scene)
		elif event.pressed and event.keycode == KEY_S:
			get_tree().change_scene_to_packed(simple_menu_scene)
		elif event.pressed and event.keycode == KEY_LEFT:
			change_level(-1)
		elif event.pressed and event.keycode == KEY_RIGHT:
			change_level(1)
		elif event.pressed and event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_play_button_pressed()

func setup_button_connections():
	$CenterContainer/Panel/VBoxContainer/Buttons/BackButton.pressed.connect(_on_back_button_pressed)
	$CenterContainer/Panel/VBoxContainer/Buttons/PlayButton.pressed.connect(_on_play_button_pressed)
	$CenterContainer/Panel/VBoxContainer/LevelNavigation/PrevButton.pressed.connect(func(): change_level(-1))
	$CenterContainer/Panel/VBoxContainer/LevelNavigation/NextButton.pressed.connect(func(): change_level(1))
	
	$CenterContainer/Panel/VBoxContainer/Buttons/BackButton.mouse_entered.connect(
		func(): _on_button_hover($CenterContainer/Panel/VBoxContainer/Buttons/BackButton))
	$CenterContainer/Panel/VBoxContainer/Buttons/BackButton.mouse_exited.connect(
		func(): _on_button_exit($CenterContainer/Panel/VBoxContainer/Buttons/BackButton))
	$CenterContainer/Panel/VBoxContainer/Buttons/PlayButton.mouse_entered.connect(
		func(): _on_button_hover($CenterContainer/Panel/VBoxContainer/Buttons/PlayButton))
	$CenterContainer/Panel/VBoxContainer/Buttons/PlayButton.mouse_exited.connect(
		func(): _on_button_exit($CenterContainer/Panel/VBoxContainer/Buttons/PlayButton))

func _on_button_hover(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
	
func _on_button_exit(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

func _on_back_button_pressed():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	
	get_tree().change_scene_to_packed(main_menu_scene)

func _on_play_button_pressed():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	
	match current_level_index:
		0: get_tree().change_scene_to_file("res://scenes/MainNew.tscn")
		1: get_tree().change_scene_to_file("res://scenes/TruckLevel.tscn")
		2: get_tree().change_scene_to_file("res://scenes/MoonLevel.tscn")
		_: get_tree().change_scene_to_file("res://scenes/MainNew.tscn")

func change_level(direction):
	current_level_index = (current_level_index + direction) % levels.size()
	if current_level_index < 0:
		current_level_index = levels.size() - 1
	
	update_level_display()

func update_level_display():
	var level = levels[current_level_index]
	$CenterContainer/Panel/VBoxContainer/LevelInfo/LevelName.text = level.name
	$CenterContainer/Panel/VBoxContainer/LevelInfo/LevelDescription.text = level.description
	
	var difficulty_stars = ""
	for i in range(level.difficulty):
		difficulty_stars += "★"
	for i in range(3 - level.difficulty):
		difficulty_stars += "☆"
	$CenterContainer/Panel/VBoxContainer/LevelInfo/DifficultyStars.text = difficulty_stars

func animate_exit():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN) 