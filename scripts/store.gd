extends Control

@export var back_button: Button
@export var multi_shot_button: Button
@export var money_label: Label

@onready var scene_manager = get_node("/root/SceneManager")
@onready var high_score_manager = get_node("/root/HighScoreManager")

var money: int = 0
var upgrades = {"multi_shot": 1}
var upgrade_costs = {"multi_shot": 100}

func _ready() -> void:
	var game = get_node("/root/GameController")
	
	# Load from high score manager instead of game controller
	if high_score_manager:
		money = high_score_manager.get_player_money()
		upgrades = high_score_manager.get_player_upgrades()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if multi_shot_button:
		multi_shot_button.pressed.connect(_on_multi_shot_pressed)
	
	update_ui()

func update_ui() -> void:
	if money_label:
		money_label.text = "Money: $" + str(money)
	
	if multi_shot_button:
		multi_shot_button.text = "Multi-Shot: " + str(upgrades["multi_shot"]) + " -> " + str(upgrades["multi_shot"] + 1) + " ($" + str(get_next_upgrade_cost("multi_shot")) + ")"
		multi_shot_button.disabled = money < get_next_upgrade_cost("multi_shot")

func get_next_upgrade_cost(upgrade_name: String) -> int:
	var base_cost = upgrade_costs[upgrade_name]
	var current_level = upgrades[upgrade_name]
	
	# Each level costs more
	return base_cost * current_level

func _on_back_pressed() -> void:
	# Save data before going back
	high_score_manager.set_player_money(money)
	high_score_manager.set_player_upgrades(upgrades)
	
	# Emit signals to ensure the game is notified of the changes
	SignalBus.emit_money_changed(money)
	SignalBus.emit_upgrades_changed(upgrades)
	
	scene_manager.change_scene("res://scenes/Game.tscn")

func _on_multi_shot_pressed() -> void:
	var cost = get_next_upgrade_cost("multi_shot")
	
	if money >= cost:
		money -= cost
		upgrades["multi_shot"] += 1
		
		# Save after purchase
		high_score_manager.set_player_money(money)
		high_score_manager.set_player_upgrades(upgrades)
		
		update_ui()
	else:
		pass 