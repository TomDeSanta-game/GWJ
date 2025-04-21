extends Node

const SAVE_FILE_PATH = "user://high_scores.save"
const GAME_DATA_PATH = "user://game_data.save"
const MAX_HIGH_SCORES = 5

var high_scores = []
var player_money = 0
var player_upgrades = {}

func _ready():
	if not SignalBus.game_over_triggered.is_connected(_on_game_over):
		SignalBus.game_over_triggered.connect(_on_game_over)
	
	if not SignalBus.money_changed.is_connected(_on_money_changed):
		SignalBus.money_changed.connect(_on_money_changed)
	
	delete_save_files()
	
	load_high_scores()
	load_game_data()

func delete_save_files():
	var dir = DirAccess.open("user://")
	if dir:
		if FileAccess.file_exists(SAVE_FILE_PATH):
			dir.remove(SAVE_FILE_PATH)
		
		if FileAccess.file_exists(GAME_DATA_PATH):
			dir.remove(GAME_DATA_PATH)
		
	high_scores = []
	player_money = 0
	player_upgrades = {}
	
	SignalBus.emit_high_scores_updated(high_scores)
	SignalBus.emit_money_changed(player_money)

func _on_game_over():
	var current_score = get_tree().current_scene.score
	check_and_update_high_scores(current_score)
	save_high_scores()
	save_game_data()

func _on_money_changed(amount: int):
	player_money = amount
	save_game_data()

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
	
	SignalBus.emit_high_scores_updated(high_scores)

func is_high_score(score: int) -> bool:
	if high_scores.size() < MAX_HIGH_SCORES:
		return true
	
	for high_score in high_scores:
		if score > high_score:
			return true
	
	return false

func load_high_scores():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		high_scores = JSON.parse_string(file.get_as_text())
		if high_scores == null:
			high_scores = []
		file.close()
	else:
		high_scores = []

func save_high_scores():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(high_scores))
		file.close()

func load_game_data():
	var file = FileAccess.open(GAME_DATA_PATH, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data != null:
			if "money" in data:
				player_money = data["money"]
			if "upgrades" in data:
				player_upgrades = data["upgrades"]
		file.close()
	else:
		player_money = 0
		player_upgrades = {}

func save_game_data():
	var data = {
		"money": player_money,
		"upgrades": player_upgrades
	}
	var file = FileAccess.open(GAME_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func get_player_money() -> int:
	return player_money

func set_player_money(value: int) -> void:
	player_money = value

func get_player_upgrades() -> Dictionary:
	return player_upgrades

func set_player_upgrades(upgrades: Dictionary) -> void:
	player_upgrades = upgrades

func get_high_scores() -> Array:
	return high_scores 