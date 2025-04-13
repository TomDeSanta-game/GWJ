extends Node2D  


signal shapes_popped(count)  
signal game_over  


@export var grid_width: int = 6  
@export var grid_height: int = 7  
@export var cell_size: int = 100  
@export var game_over_row: int = 10  


@export var min_match_count: int = 3
@export var match_check_delay: float = 0.1


var grid = {}  
var neighbor_directions = [  
	Vector2i(1, 0),   
	Vector2i(0, 1),   
	Vector2i(-1, 1),  
	Vector2i(-1, 0),  
	Vector2i(0, -1),  
	Vector2i(1, -1),  
	Vector2i(-1, -1), 
	Vector2i(1, 1)    
]


var grid_layer_offset = Vector2(0, 0)
var cell_highlights = []
var cell_pulse_nodes = []
var match_checking_active = false
var grid_lines_color = Color(0.9, 0.8, 0.7, 0.2)  
var time_since_last_pulse = 0.0
var pulse_interval = 2.0  
var grid_sparkle_positions = []
var grid_sparkle_alphas = []
var grid_sparkle_sizes = []
var sparkle_tween: Tween
var near_match_cells = []  
var sparkle_targets = []  

func _ready():
	SignalBus.shape_collided.connect(_on_shape_collided)
	create_grid_highlights()
	enhance_grid_lines()
	add_grid_particles()
	add_ambient_effects()

func _process(delta):
	
	update_grid_visuals(delta)
	
	
	time_since_last_pulse += delta
	if time_since_last_pulse >= pulse_interval:
		create_grid_pulse()
		time_since_last_pulse = 0.0
	
	
	update_sparkles(delta)

