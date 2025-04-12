extends Node  # Define this as a singleton Node that will manage global signals

# Shape-related signals - These signals handle events related to shapes in the game
@warning_ignore("unused_signal")  # Ignore warning about signal that might appear unused
signal shape_collided(shape, collision_point)  # Emitted when a shape collides with something, passes the shape and collision point

@warning_ignore("unused_signal")
signal shape_launched(shape)  # Emitted when a shape is launched from the launcher

@warning_ignore("unused_signal")
signal shapes_popped(count)  # Emitted when shapes are destroyed/popped, passes count of popped shapes

@warning_ignore("unused_signal")
signal enemy_destroyed(enemy)  # Emitted when an enemy shape is destroyed

# Game state signals - These signals handle game state changes
@warning_ignore("unused_signal")
signal grid_game_over  # Emitted when game over is caused by grid conditions (enemy reaches bottom, etc.)

@warning_ignore("unused_signal")
signal game_over_triggered  # Emitted when game is over by any condition

# UI signals - These signals are for updating the user interface
@warning_ignore("unused_signal")
signal score_changed(new_score)  # Emitted when the player's score changes, passes the new score value 