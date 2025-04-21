extends Control

var main_game_scene = preload("res://scenes/MainNew.tscn")
var level_select_scene = preload("res://scenes/LevelSelect.tscn")

func _ready():
	setup_button_connections()
	
	animate_menu_entrance()

func setup_button_connections():
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/PlayButton.mouse_entered.connect(
		func(): _on_button_hover($CenterContainer/Panel/MenuContainer/ButtonsContainer/PlayButton))
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/PlayButton.mouse_exited.connect(
		func(): _on_button_exit($CenterContainer/Panel/MenuContainer/ButtonsContainer/PlayButton))
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/LevelSelectButton.mouse_entered.connect(
		func(): _on_button_hover($CenterContainer/Panel/MenuContainer/ButtonsContainer/LevelSelectButton))
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/LevelSelectButton.mouse_exited.connect(
		func(): _on_button_exit($CenterContainer/Panel/MenuContainer/ButtonsContainer/LevelSelectButton))
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/QuitButton.mouse_entered.connect(
		func(): _on_button_hover($CenterContainer/Panel/MenuContainer/ButtonsContainer/QuitButton))
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/QuitButton.mouse_exited.connect(
		func(): _on_button_exit($CenterContainer/Panel/MenuContainer/ButtonsContainer/QuitButton))
	
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/PlayButton.pressed.connect(_on_play_button_pressed)
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/LevelSelectButton.pressed.connect(_on_level_select_button_pressed)
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func animate_menu_entrance():
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	
	$CenterContainer/Panel.scale = Vector2(0.9, 0.9)
	var panel_tween = create_tween()
	panel_tween.tween_property($CenterContainer/Panel, "scale", Vector2(1, 1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	var title_tween = create_tween()
	title_tween.set_loops()
	title_tween.tween_property($CenterContainer/Panel/MenuContainer/Title, "modulate", Color(0.9, 0.9, 1.0, 0.9), 1.5).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property($CenterContainer/Panel/MenuContainer/Title, "modulate", Color(1, 1, 1, 1), 1.5).set_ease(Tween.EASE_IN_OUT)

func _on_button_hover(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

func _on_button_exit(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

func _on_play_button_pressed():
	animate_panel_exit(true)
	
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_packed(main_game_scene)

func _on_level_select_button_pressed():
	animate_panel_exit(true)
	
	await get_tree().create_timer(0.5).timeout
	
	if level_select_scene:
		var result = get_tree().change_scene_to_packed(level_select_scene)
		if result != OK:
			push_error("Failed to change to level select scene, error: " + str(result))
			get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
	else:
		push_error("Failed to preload level select scene")
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_quit_button_pressed():
	animate_panel_exit(false)
	
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func animate_panel_exit(is_growing: bool):
	var tween = create_tween()
	
	if is_growing:
		tween.tween_property($CenterContainer/Panel, "scale", Vector2(1.1, 1.1), 0.2).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property($CenterContainer/Panel, "scale", Vector2(0.9, 0.9), 0.2).set_ease(Tween.EASE_IN)
	
	tween.parallel().tween_property($CenterContainer/Panel, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)