func create_grid_pulse():
	
	var pulse = ColorRect.new()
	pulse.color = Color(0.7, 0.9, 1.0, 0.0)
	pulse.size = Vector2(cell_size - 10, cell_size - 10)
	pulse.position = Vector2(-cell_size, -cell_size) 
	pulse.z_index = 2
	add_child(pulse)
	
	
	var start_x = randi() % grid_width
	var start_pos = Vector2(start_x * cell_size + 5, -cell_size)
	
	
	var end_x = randi() % grid_width
	var end_pos = Vector2(end_x * cell_size + 5, grid_height * cell_size + cell_size)
	
	
	var tween = safe_tween(pulse)
	if tween:
		tween.tween_property(pulse, "position", start_pos, 0.1)
		tween.tween_property(pulse, "color", Color(0.7, 0.9, 1.0, 0.5), 0.2)
		tween.tween_property(pulse, "position", end_pos, 1.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(pulse, "color", Color(0.7, 0.9, 1.0, 0.0), 1.5)
		tween.tween_callback(pulse.queue_free)

func enhance_grid_lines():
	
	var horizontal_lines = get_node("GridLines/HorizontalLines")
	var vertical_lines = get_node("GridLines/VerticalLines")
	
	if horizontal_lines and vertical_lines:
		
		for line in horizontal_lines.get_children():
			if line is Line2D:
				line.default_color = grid_lines_color
				line.width = 2.0
		
		
		for line in vertical_lines.get_children():
			if line is Line2D:
				line.default_color = grid_lines_color
				line.width = 2.0
	
	
	for x in range(grid_width + 1):
		for y in range(grid_height + 1):
			var glow = Sprite2D.new()
			
			
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
	
	var particles = CPUParticles2D.new()
	particles.position = Vector2(grid_width * cell_size / 2, grid_height * cell_size / 2)
	particles.amount = 40
	particles.lifetime = 5.0
	particles.preprocess = 5.0
	particles.emission_shape = 2  
	particles.emission_rect_extents = Vector2(grid_width * cell_size / 2, grid_height * cell_size / 2)
	particles.gravity = Vector2(0, -10)
	particles.initial_velocity_min = 5
	particles.initial_velocity_max = 15
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(1.0, 0.9, 0.7, 0.15)
	add_child(particles)

func create_grid_highlights():
	
	for x in range(grid_width):
		for y in range(grid_height):
			var highlight = Sprite2D.new()
			
			
			var img = Image.create(cell_size - 4, cell_size - 4, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			
			var corner_radius = 18  
			var width = cell_size - 4
			var height = cell_size - 4
			
			for px in range(width):
				for py in range(height):
					var in_corner = false
					var corner_dist = 0.0
					
					
					if px < corner_radius && py < corner_radius:
						
						corner_dist = Vector2(px, py).distance_to(Vector2(corner_radius, corner_radius))
						in_corner = true
					elif px >= width - corner_radius && py < corner_radius:
						
						corner_dist = Vector2(px, py).distance_to(Vector2(width - corner_radius, corner_radius))
						in_corner = true
					elif px < corner_radius && py >= height - corner_radius:
						
						corner_dist = Vector2(px, py).distance_to(Vector2(corner_radius, height - corner_radius))
						in_corner = true
					elif px >= width - corner_radius && py >= height - corner_radius:
						
						corner_dist = Vector2(px, py).distance_to(Vector2(width - corner_radius, height - corner_radius))
						in_corner = true
					
					if in_corner:
						if corner_dist <= corner_radius:
							
							var alpha = 1.0 - (corner_dist / corner_radius) * 0.7
							img.set_pixel(px, py, Color(1.0, 0.95, 0.9, alpha * 0.17))
					else:
						
						img.set_pixel(px, py, Color(1.0, 0.95, 0.9, 0.17))
			
			highlight.texture = ImageTexture.create_from_image(img)
			highlight.position = Vector2(x * cell_size + cell_size/2, y * cell_size + cell_size/2)
			highlight.z_index = -1
			add_child(highlight)
			cell_highlights.append(highlight)

func update_grid_visuals(delta):
	
	grid_layer_offset.y = sin(Time.get_ticks_msec() * 0.0003) * 1.0
	grid_layer_offset.x = cos(Time.get_ticks_msec() * 0.0005) * 0.5
	position = grid_layer_offset
	
	
	var time = Time.get_ticks_msec() * 0.001
	for i in range(cell_highlights.size()):
		var x = i % grid_width
		var y = i / grid_width
		var phase = (x + y) * 0.5 + time
		var alpha = (sin(phase) + 1) * 0.1
		cell_highlights[i].modulate.a = alpha
	
	
	for i in range(cell_pulse_nodes.size()):
		var pulse_time = time + i * 0.1
		var size_factor = 1.0 + 0.2 * sin(pulse_time * 2.0)
		var alpha = 0.2 + 0.1 * sin(pulse_time)
		cell_pulse_nodes[i].scale = Vector2(size_factor, size_factor)
		cell_pulse_nodes[i].modulate.a = alpha

func _on_shape_collided(shape, collision_point):
	
	if match_checking_active:
		return
	
	
	var grid_x = int(collision_point.x / cell_size)
	var grid_y = int(collision_point.y / cell_size)
	
	
	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return
	
	
	var grid_pos = Vector2i(grid_x, grid_y)
	if grid.has(grid_pos):
		find_adjacent_empty_cell(shape, grid_pos)
	else:
		
		place_shape_in_grid(shape, grid_pos)
		highlight_cell(grid_pos)

func find_adjacent_empty_cell(shape, grid_pos):
	
	var check_order = [
		Vector2i(0, -1),  
		Vector2i(1, 0),   
		Vector2i(0, 1),   
		Vector2i(-1, 0),  
		Vector2i(1, -1),  
		Vector2i(1, 1),   
		Vector2i(-1, 1),  
		Vector2i(-1, -1)  
	]
	
	for offset in check_order:
		var new_pos = grid_pos + offset
		
		
		if new_pos.x >= 0 and new_pos.x < grid_width and new_pos.y >= 0 and new_pos.y < grid_height:
			
			if not grid.has(new_pos):
				place_shape_in_grid(shape, new_pos)
				highlight_cell(new_pos)
				return
	
	
	shape.queue_free()

func place_shape_in_grid(shape, grid_pos):
	
	var target_position = Vector2(grid_pos.x * cell_size + cell_size/2, grid_pos.y * cell_size + cell_size/2)
	
	
	var tween = safe_tween(shape)
	if tween:
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(shape, "global_position", target_position, 0.3)
	
	
	grid[grid_pos] = shape
	
	
	shape.attach_to_grid(grid_pos)
	
	
	create_ripple_effect(target_position)
	
	
	var check_timer = Timer.new()
	add_child(check_timer)
	check_timer.wait_time = match_check_delay
	check_timer.one_shot = true
	check_timer.timeout.connect(func(): check_matches(grid_pos))
	check_timer.start()

func create_ripple_effect(position):
	
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
	
	var tween = safe_tween(ripple)
	if tween:
		tween.tween_property(ripple, "scale", Vector2(5, 5), 0.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(ripple, "modulate:a", 0.0, 0.5)
		tween.tween_callback(ripple.queue_free)

func highlight_cell(grid_pos):
	
	var highlight = Node2D.new()
	highlight.position = Vector2(grid_pos.x * cell_size + cell_size/2, grid_pos.y * cell_size + cell_size/2)
	highlight.z_index = 1
	add_child(highlight)
	
	
	var size = cell_size - 10
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var corner_radius = 20
	
	for x in range(size):
		for y in range(size):
			var in_corner = false
			var corner_dist = 0.0
			
			
			if x < corner_radius && y < corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(corner_radius, corner_radius))
				in_corner = true
			elif x >= size - corner_radius && y < corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(size - corner_radius, corner_radius))
				in_corner = true
			elif x < corner_radius && y >= size - corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(corner_radius, size - corner_radius))
				in_corner = true
			elif x >= size - corner_radius && y >= size - corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(size - corner_radius, size - corner_radius))
				in_corner = true
			
			if in_corner:
				if corner_dist <= corner_radius:
					var alpha = 1.0 - (corner_dist / corner_radius) * 0.5
					img.set_pixel(x, y, Color(1.0, 0.95, 0.85, alpha * 0.7))
			else:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.85, 0.7))
	
	var sprite = Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(0, 0)
	highlight.add_child(sprite)
	
	
	var tween = safe_tween(sprite)
	if tween:
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "modulate", Color(1.0, 0.95, 0.85, 0.9), 0.2)
		tween.chain().set_parallel(false)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(sprite, "modulate", Color(0.7, 0.9, 1.0, 0), 0.6)
		tween.tween_callback(highlight.queue_free)
	
	
	var particles = CPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.6
	particles.explosiveness = 0.7
	particles.emission_shape = 0  
	particles.emission_sphere_radius = size / 4
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 5)
	particles.initial_velocity_min = 10
	particles.initial_velocity_max = 30
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	particles.color = Color(1.0, 0.95, 0.85, 0.5)
	highlight.add_child(particles)

