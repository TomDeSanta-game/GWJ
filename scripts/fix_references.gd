extends SceneTree

func _init():
	var scene_path = "res://scenes/main.tscn"
	var scene = load(scene_path)
	var new_script = load("res://scripts/main.gd")
	scene.get_node("Main").set_script(new_script)
	ResourceSaver.save(scene, scene_path)
	print("References fixed!")
	quit() 