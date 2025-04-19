extends Control

var score_index = -1
var high_scores = []
var is_new_high_score = false
var score_position = 0

func _ready():
	connect_signals()
	get_high_scores()
	update_high_score_list()

func connect_signals():
	SignalBus.high_scores_updated.connect(_on_high_scores_updated)
	SignalBus.new_high_score.connect(_on_new_high_score)
	
	var play_again_button = get_node_or_null("PlayAgainButton")
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)

func get_high_scores():
	var high_score_mgr = get_node("/root/HighScoreManager")
	if high_score_mgr:
		high_scores = high_score_mgr.get_high_scores()

func _on_high_scores_updated(updated_high_scores):
	high_scores = updated_high_scores
	update_high_score_list()

func _on_new_high_score(score, pos):
	is_new_high_score = true
	score_position = pos
	
	var position_label = get_node_or_null("YourScorePosition")
	if position_label:
		position_label.text = "YOUR SCORE IS #" + str(pos)
		position_label.visible = true
	
	var current_score_label = get_node_or_null("CurrentScore")
	if current_score_label:
		current_score_label.text = str(score)
		
		var tween = create_tween()
		tween.tween_property(current_score_label, "modulate", Color(1, 0.9, 0.3, 1), 0.5)
		tween.tween_property(current_score_label, "modulate", Color(1, 1, 1, 1), 0.5)
		tween.set_loops()

func update_high_score_list():
	var high_score_list = get_node_or_null("HighScoreList")
	if not high_score_list:
		return
		
	high_score_list.clear()
	
	for i in range(min(high_scores.size(), 5)):
		high_score_list.add_item("#" + str(i+1) + ": " + str(high_scores[i]))

func _on_play_again_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn") 