func check_matches(start_pos):
	match_checking_active = true
	
	var matched_positions = []
	var checked_positions = {}
	
	
	for direction in neighbor_directions:
		var current_matches = find_matches_in_direction(start_pos, direction)
		if current_matches.size() >= min_match_count:
			for pos in current_matches:
				if not pos in matched_positions:
					matched_positions.append(pos)
	
	
	if matched_positions.size() >= min_match_count:
		remove_matches(matched_positions)
		SignalBus.shapes_popped.emit(matched_positions.size())
	else:
		
		var enemy_count = get_tree().get_nodes_in_group("Enemies").size()
		if enemy_count > 25:  
			check_for_near_matches(start_pos)
	
	match_checking_active = false

func find_matches_in_direction(start_pos, direction):
	var matches = [start_pos]
	
	if not grid.has(start_pos):
		return matches
	
	var start_shape = grid[start_pos]
	var start_color = start_shape.color
	var start_shape_type = start_shape.shape_type
	
	
	var current_pos = start_pos + direction
	while is_valid_position(current_pos) and grid.has(current_pos):
		var current_shape = grid[current_pos]
		
		
		if current_shape.color == start_color and current_shape.shape_type == start_shape_type:
			matches.append(current_pos)
			current_pos += direction
		else:
			break
	
	
	current_pos = start_pos - direction
	while is_valid_position(current_pos) and grid.has(current_pos):
		var current_shape = grid[current_pos]
		
		
		if current_shape.color == start_color and current_shape.shape_type == start_shape_type:
			matches.append(current_pos)
			current_pos -= direction
		else:
			break
	
	return matches

