extends Control

func _ready():
	Log.info("Main menu ready")
	$MenuContainer/ButtonsContainer/PlayButton.mouse_entered.connect(func(): _on_button_hover($MenuContainer/ButtonsContainer/PlayButton))
	$MenuContainer/ButtonsContainer/PlayButton.mouse_exited.connect(func(): _on_button_exit($MenuContainer/ButtonsContainer/PlayButton))
	$MenuContainer/ButtonsContainer/LevelSelectButton.mouse_entered.connect(func(): _on_button_hover($MenuContainer/ButtonsContainer/LevelSelectButton))
	$MenuContainer/ButtonsContainer/LevelSelectButton.mouse_exited.connect(func(): _on_button_exit($MenuContainer/ButtonsContainer/LevelSelectButton))
	$MenuContainer/ButtonsContainer/QuitButton.mouse_entered.connect(func(): _on_button_hover($MenuContainer/ButtonsContainer/QuitButton))
	$MenuContainer/ButtonsContainer/QuitButton.mouse_exited.connect(func(): _on_button_exit($MenuContainer/ButtonsContainer/QuitButton))
	
	Log.debug("Checking MenuContainer exists: " + str(has_node("MenuContainer")))
	Log.debug("Checking LevelSelectButton exists: " + str(has_node("MenuContainer/ButtonsContainer/LevelSelectButton")))
	
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_L:
			Log.info("L key pressed - quick access to level select")
			get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_button_hover(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
	
func _on_button_exit(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

func _on_play_button_pressed():
	Log.info("Play button pressed")
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	
	Log.debug("Changing to MainNew.tscn")
	get_tree().change_scene_to_file("res://scenes/MainNew.tscn")
	
func _on_level_select_button_pressed():
	Log.info("Level select button pressed")
	
	var dir = DirAccess.open("res://scenes")
	if dir:
		Log.debug("Directory accessed, checking for LevelSelect.tscn")
		Log.debug("Files in scenes directory: " + str(dir.get_files()))
	else:
		Log.error("Failed to access scenes directory")
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	await tween.finished
	
	Log.debug("Changing to LevelSelect.tscn")
	
	if FileAccess.file_exists("res://scenes/LevelSelect.tscn"):
		Log.debug("LevelSelect.tscn file exists")
	else:
		Log.error("LevelSelect.tscn file does not exist!")
		
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
	
func _on_quit_button_pressed():
	Log.info("Quit button pressed")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	await tween.finished
	
	get_tree().quit() 