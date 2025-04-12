extends Node2D

signal shapes_popped(count)
signal game_over

@export var cols: int = 10
@export var rows: int = 12
@export var cell_size: float = 64.0
@export var game_over_row: int = 10

var grid = {}
var neighbor_directions = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)
]

func world_to_grid(pos: Vector2) -> Vector2i:
	var x = int(pos.x / cell_size)
	var y = int(pos.y / cell_size)
	
	if y % 2 != 0:
		x += 0.5
		
	return Vector2i(x, y)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var x = grid_pos.x * cell_size
	var y = grid_pos.y * cell_size
	
	if grid_pos.y % 2 != 0:
		x += cell_size / 2
		
	return Vector2(x, y)

func is_valid_position(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < cols and grid_pos.y >= 0 and grid_pos.y < rows

func add_shape_to_grid(shape, world_pos: Vector2):
	var grid_pos = world_to_grid(world_pos)
	
	if not is_valid_position(grid_pos) or grid.has(grid_pos):
		grid_pos = find_closest_empty_cell(grid_pos)
		
	if grid_pos.y >= game_over_row:
		emit_signal("game_over")
		return
		
	grid[grid_pos] = shape
	shape.global_position = grid_to_world(grid_pos)
	shape.attach_to_grid(grid_pos)
	
	check_matches(shape)
	check_orphans()

func find_closest_empty_cell(start_pos: Vector2i) -> Vector2i:
	var checked = {}
	var queue = [start_pos]
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		
		if checked.has(pos):
			continue
			
		checked[pos] = true
		
		if is_valid_position(pos) and not grid.has(pos):
			return pos
			
		for dir in neighbor_directions:
			var neighbor = pos + dir
			if not checked.has(neighbor):
				queue.append(neighbor)
				
	return Vector2i(-1, -1)

func check_matches(shape):
	var matches = find_matches(shape)
	
	if matches.size() >= 3:
		for match_shape in matches:
			var pos = match_shape.grid_position
			grid.erase(pos)
			match_shape.destroy()
		emit_signal("shapes_popped", matches.size())

func find_matches(shape) -> Array:
	var color = shape.color
	var visited = {}
	var matches = []
	var queue = [shape]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var pos = current.grid_position
		
		if visited.has(pos):
			continue
			
		visited[pos] = true
		matches.append(current)
		
		for dir in neighbor_directions:
			var neighbor_pos = pos + dir
			if grid.has(neighbor_pos):
				var neighbor = grid[neighbor_pos]
				if neighbor.color == color and not visited.has(neighbor_pos):
					queue.append(neighbor)
					
	return matches

func check_orphans():
	var all_positions = grid.keys()
	var supported = {}
	
	for pos in all_positions:
		if pos.y == 0:
			mark_as_supported(pos, supported)
			
	var orphans = []
	for pos in all_positions:
		if not supported.has(pos):
			orphans.append(grid[pos])
			grid.erase(pos)
			
	for orphan in orphans:
		orphan.destroy()
		
	if orphans.size() > 0:
		emit_signal("shapes_popped", orphans.size())

func mark_as_supported(pos: Vector2i, supported: Dictionary):
	var queue = [pos]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		if supported.has(current):
			continue
			
		supported[current] = true
		
		for dir in neighbor_directions:
			var neighbor = current + dir
			if grid.has(neighbor) and not supported.has(neighbor):
				queue.append(neighbor)

func get_neighbors(pos: Vector2i) -> Array:
	var result = []
	
	for dir in neighbor_directions:
		var neighbor = pos + dir
		if grid.has(neighbor):
			result.append(grid[neighbor])
			
	return result
