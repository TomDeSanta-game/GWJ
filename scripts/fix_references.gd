extends SceneTree

func _init():
	var scene_path = "res://scenes/main.tscn"
	var script_path = "res://scripts/main.gd"
	
	var scene = load(scene_path)
	var new_script = load(script_path)
	scene.get_node("Main").set_script(new_script)
	ResourceSaver.save(scene, scene_path)
	
	quit() 