func is_valid_position(pos):
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func remove_matches(positions):
	
	positions.sort_custom(func(a, b): return a.y < b.y)
	
	
	var delay = 0.05
	for i in range(positions.size()):
		var pos = positions[i]
		if grid.has(pos):
			var shape = grid[pos]
			
			
			create_match_effect(shape.global_position, shape.color)
			
			
			var tween = safe_tween()
			tween.tween_interval(delay * i)  
			tween.tween_callback(func():
				if is_instance_valid(shape):
					shape.destroy()
					grid.erase(pos)
			)
	
	
	check_game_over()

func create_match_effect(position, color_enum):
	
	var shape_ref = load("res:
	shape_ref.color = color_enum
	var color = shape_ref.get_color_from_enum()
	shape_ref.queue_free()
	
	
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
	
	
	var ring = ColorRect.new()
	get_tree().root.add_child(ring)
	ring.color = color.lightened(0.5)
	ring.color.a = 0.7
	ring.size = Vector2(20, 20)
	ring.position = position - Vector2(10, 10)
	
	
	var ring_tween = safe_tween(ring)
	if ring_tween:
		ring_tween.tween_property(ring, "scale", Vector2(8, 8), 0.5).set_trans(Tween.TRANS_SINE)
		ring_tween.parallel().tween_property(ring, "color:a", 0.0, 0.5)
		ring_tween.tween_callback(ring.queue_free)
	
	
	var flash = ColorRect.new()
	get_tree().root.add_child(flash)
	flash.color = color.lightened(0.5)
	flash.color.a = 0.7
	flash.size = Vector2(cell_size * 2, cell_size * 2)
	flash.position = position - Vector2(cell_size, cell_size)
	
	
	var flash_tween = safe_tween(flash)
	if flash_tween:
		flash_tween.tween_property(flash, "color:a", 0.0, 0.3)
		flash_tween.tween_callback(flash.queue_free)
	
	
	var timer = Timer.new()
	particles.add_child(timer)
	timer.wait_time = 1.2
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	timer.start()

func check_game_over():
	
	var enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in enemies:
		if enemy.position.y > 640: 
			SignalBus.grid_game_over.emit()
			return


func check_for_near_matches(start_pos):
	near_match_cells = []  
	
	
	for direction in neighbor_directions:
		var current_pos = start_pos
		var matches = [current_pos]
		
		if not grid.has(current_pos):
			continue
			
		var start_shape = grid[current_pos]
		var start_color = start_shape.color
		var start_shape_type = start_shape.shape_type
		
		
		var next_pos = current_pos + direction
		while is_valid_position(next_pos) and grid.has(next_pos):
			var next_shape = grid[next_pos]
			if next_shape.color == start_color and next_shape.shape_type == start_shape_type:
				matches.append(next_pos)
			else:
				break
			next_pos += direction
		
		
		next_pos = current_pos - direction
		while is_valid_position(next_pos) and grid.has(next_pos):
			var next_shape = grid[next_pos]
			if next_shape.color == start_color and next_shape.shape_type == start_shape_type:
				matches.append(next_pos)
			else:
				break
			next_pos -= direction
		
		
		if matches.size() == min_match_count - 1:
			for pos in matches:
				if not near_match_cells.has(pos):
					near_match_cells.append(pos)
	
	
	queue_redraw()

func highlight_near_match(grid_pos):
	
	var highlight = Node2D.new()
	highlight.position = Vector2(grid_pos.x * cell_size + cell_size/2, grid_pos.y * cell_size + cell_size/2)
	highlight.z_index = 1
	add_child(highlight)
	
	
	var size = cell_size - 15
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var corner_radius = 20
	
	for x in range(size):
		for y in range(size):
			var in_corner = false
			var corner_dist = 0.0
			
			
			if x < corner_radius && y < corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(corner_radius, corner_radius))
				in_corner = true
			elif x >= size - corner_radius && y < corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(size - corner_radius, corner_radius))
				in_corner = true
			elif x < corner_radius && y >= size - corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(corner_radius, size - corner_radius))
				in_corner = true
			elif x >= size - corner_radius && y >= size - corner_radius:
				corner_dist = Vector2(x, y).distance_to(Vector2(size - corner_radius, size - corner_radius))
				in_corner = true
			
			if in_corner:
				if corner_dist <= corner_radius:
					var alpha = 1.0 - (corner_dist / corner_radius) * 0.5
					img.set_pixel(x, y, Color(1.0, 0.9, 0.5, alpha * 0.3))
			else:
				img.set_pixel(x, y, Color(1.0, 0.9, 0.5, 0.3))
	
	var sprite = Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(0, 0)
	highlight.add_child(sprite)
	
	
	var tween = safe_tween(sprite)
	if tween:
		tween.set_loops(3)
		tween.tween_property(sprite, "scale", Vector2(1.05, 1.05), 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "scale", Vector2(0.95, 0.95), 0.5).set_trans(Tween.TRANS_SINE)
		tween.chain()
		tween.tween_property(sprite, "modulate:a", 0, 0.3)
		tween.tween_callback(highlight.queue_free)
	
	
	var particles = CPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 1.0
	particles.emission_shape = 0  
	particles.emission_sphere_radius = size / 6
	particles.local_coords = false
	particles.direction = Vector2(0, -1)
	particles.spread = 90
	particles.gravity = Vector2(0, 2)
	particles.initial_velocity_min = 5
	particles.initial_velocity_max = 15
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3
	particles.color = Color(1.0, 0.9, 0.5, 0.2)
	highlight.add_child(particles)

