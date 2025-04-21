extends Node

var icons = []
var animation_in_progress = false

func _ready():
	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	find_icons()

func find_icons():
	icons.clear()
	
	var high_score_display = get_parent().get_node_or_null("HighScoreDisplay")
	if high_score_display:
		var crown_icon = high_score_display.get_node_or_null("CrownIcon")
		if crown_icon:
			icons.append(crown_icon)

func animate_icons():
	for icon in icons:
		if not is_instance_valid(icon):
			continue
			
		var tween = create_tween()
		if tween:
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(icon, "scale", Vector2(0.6, 0.6), 0.2)
			tween.tween_property(icon, "scale", Vector2(0.5, 0.5), 0.2)

func _on_icon_animation_timer_timeout():
	if animation_in_progress or icons.is_empty():
		return
	
	animation_in_progress = true
	
	var icon = icons[randi() % icons.size()]
	var original_scale = icon.scale
	var original_rotation = icon.rotation
	
	var tween = create_tween()
	if tween:
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.set_ease(Tween.EASE_OUT)
		
		tween.tween_property(icon, "scale", original_scale * 1.3, 0.3)
		tween.tween_property(icon, "rotation", original_rotation + 0.2, 0.2)
		tween.tween_property(icon, "scale", original_scale, 0.3)
		tween.tween_property(icon, "rotation", original_rotation, 0.2)
		
		tween.finished.connect(func(): animation_in_progress = false) 
