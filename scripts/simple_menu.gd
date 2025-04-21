extends Control

# This script handles the main menu functionality including animations and scene transitions

# Preload scenes to avoid file loading issues
var main_game_scene = preload("res://scenes/MainNew.tscn")
var level_select_scene = preload("res://scenes/LevelSelect.tscn")

func _ready():
	# Set up button connections
	setup_button_connections()
	
	# Create entrance animations
	animate_menu_entrance()

# Connect all button signals
func setup_button_connections():
	# Hover effects
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
	
	# Button clicks
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/PlayButton.pressed.connect(_on_play_button_pressed)
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/LevelSelectButton.pressed.connect(_on_level_select_button_pressed)
	$CenterContainer/Panel/MenuContainer/ButtonsContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

# Create all entrance animations for the menu
func animate_menu_entrance():
	# Fade in the entire menu
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	
	# Scale up the panel with a bounce effect
	$CenterContainer/Panel.scale = Vector2(0.9, 0.9)
	var panel_tween = create_tween()
	panel_tween.tween_property($CenterContainer/Panel, "scale", Vector2(1, 1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Gentle pulsing effect on the title
	var title_tween = create_tween()
	title_tween.set_loops() # Makes the animation loop forever
	title_tween.tween_property($CenterContainer/Panel/MenuContainer/Title, "modulate", Color(0.9, 0.9, 1.0, 0.9), 1.5).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property($CenterContainer/Panel/MenuContainer/Title, "modulate", Color(1, 1, 1, 1), 1.5).set_ease(Tween.EASE_IN_OUT)

# Handle button hover animation
func _on_button_hover(button):
	# Scale up the button slightly for hover effect
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

# Reset button after hover ends
func _on_button_exit(button):
	# Scale back to normal size
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1).set_ease(Tween.EASE_IN)

# When the Play button is pressed
func _on_play_button_pressed():
	animate_panel_exit(true)
	
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_packed(main_game_scene)

# When the LevelSelect button is pressed
func _on_level_select_button_pressed():
	animate_panel_exit(true)
	
	await get_tree().create_timer(0.5).timeout
	
	# Add error handling for scene loading
	if level_select_scene:
		var result = get_tree().change_scene_to_packed(level_select_scene)
		if result != OK:
			push_error("Failed to change to level select scene, error: " + str(result))
			# Fallback to direct scene loading
			get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
	else:
		push_error("Failed to preload level select scene")
		# Fallback to direct scene loading
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

# When the Quit button is pressed
func _on_quit_button_pressed():
	animate_panel_exit(false)
	
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

# Handle the panel exit animation
func animate_panel_exit(is_growing: bool):
	var tween = create_tween()
	
	# Different animations based on if we're playing (grow) or quitting (shrink)
	if is_growing:
		tween.tween_property($CenterContainer/Panel, "scale", Vector2(1.1, 1.1), 0.2).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property($CenterContainer/Panel, "scale", Vector2(0.9, 0.9), 0.2).set_ease(Tween.EASE_IN)
	
	# Fade out the panel and menu
	tween.parallel().tween_property($CenterContainer/Panel, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN) 