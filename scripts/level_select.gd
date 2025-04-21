extends Control

# Script for the level selection menu

# Store level information for easy access - can be used in the future
var levels = [
	{
		"name": "Default Level",
		"scene_path": "res://scenes/MainNew.tscn",
		"description": "The classic shapes cannon experience.",
		"gravity": 1.0,
		"thumbnail_color": Color(0.4, 0.6, 0.8)
	},
	{
		"name": "Truck Interior",
		"scene_path": "res://scenes/TruckLevel.tscn", 
		"description": "Challenge yourself by playing inside a moving truck!\nDeal with bumps and vibrations.",
		"gravity": 1.0,
		"thumbnail_color": Color(0.5, 0.5, 0.55)
	},
	{
		"name": "Moon Surface",
		"scene_path": "res://scenes/MoonLevel.tscn",
		"description": "Low gravity shapes adventure on the lunar surface.\nWatch your shots go further!",
		"gravity": 0.16,
		"thumbnail_color": Color(0.8, 0.8, 0.85)
	}
]

# Preload scene resources
var truck_level_scene = preload("res://scenes/TruckLevel.tscn")
var moon_level_scene = preload("res://scenes/MoonLevel.tscn")
var simple_menu_scene = preload("res://scenes/SimpleMenu.tscn")

func _ready():
	Log.info("Level select screen ready")
	
	# Check if nodes exist
	Log.debug("Background exists: " + str(has_node("Background")))
	Log.debug("VBoxContainer exists: " + str(has_node("VBoxContainer")))
	Log.debug("TruckButton exists: " + str(has_node("VBoxContainer/TruckButton")))
	Log.debug("MoonButton exists: " + str(has_node("VBoxContainer/MoonButton")))
	Log.debug("BackButton exists: " + str(has_node("BackButton")))
	
	# Print full node tree for debugging
	Log.debug("Node tree structure:")
	_print_node_tree(self, 0)
	
	# Check if signals are connected
	Log.debug("TruckButton has connections: " + str(get_node("VBoxContainer/TruckButton").get_signal_connection_list("pressed").size() > 0))
	Log.debug("MoonButton has connections: " + str(get_node("VBoxContainer/MoonButton").get_signal_connection_list("pressed").size() > 0))
	Log.debug("BackButton has connections: " + str(get_node("BackButton").get_signal_connection_list("pressed").size() > 0))
	
	# Animate entrance - simple fade in
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)

# Helper function to print node tree
func _print_node_tree(node, level):
	var indent = ""
	for i in range(level):
		indent += "  "
	Log.debug(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_node_tree(child, level + 1)

# Input function for keyboard shortcuts
func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Log.info("ESC key pressed - returning to main menu")
			_on_back_button_pressed()
		elif event.pressed and event.keycode == KEY_1:
			Log.info("1 key pressed - quick access to Truck level")
			_on_truck_button_pressed()
		elif event.pressed and event.keycode == KEY_2:
			Log.info("2 key pressed - quick access to Moon level")
			_on_moon_button_pressed()
		elif event.pressed and event.keycode == KEY_M:
			Log.info("M key pressed - returning to main menu")
			_on_back_button_pressed()

# Button event handlers - these are connected in the scene

func _on_truck_button_pressed():
	Log.info("Truck button pressed")
	animate_exit()
	await get_tree().create_timer(0.3).timeout
	
	if truck_level_scene:
		var result = get_tree().change_scene_to_packed(truck_level_scene)
		if result != OK:
			Log.error("Failed to load truck level scene. Error: " + str(result))
			get_tree().change_scene_to_file("res://scenes/TruckLevel.tscn")
	else:
		Log.error("Failed to preload truck level scene")
		get_tree().change_scene_to_file("res://scenes/TruckLevel.tscn")

func _on_moon_button_pressed():
	Log.info("Moon button pressed")
	animate_exit()
	await get_tree().create_timer(0.3).timeout
	
	if moon_level_scene:
		var result = get_tree().change_scene_to_packed(moon_level_scene)
		if result != OK:
			Log.error("Failed to load moon level scene. Error: " + str(result))
			get_tree().change_scene_to_file("res://scenes/MoonLevel.tscn")
	else:
		Log.error("Failed to preload moon level scene")
		get_tree().change_scene_to_file("res://scenes/MoonLevel.tscn")

func _on_back_button_pressed():
	Log.info("Back button pressed")
	animate_exit()
	await get_tree().create_timer(0.3).timeout
	
	if simple_menu_scene:
		var result = get_tree().change_scene_to_packed(simple_menu_scene)
		if result != OK:
			Log.error("Failed to load simple menu scene. Error: " + str(result))
			get_tree().change_scene_to_file("res://scenes/SimpleMenu.tscn")
	else:
		Log.error("Failed to preload simple menu scene")
		get_tree().change_scene_to_file("res://scenes/SimpleMenu.tscn")

# Simple exit animation
func animate_exit():
	# Fade out the entire menu
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN) 