func add_ambient_effects():
	
	grid_sparkle_positions = []
	grid_sparkle_alphas = []
	grid_sparkle_sizes = []
	sparkle_targets = []  
	
	
	for i in range(20):  
		var pos = Vector2(
			randf_range(0, grid_width * cell_size),
			randf_range(0, grid_height * cell_size)
		)
		grid_sparkle_positions.append(pos)
		grid_sparkle_alphas.append(randf_range(0.1, 0.5))  
		grid_sparkle_sizes.append(randf_range(1.0, 3.0))  
		
		
		sparkle_targets.append({
			"alpha": 0.0,
			"size": randf_range(0.5, 1.5),
			"alpha_speed": 1.0 / randf_range(1.0, 2.5),
			"size_speed": 1.0 / randf_range(1.0, 2.5),
			"alpha_target": 0.0,
			"size_target": 0.0,
			"alpha_direction": -1,
			"size_direction": -1
		})
	
	
	var min_length = min(grid_sparkle_positions.size(), min(grid_sparkle_alphas.size(), min(grid_sparkle_sizes.size(), sparkle_targets.size())))
	if min_length > 0:
		grid_sparkle_positions.resize(min_length)
		grid_sparkle_alphas.resize(min_length)
		grid_sparkle_sizes.resize(min_length)
		sparkle_targets.resize(min_length)
	
	
	for i in range(grid_sparkle_positions.size()):
		reset_sparkle_targets(i)
	
	
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.amount = 15
	particles.lifetime = 8.0
	particles.emission_shape = 2  
	particles.emission_rect_extents = Vector2(grid_width * cell_size / 2, 5)
	particles.position = Vector2(grid_width * cell_size / 2, grid_height * cell_size + 10)
	particles.gravity = Vector2(0, -10)  
	particles.initial_velocity_min = 10
	particles.initial_velocity_max = 20
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.9, 0.95, 1.0, 0.15)  

	
	var grid_pulse = safe_tween(self)
	if grid_pulse:
		grid_pulse.set_loops(0)  
		grid_pulse.tween_property(self, "modulate", Color(1.05, 1.05, 1.08, 1.0), 3.0).set_trans(Tween.TRANS_SINE)
		grid_pulse.tween_property(self, "modulate", Color(0.95, 0.95, 0.98, 1.0), 3.0).set_trans(Tween.TRANS_SINE)


