extends Node

var Log = null

func _ready():
	Log = get_node_or_null("/root/Log")
	
	if not has_autoload("HighScoreManager"):
		var high_score_manager = load("res://scripts/high_score_manager.gd").new()
		high_score_manager.name = "HighScoreManager"
		call_deferred("add_high_score_manager", high_score_manager)
		if Log:
			Log.info("SetupAutoloads: Added HighScoreManager as a singleton")
	else:
		if Log:
			Log.info("SetupAutoloads: HighScoreManager already exists")

func add_high_score_manager(node):
	get_tree().root.add_child(node)
	if node.has_method("_ready"):
		node._ready()

func has_autoload(autoload_name: String) -> bool:
	if get_tree().root.has_node(autoload_name):
		return true
	return false 