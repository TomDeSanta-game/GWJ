extends SceneTree

# This is a simple fix script to run once to remap references

func _init():
	# Remap the Main.tscn script reference
	var scene_path = "res://scenes/Main.tscn"
	var scene = load(scene_path)
	
	# Set the proper script
	var new_script = load("res://scripts/game_controller.gd")
	scene.get_node("Main").set_script(new_script)
	
	# Save the scene
	ResourceSaver.save(scene, scene_path)
	
	print("References fixed!")
	quit() 