func reset_sparkle_targets(index: int) -> void:
	
	if sparkle_targets.size() <= index:
		
		sparkle_targets.append({
			"alpha": 0.0,
			"size": randf_range(0.5, 1.5),
			"alpha_speed": 1.0 / randf_range(1.0, 2.5),
			"size_speed": 1.0 / randf_range(1.0, 2.5),
			"alpha_target": 0.0,
			"size_target": 0.0,
			"alpha_direction": -1,
			"size_direction": -1
		})
	
	
	if sparkle_targets[index].alpha_direction < 0:
		sparkle_targets[index].alpha_target = randf_range(0.3, 0.6)
		sparkle_targets[index].alpha_direction = 1
		sparkle_targets[index].alpha_speed = 1.0 / randf_range(1.0, 2.5)
	else:  
		sparkle_targets[index].alpha_target = 0.0
		sparkle_targets[index].alpha_direction = -1
		sparkle_targets[index].alpha_speed = 1.0 / randf_range(1.0, 2.5)
		
	
	if sparkle_targets[index].size_direction < 0:
		sparkle_targets[index].size_target = randf_range(1.5, 3.5)
		sparkle_targets[index].size_direction = 1
		sparkle_targets[index].size_speed = 1.0 / randf_range(1.0, 2.5)
	else:
		sparkle_targets[index].size_target = randf_range(0.5, 1.5)
		sparkle_targets[index].size_direction = -1
		sparkle_targets[index].size_speed = 1.0 / randf_range(1.0, 2.5)

func update_sparkles(delta: float) -> void:
	
	if grid_sparkle_positions.size() == 0:
		return
	
	
	while sparkle_targets.size() < grid_sparkle_positions.size():
		reset_sparkle_targets(sparkle_targets.size())
	
	
	while grid_sparkle_alphas.size() < grid_sparkle_positions.size():
		grid_sparkle_alphas.append(randf_range(0.1, 0.5))
	
	while grid_sparkle_sizes.size() < grid_sparkle_positions.size():
		grid_sparkle_sizes.append(randf_range(1.0, 3.0))
	
	for i in range(grid_sparkle_positions.size()):
		
		if i >= sparkle_targets.size() or i >= grid_sparkle_alphas.size() or i >= grid_sparkle_sizes.size():
			continue
			
		var target = sparkle_targets[i]
		
		
		var alpha_diff = target.alpha_target - grid_sparkle_alphas[i]
		if abs(alpha_diff) < 0.01:
			reset_sparkle_targets(i)  
		else:
			grid_sparkle_alphas[i] += alpha_diff * target.alpha_speed * delta * 2.0
		
		
		var size_diff = target.size_target - grid_sparkle_sizes[i]
		if abs(size_diff) < 0.05:
			pass  
		else:
			grid_sparkle_sizes[i] += size_diff * target.size_speed * delta * 2.0
		
	
	queue_redraw()

