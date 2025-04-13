extends Node

signal shape_collided(shape, collision_point)
signal shape_launched(shape)
signal shapes_popped(count)
signal enemy_destroyed(enemy)
signal game_over_triggered
signal score_changed(new_score)

func emit_shape_collided(shape, collision_point):
    emit_signal("shape_collided", shape, collision_point)
    
func emit_shape_launched(shape):
    emit_signal("shape_launched", shape)
    
func emit_shapes_popped(count):
    emit_signal("shapes_popped", count)
    
func emit_enemy_destroyed(enemy):
    emit_signal("enemy_destroyed", enemy)
    
func emit_game_over_triggered():
    emit_signal("game_over_triggered")
    
func emit_score_changed(new_score):
    emit_signal("score_changed", new_score)  