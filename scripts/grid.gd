extends Node2D  # 2D Node that can have a position in the game world

# Signals emitted by this node
signal shapes_popped(count)  # Signal emitted when shapes are removed from grid, with count of shapes
signal game_over  # Signal emitted when game over condition is met

# Grid configuration properties that can be set in the editor
@export var grid_width: int = 6  # Number of columns in the grid
@export var grid_height: int = 7  # Number of rows in the grid
@export var cell_size: int = 100  # Size of each cell in pixels
@export var game_over_row: int = 10  # Row at which game over is triggered if shapes reach it

# Color matching
@export var min_match_count: int = 3
@export var match_check_delay: float = 0.1

# Grid data
var grid = {}  # Dictionary mapping grid positions to shape objects
var neighbor_directions = [  # Array of neighbor directions in grid
	Vector2i(1, 0),   # Right
	Vector2i(0, 1),   # Down
	Vector2i(-1, 1),  # Down-Left
	Vector2i(-1, 0),  # Left
	Vector2i(0, -1),  # Up
	Vector2i(1, -1),  # Up-Right
	Vector2i(-1, -1), # Up-Left
	Vector2i(1, 1)    # Down-Right
]

# Visual effects
var grid_layer_offset = Vector2(0, 0)
var cell_highlights = []
var cell_pulse_nodes = []
var match_checking_active = false
var grid_lines_color = Color(0.9, 0.7, 0.5, 0.3)
var time_since_last_pulse = 0.0
var pulse_interval = 2.0  # Seconds between grid pulses

func _ready():
	SignalBus.shape_collided.connect(_on_shape_collided)
	create_grid_highlights()
	enhance_grid_lines()
	add_grid_particles()

func _process(delta):
	# Visual effects
	update_grid_visuals(delta)
	
	# Add periodic pulse effect to grid
	time_since_last_pulse += delta
	if time_since_last_pulse >= pulse_interval:
		create_grid_pulse()
		time_since_last_pulse = 0.0