func create_match_pulse(grid_pos: Vector2i, color: Color, match_size: int = 3):
	
	var pulse = ColorRect.new()
	add_child(pulse)
	
	var pulse_size = cell_size * 0.8
	pulse.size = Vector2(pulse_size, pulse_size)
	
	
	pulse.position = Vector2(
		grid_pos.x * cell_size + (cell_size - pulse_size) / 2,
		grid_pos.y * cell_size + (cell_size - pulse_size) / 2
	)
	
	
	var intensity = min(0.5 + (match_size * 0.1), 0.9)
	pulse.color = Color(0.95, 0.85, 0.7, intensity)
	
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = pulse.color
	style_box.corner_radius_top_left = pulse_size * 0.3
	style_box.corner_radius_top_right = pulse_size * 0.3
	style_box.corner_radius_bottom_left = pulse_size * 0.3
	style_box.corner_radius_bottom_right = pulse_size * 0.3
	
	pulse.add_theme_stylebox_override("panel", style_box)
	
	
	var tween = create_tween()
	tween.tween_property(pulse, "modulate:a", 0.0, 0.8)
	tween.tween_callback(pulse.queue_free)
	
	return pulse

func _draw():
	
	var bg_color1 = Color(0.98, 0.95, 0.9, 1.0)  
	var bg_color2 = Color(0.97, 0.92, 0.85, 1.0)  
	var background_rect = Rect2(0, 0, grid_width * cell_size, grid_height * cell_size)
	
	
	for y in range(grid_height * cell_size):
		var t = float(y) / (grid_height * cell_size)
		var color = bg_color1.lerp(bg_color2, t)
		var line_rect = Rect2(0, y, grid_width * cell_size, 1)
		draw_rect(line_rect, color, true)
	
	
	var shadow_width = 20.0
	var shadow_color = Color(0.7, 0.65, 0.6, 0.2)
	var inner_rect = Rect2(shadow_width, shadow_width, 
		grid_width * cell_size - shadow_width * 2, 
		grid_height * cell_size - shadow_width * 2)
	draw_rect(inner_rect, shadow_color, false, shadow_width)
	
	
	for i in range(15):
		var x = randf_range(0, grid_width * cell_size)
		var y = randf_range(0, grid_height * cell_size)
		var sparkle_size = randf_range(1.5, 3.0)
		var sparkle_color = Color(1.0, 0.98, 0.92, randf_range(0.1, 0.25))
		draw_circle(Vector2(x, y), sparkle_size, sparkle_color)
	
	
	for x in range(grid_width):
		for y in range(grid_height):
			var cell_pos = Vector2(x * cell_size, y * cell_size)
			var cell_color = Color(0.9, 0.87, 0.83, 0.3)  
			
			
			var corner_radius = 15.0  
			
			
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = cell_color
			style_box.corner_radius_top_left = corner_radius
			style_box.corner_radius_top_right = corner_radius
			style_box.corner_radius_bottom_left = corner_radius
			style_box.corner_radius_bottom_right = corner_radius
			
			
			var rect = Rect2(cell_pos.x + 2, cell_pos.y + 2, cell_size - 4, cell_size - 4)
			draw_style_box(style_box, rect)
	
	
	for cell in near_match_cells:
		if is_valid_position(cell):
			var cell_pos = Vector2(cell.x * cell_size, cell.y * cell_size)
			var hint_color = Color(1.0, 0.9, 0.7, 0.3)
			
			
			var corner_radius = 15.0
			
			
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = hint_color
			style_box.corner_radius_top_left = corner_radius
			style_box.corner_radius_top_right = corner_radius
			style_box.corner_radius_bottom_left = corner_radius
			style_box.corner_radius_bottom_right = corner_radius
			
			
			var rect = Rect2(cell_pos.x + 2, cell_pos.y + 2, cell_size - 4, cell_size - 4)
			draw_style_box(style_box, rect)

func safe_tween(target_node: Node = null) -> Tween:
	var tween = create_tween()
	if tween == null:
		
		if target_node:
			tween = target_node.create_tween()
	
	return tween

func snap_to_grid(shape_node):
	
	var grid_pos = get_grid_position_from_world(shape_node.global_position)
	
	if is_valid_position(grid_pos) and not grid.has(grid_pos):
		
		add_shape_to_grid(shape_node, grid_pos)
		return true
	else:
		
		var closest_pos = find_closest_available_position(grid_pos)
		if closest_pos != grid_pos:
			add_shape_to_grid(shape_node, closest_pos)
			return true
	
	return false

