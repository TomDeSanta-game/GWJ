extends Control

# Main menu script for Shape Shooter game

# Called when the play button is pressed
func _on_play_button_pressed():
	# Load the main game scene
	get_tree().change_scene_to_file("res://scenes/MainNew.tscn")

# Called when the quit button is pressed
func _on_quit_button_pressed():
	# Quit the game
	get_tree().quit()

# Optional: Add some visual effects to the menu
func _ready():
	# Set up animations for the decorative shapes
	var tween = create_tween().set_loops()
	tween.tween_property($EffectsContainer/SquareShape, "rotation", 2 * PI, 8.0)
	
	var tween2 = create_tween().set_loops()
	tween2.tween_property($EffectsContainer/CircleShape, "rotation", -2 * PI, 10.0)
	
	var tween3 = create_tween().set_loops()
	tween3.tween_property($EffectsContainer/TriangleShape, "rotation", 2 * PI, 12.0) 