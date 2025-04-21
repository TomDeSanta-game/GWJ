extends Node

const SAVE_FILE_PATH = "user://high_scores.save"

var high_scores: Array = []
var max_high_scores: int = 10
var initialized: bool = false
var is_high_score_panel_shown: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "HighScoreManager"
	
	ensure_user_directory_exists()
	
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var result = load_high_scores()
		if result.is_empty():
			generate_default_high_scores()
			save_high_scores()
	else:
		generate_default_high_scores()
		save_high_scores()
	
	initialized = true
	SignalBus.emit_high_scores_updated(high_scores)
	SignalBus.emit_high_scores_loaded(high_scores)

func ensure_user_directory_exists():
	var dir = DirAccess.open("user://")
	if not dir:
		DirAccess.make_dir_absolute("user://")

func generate_default_high_scores():
	high_scores = []
	for i in range(10):
		high_scores.append(1000 - i * 100)

func save_high_scores():
	ensure_user_directory_exists()
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var save_data = {
			"high_scores": high_scores
		}
		file.store_var(save_data)
		file.close()
		return true
	
	return false

func load_high_scores():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return []
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return []
		
	var data = file.get_var()
	file.close()
	
	if data == null or typeof(data) != TYPE_DICTIONARY or not data.has("high_scores"):
		if FileAccess.file_exists(SAVE_FILE_PATH):
			var dir = DirAccess.open("user://")
			if dir:
				dir.remove(SAVE_FILE_PATH.replace("user://", ""))
		return []
	
	high_scores = data["high_scores"]
	
	if typeof(high_scores) != TYPE_ARRAY:
		high_scores = []
		return []
	
	high_scores.sort()
	high_scores.reverse()
	
	if high_scores.size() > max_high_scores:
		high_scores.resize(max_high_scores)
	
	return high_scores

func add_high_score(score: int):
	if score <= 0:
		return -1
		
	var dir = DirAccess.open("user://")
	if not dir:
		DirAccess.make_dir_absolute("user://")
	
	high_scores.append(score)
	high_scores.sort()
	high_scores.reverse()
	
	if high_scores.size() > max_high_scores:
		high_scores.resize(max_high_scores)
	
	save_high_scores()
	
	var position = high_scores.find(score)
	if position >= 0:
		SignalBus.emit_new_high_score(score, position + 1)
		
	SignalBus.emit_high_scores_updated(high_scores)
	SignalBus.emit_high_scores_loaded(high_scores)
	
	return position

func is_high_score(score: int):
	if high_scores.size() < max_high_scores:
		return true
		
	return score > high_scores[high_scores.size() - 1]

func reset_save_files():
	ensure_user_directory_exists()
	
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_FILE_PATH.replace("user://", ""))
	
	generate_default_high_scores()
	
	save_high_scores()
	
	SignalBus.emit_high_scores_updated(high_scores)
	SignalBus.emit_high_scores_loaded(high_scores)
	
	return true 