func find_closest_available_position(start_pos):
	if is_valid_position(start_pos) and not grid.has(start_pos):
		return start_pos
	
	
	var layer = 1
	
	while layer < 5:  
		
		var cur_x = start_pos.x - layer
		for var_y in range(start_pos.y - layer, start_pos.y + layer + 1):
			var pos = Vector2i(cur_x, var_y)
			if is_valid_position(pos) and not grid.has(pos):
				return pos
		
		
		var cur_y = start_pos.y + layer
		for var_x in range(start_pos.x - layer + 1, start_pos.x + layer + 1):
			var pos = Vector2i(var_x, cur_y)
			if is_valid_position(pos) and not grid.has(pos):
				return pos
		
		
		cur_x = start_pos.x + layer
		for var_y in range(start_pos.y + layer - 1, start_pos.y - layer - 1, -1):
			var pos = Vector2i(cur_x, var_y)
			if is_valid_position(pos) and not grid.has(pos):
				return pos
		
		
		cur_y = start_pos.y - layer
		for var_x in range(start_pos.x + layer - 1, start_pos.x - layer - 1, -1):
			var pos = Vector2i(var_x, cur_y)
			if is_valid_position(pos) and not grid.has(pos):
				return pos
		
		layer += 1
	
	return start_pos  

func add_shape_to_grid(shape_node, grid_pos):
	
	var world_pos = get_world_position_from_grid(grid_pos)
	shape_node.global_position = world_pos
	
	
	var snap_tween = create_tween()
	snap_tween.tween_property(shape_node, "scale", Vector2(1.1, 1.1), 0.1)
	snap_tween.tween_property(shape_node, "scale", Vector2(1, 1), 0.1)
	
	
	grid[grid_pos] = shape_node
	
	
	shape_node.attach_to_grid(grid_pos)
	
	
	create_shape_placement_pulse(grid_pos, shape_node.color)
	
	
	check_matches(grid_pos)

func get_grid_position_from_world(world_pos: Vector2) -> Vector2i:
	
	var x = int(world_pos.x / cell_size)
	var y = int(world_pos.y / cell_size)
	return Vector2i(x, y)

func get_world_position_from_grid(grid_pos: Vector2i) -> Vector2:
	
	var x = grid_pos.x * cell_size + cell_size / 2
	var y = grid_pos.y * cell_size + cell_size / 2
	return Vector2(x, y)


func create_shape_placement_pulse(grid_pos: Vector2i, shape_color = null):
	
	var pulse = ColorRect.new()
	add_child(pulse)
	
	
	var pulse_color = Color(1.0, 0.9, 0.7, 0.4)  
	if shape_color != null:
		
		var color_obj = load("res:
		color_obj.color = shape_color
		pulse_color = color_obj.get_color_from_enum(shape_color).lightened(0.3)
		pulse_color.a = 0.4
		color_obj.queue_free()
	
	
	var world_pos = get_world_position_from_grid(grid_pos)
	var pulse_size = cell_size * 0.9
	pulse.size = Vector2(pulse_size, pulse_size)
	pulse.position = world_pos - Vector2(pulse_size / 2, pulse_size / 2)
	pulse.color = pulse_color
	
	
	var style = StyleBoxFlat.new()
	style.bg_color = pulse_color
	style.corner_radius_top_left = pulse_size * 0.3
	style.corner_radius_top_right = pulse_size * 0.3
	style.corner_radius_bottom_left = pulse_size * 0.3
	style.corner_radius_bottom_right = pulse_size * 0.3
	
	
	pulse.add_theme_stylebox_override("panel", style)
	
	
	var tween = create_tween()
	tween.tween_property(pulse, "size", Vector2(pulse_size * 1.3, pulse_size * 1.3), 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(pulse, "position", world_pos - Vector2(pulse_size * 1.3 / 2, pulse_size * 1.3 / 2), 0.3)
	tween.parallel().tween_property(pulse, "color:a", 0.0, 0.5)
	tween.tween_callback(pulse.queue_free)
