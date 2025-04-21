extends Node

signal shape_collided(shape, collision_point)
signal shape_launched(shape)
signal shapes_popped(count)
signal enemy_destroyed(enemy)
signal game_over_triggered
signal score_changed(score)
signal money_changed(amount)
signal high_scores_updated(high_scores)
signal new_high_score(score, position)
signal bounced
signal high_scores_loaded(high_scores)
signal player_money_changed(amount)

func emit_shape_collided(shape, collision_point):
    emit_signal("shape_collided", shape, collision_point)
    
func emit_shape_launched(shape):
    emit_signal("shape_launched", shape)
    
func emit_shapes_popped(count: int):
    emit_signal("shapes_popped", count)
    
func emit_enemy_destroyed(enemy):
    emit_signal("enemy_destroyed", enemy)
    
func emit_game_over_triggered():
    emit_signal("game_over_triggered")
    
func emit_score_changed(score: int):
    emit_signal("score_changed", score)

func emit_money_changed(amount: int):
    emit_signal("money_changed", amount)

func emit_high_scores_updated(high_scores: Array):
    emit_signal("high_scores_updated", high_scores)
    
func emit_new_high_score(score: int, position: int):
    emit_signal("new_high_score", score, position)

func emit_bounced():
    emit_signal("bounced")
    
func emit_high_scores_loaded(high_scores: Array):
    emit_signal("high_scores_loaded", high_scores)
    
func emit_player_money_changed(amount: int):
    emit_signal("player_money_changed", amount)  