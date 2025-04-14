extends Node

const SAVE_FILE_PATH = "user://high_scores.save"
const MAX_HIGH_SCORES = 5

var high_scores = []

func _ready():
	load_high_scores()
	SignalBus.game_over_triggered.connect(_on_game_over)

func _on_game_over():
	var current_score = get_tree().current_scene.score
	check_and_update_high_scores(current_score)

func check_and_update_high_scores(score: int):
	var inserted = false
	
	for i in range(high_scores.size()):
		if score > high_scores[i]:
			high_scores.insert(i, score)
			inserted = true
			break
	
	if not inserted and high_scores.size() < MAX_HIGH_SCORES:
		high_scores.append(score)
	
	if high_scores.size() > MAX_HIGH_SCORES:
		high_scores.resize(MAX_HIGH_SCORES)
	
	save_high_scores()
	SignalBus.emit_high_scores_updated(high_scores)

func is_high_score(score: int) -> bool:
	if high_scores.size() < MAX_HIGH_SCORES:
		return true
	
	for high_score in high_scores:
		if score > high_score:
			return true
	
	return false

func load_high_scores():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.get_data()
			if data is Array:
				high_scores = data
				if high_scores.size() > MAX_HIGH_SCORES:
					high_scores.resize(MAX_HIGH_SCORES)
			else:
				high_scores = []
		else:
			high_scores = []
	else:
		high_scores = []

func save_high_scores():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	var json_string = JSON.stringify(high_scores)
	file.store_string(json_string)
	file.close()

func get_high_scores() -> Array:
	return high_scores 