func create_grid_pulse():
	# Create a pulse effect that travels across the grid
	var pulse = ColorRect.new()
	pulse.color = Color(0.7, 0.9, 1.0, 0.0)
	pulse.size = Vector2(cell_size - 10, cell_size - 10)
	pulse.position = Vector2(-cell_size, -cell_size) # Start off-grid
	pulse.z_index = 2
	add_child(pulse)
	
	# Random starting position at top of grid
	var start_x = randi() % grid_width
	var start_pos = Vector2(start_x * cell_size + 5, -cell_size)
	
	# Random ending position at bottom of grid
	var end_x = randi() % grid_width
	var end_pos = Vector2(end_x * cell_size + 5, grid_height * cell_size + cell_size)
	
	# Create the pulse animation
	var tween = create_tween()
	tween.tween_property(pulse, "position", start_pos, 0.1)
	tween.tween_property(pulse, "color", Color(0.7, 0.9, 1.0, 0.5), 0.2)
	tween.tween_property(pulse, "position", end_pos, 1.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(pulse, "color", Color(0.7, 0.9, 1.0, 0.0), 1.5)
	tween.tween_callback(pulse.queue_free)

func enhance_grid_lines():
	# Get references to the grid lines
	var horizontal_lines = get_node("GridLines/HorizontalLines")
	var vertical_lines = get_node("GridLines/VerticalLines")
	
	if horizontal_lines and vertical_lines:
		# Enhance horizontal lines
		for line in horizontal_lines.get_children():
			if line is Line2D:
				line.default_color = grid_lines_color
				line.width = 2.0
		
		# Enhance vertical lines
		for line in vertical_lines.get_children():
			if line is Line2D:
				line.default_color = grid_lines_color
				line.width = 2.0
	
	# Add rounded glowing dots at line intersections
	for x in range(grid_width + 1):
		for y in range(grid_height + 1):
			var glow = Sprite2D.new()
			
			# Create a round dot image
			var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			
			var center = Vector2(6, 6)
			var radius = 4
			for px in range(12):
				for py in range(12):
					var dist = Vector2(px, py).distance_to(center)
					if dist <= radius:
						var alpha = 1.0 - (dist / radius) * 0.7
						img.set_pixel(px, py, Color(1.0, 0.9, 0.7, alpha * 0.3))
			
			glow.texture = ImageTexture.create_from_image(img)
			glow.position = Vector2(x * cell_size, y * cell_size)
			glow.z_index = 0
			add_child(glow)
			cell_pulse_nodes.append(glow)

func add_grid_particles():
	# Create subtle particle system for the grid
	var particles = CPUParticles2D.new()
	particles.position = Vector2(grid_width * cell_size / 2, grid_height * cell_size / 2)
	particles.amount = 40
	particles.lifetime = 5.0
	particles.preprocess = 5.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(grid_width * cell_size / 2, grid_height * cell_size / 2)
	particles.gravity = Vector2(0, -10)
	particles.initial_velocity_min = 5
	particles.initial_velocity_max = 15
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(1.0, 0.9, 0.7, 0.15)
	add_child(particles)

func create_grid_highlights():
	# Create highlight effects for each cell
	for x in range(grid_width):
		for y in range(grid_height):
			var highlight = Sprite2D.new()
			
			# Create rounded rectangle
			var img = Image.create(cell_size - 4, cell_size - 4, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			
			var corner_radius = 10
			var width = cell_size - 4
			var height = cell_size - 4
			
			for px in range(width):
				for py in range(height):
					var in_corner = false
					var corner_dist = 0.0
					
					# Check if in corner regions
					if px < corner_radius && py < corner_radius:
						# Top-left
						corner_dist = Vector2(px, py).distance_to(Vector2(corner_radius, corner_radius))
						in_corner = true
					elif px >= width - corner_radius && py < corner_radius:
						# Top-right
						corner_dist = Vector2(px, py).distance_to(Vector2(width - corner_radius, corner_radius))
						in_corner = true
					elif px < corner_radius && py >= height - corner_radius:
						# Bottom-left
						corner_dist = Vector2(px, py).distance_to(Vector2(corner_radius, height - corner_radius))
						in_corner = true
					elif px >= width - corner_radius && py >= height - corner_radius:
						# Bottom-right
						corner_dist = Vector2(px, py).distance_to(Vector2(width - corner_radius, height - corner_radius))
						in_corner = true
					
					if in_corner:
						if corner_dist <= corner_radius:
							# Soft gradient at edges
							var alpha = 1.0 - (corner_dist / corner_radius) * 0.7
							img.set_pixel(px, py, Color(1.0, 0.9, 0.8, alpha * 0.15))
					else:
						# Main body of the rectangle
						img.set_pixel(px, py, Color(1.0, 0.9, 0.8, 0.15))
			
			highlight.texture = ImageTexture.create_from_image(img)
			highlight.position = Vector2(x * cell_size + cell_size/2, y * cell_size + cell_size/2)
			highlight.z_index = -1
			add_child(highlight)
			cell_highlights.append(highlight)

func update_grid_visuals(delta):
	# Reduced grid movement with more subtle wave effect
	grid_layer_offset.y = sin(Time.get_ticks_msec() * 0.0003) * 1.0
	grid_layer_offset.x = cos(Time.get_ticks_msec() * 0.0005) * 0.5
	position = grid_layer_offset
	
	# Update cell highlights with enhanced wave effect
	var time = Time.get_ticks_msec() * 0.001
	for i in range(cell_highlights.size()):
		var x = i % grid_width
		var y = i / grid_width
		var phase = (x + y) * 0.5 + time
		var alpha = (sin(phase) + 1) * 0.1
		cell_highlights[i].modulate.a = alpha
	
	# Animate intersection points
	for i in range(cell_pulse_nodes.size()):
		var pulse_time = time + i * 0.1
		var size_factor = 1.0 + 0.2 * sin(pulse_time * 2.0)
		var alpha = 0.2 + 0.1 * sin(pulse_time)
		cell_pulse_nodes[i].scale = Vector2(size_factor, size_factor)
		cell_pulse_nodes[i].modulate.a = alpha

func _on_shape_collided(shape, collision_point):
	# If already checking for matches, ignore new collisions
	if match_checking_active:
		return
	
	# Calculate grid coordinates from collision point
	var grid_x = int(collision_point.x / cell_size)
	var grid_y = int(collision_point.y / cell_size)
	
	# Validate grid position
	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return
	
	# Check if cell is already occupied
	var grid_pos = Vector2i(grid_x, grid_y)
	if grid.has(grid_pos):
		find_adjacent_empty_cell(shape, grid_pos)
	else:
		# Place shape in grid at collision point
		place_shape_in_grid(shape, grid_pos)
		highlight_cell(grid_pos)

func find_adjacent_empty_cell(shape, grid_pos):
	# Check adjacent cells in a spiral pattern
	var check_order = [
		Vector2i(0, -1),  # up
		Vector2i(1, 0),   # right
		Vector2i(0, 1),   # down
		Vector2i(-1, 0),  # left
		Vector2i(1, -1),  # up-right
		Vector2i(1, 1),   # down-right
		Vector2i(-1, 1),  # down-left
		Vector2i(-1, -1)  # up-left
	]
	
	for offset in check_order:
		var new_pos = grid_pos + offset
		
		# Check if in bounds
		if new_pos.x >= 0 and new_pos.x < grid_width and new_pos.y >= 0 and new_pos.y < grid_height:
			# Check if cell is empty
			if not grid.has(new_pos):
				place_shape_in_grid(shape, new_pos)
				highlight_cell(new_pos)
				return
	
	# If no empty cells found, destroy the shape
	shape.queue_free()

func place_shape_in_grid(shape, grid_pos):
	# Set shape's position to center of grid cell
	var target_position = Vector2(grid_pos.x * cell_size + cell_size/2, grid_pos.y * cell_size + cell_size/2)
	
	# Create a tween for smooth movement
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(shape, "global_position", target_position, 0.3)
	
	# Add shape to grid
	grid[grid_pos] = shape
	
	# Attach shape to grid
	shape.attach_to_grid(grid_pos)
	
	# Add ripple effect when shape is placed
	create_ripple_effect(target_position)
	
	# Slight delay before checking for matches
	var check_timer = Timer.new()
	add_child(check_timer)
	check_timer.wait_time = match_check_delay
	check_timer.one_shot = true
	check_timer.timeout.connect(func(): check_matches(grid_pos))
	check_timer.start()

func create_ripple_effect(position):
	# Create a ripple effect when a shape is placed on the grid
	var ripple = Sprite2D.new()
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(16, 16)
	var radius = 14
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius && dist >= radius - 3:
				var alpha = 1.0 - abs(dist - (radius - 1.5)) / 1.5
				img.set_pixel(x, y, Color(1.0, 0.9, 0.7, alpha * 0.8))
	
	ripple.texture = ImageTexture.create_from_image(img)
	ripple.position = position
	ripple.z_index = 5
	add_child(ripple)
	
	var tween = create_tween()
	tween.tween_property(ripple, "scale", Vector2(5, 5), 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(ripple, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ripple.queue_free)

func highlight_cell(grid_pos):
	# Add a visual highlight effect to the cell
	var highlight = ColorRect.new()
	highlight.color = Color(1, 1, 1, 0.5)
	highlight.size = Vector2(cell_size, cell_size)
	highlight.position = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
	highlight.z_index = 1
	add_child(highlight)
	
	# Enhanced fade out animation
	var tween = create_tween()
	tween.tween_property(highlight, "color", Color(0.7, 0.9, 1.0, 0.7), 0.2)
	tween.tween_property(highlight, "color", Color(0.7, 0.9, 1.0, 0), 0.5)
	tween.tween_callback(highlight.queue_free)

func check_matches(start_pos):
	match_checking_active = true
	
	var matched_positions = []
	var checked_positions = {}
	
	# Check for color and shape matches in all directions
	for direction in neighbor_directions:
		var current_matches = find_matches_in_direction(start_pos, direction)
		if current_matches.size() >= min_match_count:
			for pos in current_matches:
				if not pos in matched_positions:
					matched_positions.append(pos)
	
	# If matches found, remove them
	if matched_positions.size() >= min_match_count:
		remove_matches(matched_positions)
		SignalBus.shapes_popped.emit(matched_positions.size())
	else:
		# Check if the grid is becoming too full
		var enemy_count = get_tree().get_nodes_in_group("Enemies").size()
		if enemy_count > 25:  # If there are too many enemies, make matches easier
			check_for_near_matches(start_pos)
	
	match_checking_active = false

func find_matches_in_direction(start_pos, direction):
	var matches = [start_pos]
	
	if not grid.has(start_pos):
		return matches
	
	var start_shape = grid[start_pos]
	var start_color = start_shape.color
	var start_shape_type = start_shape.shape_type
	
	# Check forward
	var current_pos = start_pos + direction
	while is_valid_position(current_pos) and grid.has(current_pos):
		var current_shape = grid[current_pos]
		
		# Match by color and shape type
		if current_shape.color == start_color and current_shape.shape_type == start_shape_type:
			matches.append(current_pos)
			current_pos += direction
		else:
			break
	
	# Check backward
	current_pos = start_pos - direction
	while is_valid_position(current_pos) and grid.has(current_pos):
		var current_shape = grid[current_pos]
		
		# Match by color and shape type
		if current_shape.color == start_color and current_shape.shape_type == start_shape_type:
			matches.append(current_pos)
			current_pos -= direction
		else:
			break
	
	return matches

func is_valid_position(pos):
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func remove_matches(positions):
	# Sort positions by y-value for top-to-bottom removal
	positions.sort_custom(func(a, b): return a.y < b.y)
	
	# Remove matched shapes with a slight delay between each
	var delay = 0.05
	for i in range(positions.size()):
		var pos = positions[i]
		if grid.has(pos):
			var shape = grid[pos]
			
			# Create enhanced match effect at shape position
			create_match_effect(shape.global_position, shape.color)
			
			# Delayed destruction with tween
			var tween = create_tween()
			tween.tween_interval(delay * i)  # Increasing delay for cascade effect
			tween.tween_callback(func():
				if is_instance_valid(shape):
					shape.destroy()
					grid.erase(pos)
			)
	
	# Check if game over after removing matches
	check_game_over()

func create_match_effect(position, color_enum):
	# Get color from enum
	var shape_ref = load("res://scripts/shape.gd").new()
	shape_ref.color = color_enum
	var color = shape_ref.get_color_from_enum()
	shape_ref.queue_free()
	
	# Create enhanced particles for match effect
	var particles = CPUParticles2D.new()
	get_tree().root.add_child(particles)
	particles.position = position
	particles.amount = 30
	particles.lifetime = 1.0
	particles.explosiveness = 0.9
	particles.spread = 180
	particles.gravity = Vector2(0, 50)
	particles.initial_velocity_min = 70
	particles.initial_velocity_max = 170
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 8.0
	particles.color = color
	
	# Create expanding ring effect
	var ring = ColorRect.new()
	get_tree().root.add_child(ring)
	ring.color = color.lightened(0.5)
	ring.color.a = 0.7
	ring.size = Vector2(20, 20)
	ring.position = position - Vector2(10, 10)
	
	# Animate ring expansion and cleanup
	var ring_tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(8, 8), 0.5).set_trans(Tween.TRANS_SINE)
	ring_tween.parallel().tween_property(ring, "color:a", 0.0, 0.5)
	ring_tween.tween_callback(ring.queue_free)
	
	# Create light flash
	var flash = ColorRect.new()
	get_tree().root.add_child(flash)
	flash.color = color.lightened(0.5)
	flash.color.a = 0.7
	flash.size = Vector2(cell_size * 2, cell_size * 2)
	flash.position = position - Vector2(cell_size, cell_size)
	
	# Animate flash and cleanup
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.3)
	flash_tween.tween_callback(flash.queue_free)
	
	# Auto-remove particles after they're done
	var timer = Timer.new()
	particles.add_child(timer)
	timer.wait_time = 1.2
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	timer.start()

func check_game_over():
	# Check if any enemy has reached game over line
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.position.y > 640: # Game over line Y position
			SignalBus.grid_game_over.emit()
			return

# Function to check for positions where only one more shape is needed for a match
func check_for_near_matches(start_pos):
	var near_matches = []
	
	# Check each direction for near matches (one away from matching)
	for direction in neighbor_directions:
		var current_pos = start_pos
		var matches = [current_pos]
		
		if not grid.has(current_pos):
			continue
			
		var start_shape = grid[current_pos]
		var start_color = start_shape.color
		var start_shape_type = start_shape.shape_type
		
		# Check in this direction
		var next_pos = current_pos + direction
		while is_valid_position(next_pos) and grid.has(next_pos):
			var next_shape = grid[next_pos]
			if next_shape.color == start_color and next_shape.shape_type == start_shape_type:
				matches.append(next_pos)
			else:
				break
			next_pos += direction
		
		# Check opposite direction
		next_pos = current_pos - direction
		while is_valid_position(next_pos) and grid.has(next_pos):
			var next_shape = grid[next_pos]
			if next_shape.color == start_color and next_shape.shape_type == start_shape_type:
				matches.append(next_pos)
			else:
				break
			next_pos -= direction
		
		# If we found enough matches, remember them
		if matches.size() == min_match_count - 1:
			near_matches.append(matches)
	
	# Mark near-match cells with subtle highlight
	for match_group in near_matches:
		for pos in match_group:
			highlight_near_match(pos)

func highlight_near_match(grid_pos):
	# Subtle highlight to indicate a near-match
	var highlight = ColorRect.new()
	highlight.color = Color(1.0, 0.9, 0.5, 0.3)
	highlight.size = Vector2(cell_size, cell_size)
	highlight.position = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
	highlight.z_index = 1
	add_child(highlight)
	
	# Subtle pulse animation
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(highlight, "color:a", 0.1, 0.5)
	tween.tween_property(highlight, "color:a", 0.3, 0.5)
	tween.tween_callback(highlight.queue_free)
