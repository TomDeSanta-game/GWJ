extends RigidBody2D  # Inherits from RigidBody2D, giving physics properties like collision and gravity

# Enums define fixed sets of possible values
enum ShapeColor { RED, BLUE, GREEN, YELLOW, PURPLE }  # Define possible colors for shapes
enum ShapeType { CIRCLE, TRIANGLE, SQUARE }  # Define possible shape types

# Properties that define the shape's characteristics
var color: ShapeColor  # Stores the current color using the ShapeColor enum
var shape_type: ShapeType  # Stores the current shape type using the ShapeType enum
var radius: float = 48.0  # Default radius size for the shape in pixels
var is_attached_to_grid: bool = false  # Tracks if shape is attached to a game grid
var grid_position: Vector2i = Vector2i(-1, -1)  # Position on grid, (-1,-1) means not on grid
var is_enemy: bool = false  # Flag to differentiate between player and enemy shapes
var target_position: Vector2 = Vector2.ZERO  # Target position for enemy movement
var move_speed: float = 80.0  # Speed at which enemy shapes move (pixels/second)
var health: int = 1  # Health points of the shape, when 0 the shape is destroyed

# Visual properties
var outline: Node2D  # Main node that holds all visual elements for the shape

# Texture caching - Store pre-generated textures to avoid redrawing them
static var cached_textures = {}

func _ready():  # Built-in Godot function that runs when node enters scene tree
	initialize_shape()  # Call our custom initialization function
	preload_sounds()  # Preload sound resources
	connect_signals()  # Connect signals for collision detection
	
func initialize_shape():  # Initializes shape appearance and behavior
	set_random_color()  # Randomly select a color
	set_random_shape()  # Randomly select a shape type
	setup_collision()  # Setup the physics collision shape
	create_shape_visual()  # Create the visual shape with effects
	
	var visual = get_node_or_null("Visual")  # Get reference to the Visual child node
	if visual:  # If Visual node exists
		visual.queue_free()  # Remove it as we'll create our own visuals
	
	gravity_scale = 0.0  # Disable gravity effect on this RigidBody2D

func _process(delta: float):  # Built-in Godot function called every frame
	if is_enemy and not is_attached_to_grid:  # If this is an enemy shape not attached to grid
		move_towards_target(delta)  # Move it towards its target

func move_towards_target(delta: float):  # Moves enemy shape towards its target
	var direction = (target_position - global_position).normalized()  # Calculate normalized direction vector
	global_position += direction * move_speed * delta  # Move shape based on direction, speed and delta time
	rotation = direction.angle() + PI/2  # Rotate shape to face movement direction
	
	if global_position.y > 700:  # If shape has moved below the bottom of the screen
		var game_controller = get_node("/root/Main")  # Get reference to game controller
		if game_controller:  # If controller exists
			game_controller.check_enemies_reached_bottom()  # Notify controller that enemy reached bottom

func set_random_color():  # Sets a random color from the ShapeColor enum
	color = ShapeColor.values()[randi() % ShapeColor.size()]  # Pick random color from enum
	
func set_color(new_color: ShapeColor):  # Sets a specific color
	color = new_color  # Update the color property
	
func set_random_shape():  # Sets a random shape from the ShapeType enum
	shape_type = ShapeType.values()[randi() % ShapeType.size()]  # Pick random shape from enum
	
func set_shape(new_shape: ShapeType):  # Sets a specific shape type
	shape_type = new_shape  # Update the shape_type property
	
func setup_collision():  # Sets up the collision shape for physics
	var collision_shape = get_node_or_null("CollisionShape2D")
	
	# Create collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	
	# Setup collision layers based on type
	if is_enemy:
		collision_layer = 2  # Layer 2 for enemies
		collision_mask = 1   # Collide with player shapes
	else:
		collision_layer = 1  # Layer 1 for player shapes
		collision_mask = 2   # Collide with enemies
	
	# Create the actual shape
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius  # Set radius from our property
	collision_shape.shape = circle_shape  # Assign shape to collision shape component

func create_shape_visual():  # Creates the visual representation of the shape
	if outline:  # If previous outline exists
		outline.queue_free()  # Remove it
		
	outline = Node2D.new()  # Create a container for all visual elements
	outline.z_index = 5  # Set to render above other elements
	add_child(outline)
	
	# Create enhanced glow effect - larger and softer
	var glow = ColorRect.new()
	var shape_color = get_color_from_enum()
	var glow_size = radius * 3.5  # Larger glow for a softer, cozier look
	glow.size = Vector2(glow_size, glow_size)
	glow.position = Vector2(-glow_size/2, -glow_size/2)
	glow.color = shape_color.lightened(0.5)
	glow.color.a = 0.25  # More visible glow
	outline.add_child(glow)
	
	# Add inner glow for extra coziness
	var inner_glow = ColorRect.new()
	var inner_size = radius * 2.4
	inner_glow.size = Vector2(inner_size, inner_size)
	inner_glow.position = Vector2(-inner_size/2, -inner_size/2)
	inner_glow.color = shape_color.lightened(0.35)
	inner_glow.color.a = 0.3
	outline.add_child(inner_glow)
	
	# Create shape sprite
	var shape_sprite = Sprite2D.new()
	
	# Check if texture is cached
	var cache_key = "%d_%d" % [shape_type, color]
	var scale_factor = 2  # Reduced scale factor for better performance
	
	if not cached_textures.has(cache_key):
		# Not cached, generate it
		var shape_size = int(radius * 2 + 8) * scale_factor # Slightly larger for softer edges
		var image = Image.create(shape_size, shape_size, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))  # Fill with transparent color
		
		var center = Vector2(shape_size / 2.0, shape_size / 2.0)
		var fill_color = get_color_from_enum()
		
		# Draw the shape based on shape_type - with enhanced lighting effects
		match shape_type:
			ShapeType.CIRCLE:
				draw_circle_shape(image, center, fill_color, scale_factor)
			ShapeType.TRIANGLE:
				draw_triangle_shape(image, center, fill_color, scale_factor)
			ShapeType.SQUARE:
				draw_square_shape(image, center, fill_color, scale_factor)
		
		cached_textures[cache_key] = ImageTexture.create_from_image(image)
	
	shape_sprite.texture = cached_textures[cache_key]
	shape_sprite.scale = Vector2(1.0 / scale_factor, 1.0 / scale_factor)
	outline.add_child(shape_sprite)
	
	# Add enhanced particle effects - more and prettier
	var particles = CPUParticles2D.new()
	particles.amount = 16  # More particles
	particles.lifetime = 2.0  # Longer lifetime
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius * 0.8  # Larger emission area
	particles.local_coords = true
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 4
	particles.initial_velocity_max = 12
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.0
	particles.color = shape_color.lightened(0.45)  # Lighter particles
	particles.color.a = 0.4  # More visible
	outline.add_child(particles)
	
	# Add subtle twinkling stars effect
	var stars = CPUParticles2D.new()
	stars.amount = 8
	stars.lifetime = 3.0
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	stars.emission_sphere_radius = radius * 0.9
	stars.local_coords = true
	stars.gravity = Vector2.ZERO
	stars.initial_velocity_min = 1
	stars.initial_velocity_max = 3
	stars.angle = 45
	stars.scale_amount_min = 3.5
	stars.scale_amount_max = 6.0
	stars.color = Color(1.0, 0.98, 0.9, 0.6)
	outline.add_child(stars)
	
	# Animate the stars for twinkling effect
	var stars_tween = create_tween()
	stars_tween.set_loops()
	stars_tween.tween_property(stars, "modulate:a", 0.2, 1.5)
	stars_tween.tween_property(stars, "modulate:a", 0.6, 1.5)
	
	# Enhanced glow animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 2.0).set_trans(Tween.TRANS_SINE)
	
	# Inner glow animation
	var inner_tween = create_tween()
	inner_tween.set_loops()
	inner_tween.tween_property(inner_glow, "scale", Vector2(1.07, 1.07), 1.2).set_trans(Tween.TRANS_SINE)
	inner_tween.tween_property(inner_glow, "scale", Vector2(0.95, 0.95), 1.2).set_trans(Tween.TRANS_SINE)
	
	# Add rotation animation based on shape type
	if shape_type == ShapeType.TRIANGLE:
		var rotation_tween = create_tween()
		rotation_tween.set_loops()
		rotation_tween.tween_property(shape_sprite, "rotation", PI/8, 4.0).set_trans(Tween.TRANS_SINE)
		rotation_tween.tween_property(shape_sprite, "rotation", -PI/8, 4.0).set_trans(Tween.TRANS_SINE)
	elif shape_type == ShapeType.SQUARE:
		var rotation_tween = create_tween()
		rotation_tween.set_loops()
		rotation_tween.tween_property(shape_sprite, "rotation", PI/12, 5.0).set_trans(Tween.TRANS_SINE)
		rotation_tween.tween_property(shape_sprite, "rotation", -PI/12, 5.0).set_trans(Tween.TRANS_SINE)
	
	# For circle shapes, add a pulsing effect
	if shape_type == ShapeType.CIRCLE:
		var pulse_tween = create_tween()
		pulse_tween.set_loops()
		pulse_tween.tween_property(shape_sprite, "scale", Vector2(1.09/scale_factor, 1.09/scale_factor), 2.0).set_trans(Tween.TRANS_SINE)
		pulse_tween.tween_property(shape_sprite, "scale", Vector2(1.0/scale_factor, 1.0/scale_factor), 2.0).set_trans(Tween.TRANS_SINE)

func draw_circle_shape(image: Image, center: Vector2, fill_color: Color, scale_factor: int, is_glow: bool = false):
	var radius_scaled = radius * scale_factor
	var aa_width = 3.0 * scale_factor  # Wider anti-aliasing for ultra-soft edges
	
	# More efficient approach with pre-calculated values
	var width = image.get_width()
	var height = image.get_height()
	var outer_radius_squared = (radius_scaled + aa_width) * (radius_scaled + aa_width)
	
	for x in range(width):
		for y in range(height):
			var dx = x - center.x
			var dy = y - center.y
			var dist_squared = dx * dx + dy * dy
			
			if dist_squared <= outer_radius_squared:
				var dist = sqrt(dist_squared)
				var alpha = 1.0
				
				if dist > radius_scaled:
					alpha = max(0.0, 1.0 - (dist - radius_scaled) / aa_width)
				
				# Enhanced gradient with better lighting and warmer tones
				var pixel_color = fill_color
				
				# Create a more dynamic gradient with highlight and shadow
				var angle = atan2(dy, dx)
				var highlight_direction = 0.7  # Highlight from top-right
				var highlight_factor = (cos(angle - highlight_direction) + 1) * 0.5
				
				if dist < radius_scaled * 0.95:
					var inner_gradient = 1.0 - (dist / (radius_scaled * 0.95))
					pixel_color = fill_color.lightened(0.5 * inner_gradient * highlight_factor)
				else:
					pixel_color = fill_color.darkened(0.15 * (1.0 - highlight_factor))
				
				# Add a subtle warm tint
				pixel_color.r = min(1.0, pixel_color.r * 1.15)
				pixel_color.g = min(1.0, pixel_color.g * 1.07)
				
				pixel_color.a *= alpha
				image.set_pixel(x, y, pixel_color)

func draw_triangle_shape(image: Image, center: Vector2, fill_color: Color, scale_factor: int, is_glow: bool = false):
	var side_length = radius * 2 * scale_factor
	var aa_width = 3.0 * scale_factor  # Wider anti-aliasing for ultra-soft edges
	var corner_radius = side_length * 0.25  # Increased rounded corners for cozier look
	
	var width = image.get_width()
	var height = image.get_height()
	
	# Define triangle points with very rounded corners
	var top = Vector2(center.x, center.y - side_length / 1.9)  # Move top point down for a friendlier look
	var left = Vector2(center.x - side_length / 2, center.y + side_length / 3.5)
	var right = Vector2(center.x + side_length / 2, center.y + side_length / 3.5)
	
	for x in range(width):
		for y in range(height):
			var point = Vector2(x, y)
			
			# Inside triangle check using barycentric coordinates
			var a = top
			var b = left
			var c = right
			
			var v0 = c - a
			var v1 = b - a
			var v2 = point - a
			
			var dot00 = v0.dot(v0)
			var dot01 = v0.dot(v1)
			var dot02 = v0.dot(v2)
			var dot11 = v1.dot(v1)
			var dot12 = v1.dot(v2)
			
			var invDenom = 1.0 / (dot00 * dot11 - dot01 * dot01)
			var u = (dot11 * dot02 - dot01 * dot12) * invDenom
			var v = (dot00 * dot12 - dot01 * dot02) * invDenom
			
			var inside_triangle = (u >= 0) && (v >= 0) && (u + v <= 1)
			
			# Check distance to each edge for antialiasing and rounded corners
			var edge_dist = 999999.0
			
			# Get minimum distance to any edge
			edge_dist = min(edge_dist, dist_point_to_line(point, top, left))
			edge_dist = min(edge_dist, dist_point_to_line(point, left, right))
			edge_dist = min(edge_dist, dist_point_to_line(point, right, top))
			
			# Handle rounded corners
			var corner_dist = 999999.0
			corner_dist = min(corner_dist, point.distance_to(top))
			corner_dist = min(corner_dist, point.distance_to(left))
			corner_dist = min(corner_dist, point.distance_to(right))
			
			var alpha = 1.0
			
			if inside_triangle:
				if corner_dist < corner_radius:
					# Inside rounded corner, full opacity
					alpha = 1.0
				elif edge_dist < aa_width:
					# Inside but near edge, antialiasing
					alpha = max(0.0, edge_dist / aa_width)
			else:
				if edge_dist < aa_width:
					# Outside but near edge, antialiasing
					alpha = max(0.0, 1.0 - edge_dist / aa_width)
				else:
					alpha = 0.0
			
			if alpha > 0:
				# Enhanced gradient with better lighting
				var pixel_color = fill_color
				
				# Calculate position within triangle for gradient effects
				var height_pos = 1.0 - (y - top.y) / (left.y - top.y)
				height_pos = clamp(height_pos, 0.0, 1.0)
				
				# Add more depth with lighting
				var center_dist = point.distance_to(center)
				var center_factor = 1.0 - min(1.0, center_dist / (side_length * 0.4))
				
				if center_factor > 0.2:
					pixel_color = fill_color.lightened(0.4 * center_factor)
				else:
					# Slight darkening at edges
					pixel_color = fill_color.darkened(0.1 * (1.0 - height_pos))
				
				# Add warm tint
				pixel_color.r = min(1.0, pixel_color.r * 1.15)
				pixel_color.g = min(1.0, pixel_color.g * 1.07)
				
				pixel_color.a = alpha
				image.set_pixel(x, y, pixel_color)

# Helper function to get distance from point to line segment
func dist_point_to_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var ap = p - a
	var proj = ap.dot(ab) / ab.length_squared()
	proj = clamp(proj, 0.0, 1.0)
	var closest = a + ab * proj
	return p.distance_to(closest)

func draw_square_shape(image: Image, center: Vector2, fill_color: Color, scale_factor: int, is_glow: bool = false):
	var side_length = radius * 2 * scale_factor
	var corner_radius = side_length * 0.4  # Increased corner radius for extra cozy round square
	var aa_width = 4.0 * scale_factor  # Wider anti-aliasing for ultra-soft edges
	
	var width = image.get_width()
	var height = image.get_height()
	var rect_min_x = center.x - side_length / 2
	var rect_min_y = center.y - side_length / 2
	var rect_max_x = center.x + side_length / 2
	var rect_max_y = center.y + side_length / 2
	
	for x in range(width):
		for y in range(height):
			# Adjust for rounded corners
			var dx = 0
			var dy = 0
			var corner_x = 0
			var corner_y = 0
			var in_corner = false
			
			# Determine if point is in corner region
			if x < rect_min_x + corner_radius:
				corner_x = rect_min_x + corner_radius
				if y < rect_min_y + corner_radius:
					corner_y = rect_min_y + corner_radius
					in_corner = true
				elif y > rect_max_y - corner_radius:
					corner_y = rect_max_y - corner_radius
					in_corner = true
			elif x > rect_max_x - corner_radius:
				corner_x = rect_max_x - corner_radius
				if y < rect_min_y + corner_radius:
					corner_y = rect_min_y + corner_radius
					in_corner = true
				elif y > rect_max_y - corner_radius:
					corner_y = rect_max_y - corner_radius
					in_corner = true
			
			var inside = false
			var dist = 0.0
			
			if in_corner:
				dx = x - corner_x
				dy = y - corner_y
				dist = sqrt(dx * dx + dy * dy)
				inside = dist <= corner_radius
			else:
				inside = x >= rect_min_x and x <= rect_max_x and y >= rect_min_y and y <= rect_max_y
			
			var alpha = 1.0
			if in_corner:
				if dist > corner_radius:
					alpha = 0.0
				elif dist > corner_radius - aa_width:
					alpha = max(0.0, 1.0 - (dist - (corner_radius - aa_width)) / aa_width)
			else:
				if !inside:
					# Handle antialiasing for straight edges
					if x >= rect_min_x - aa_width and x <= rect_max_x + aa_width and y >= rect_min_y - aa_width and y <= rect_max_y + aa_width:
						var edge_dist = min(
							min(abs(x - rect_min_x), abs(x - rect_max_x)),
							min(abs(y - rect_min_y), abs(y - rect_max_y))
						)
						alpha = max(0.0, 1.0 - edge_dist / aa_width)
					else:
						alpha = 0.0
			
			if alpha > 0:
				# Enhanced gradient with better lighting
				var pixel_color = fill_color
				
				# Calculate position within square for gradient effects
				var rel_x = float(x - rect_min_x) / side_length
				var rel_y = float(y - rect_min_y) / side_length
				
				# Create softer gradient from corner to corner
				var highlight_factor = (rel_x + rel_y) / 2.0
				
				# Inner lighter area for a plush appearance
				var center_dist = sqrt(pow(x - center.x, 2) + pow(y - center.y, 2))
				var center_factor = 1.0 - min(1.0, center_dist / (side_length * 0.4))
				
				if center_factor > 0.3:
					pixel_color = fill_color.lightened(0.45 * center_factor)
				else:
					pixel_color = fill_color.darkened(0.12 * (1.0 - highlight_factor))
				
				# Add warm tint
				pixel_color.r = min(1.0, pixel_color.r * 1.18)
				pixel_color.g = min(1.0, pixel_color.g * 1.09)
				
				pixel_color.a = alpha
				image.set_pixel(x, y, pixel_color)

func is_point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 = c - a
	var v1 = b - a
	var v2 = p - a
	
	var den = v0.x * v1.y - v1.x * v0.y
	if den == 0:
		return false
		
	var u = (v2.x * v1.y - v1.x * v2.y) / den
	var v = (v0.x * v2.y - v2.x * v0.y) / den
	
	return u >= 0 and v >= 0 and u + v <= 1

func get_color_from_enum() -> Color:  # Converts ShapeColor enum to Color object
	match color:  # Match against current color
		ShapeColor.RED:
			return Color(0.98, 0.42, 0.35, 1)  # Warmer, softer red
		ShapeColor.BLUE:
			return Color(0.52, 0.68, 0.97, 1)  # Warmer, softer blue
		ShapeColor.GREEN:
			return Color(0.52, 0.90, 0.42, 1)  # Warmer, softer green
		ShapeColor.YELLOW:
			return Color(1.0, 0.9, 0.38, 1)    # Warmer, softer yellow
		ShapeColor.PURPLE:
			return Color(0.88, 0.52, 0.88, 1)   # Warmer, softer purple
		_:  # Default case
			return Color(1.0, 0.92, 0.85, 1)   # Warm white

func connect_signals():
	# Connect the built-in body_entered signal to our custom function
	connect("body_entered", _on_body_entered)
	
	# Also set collision layers and masks properly
	collision_layer = 1  # Layer 1 for all shapes
	if is_enemy:
		collision_mask = 1  # Enemy shapes collide with all shapes
	else:
		collision_mask = 2  # Player shapes only collide with enemies

func _on_body_entered(body):  # Called when this shape collides with another physics body
	# Print debug info
	print("Collision detected between: ", self, " and ", body)
	print("Self is_enemy: ", is_enemy, " - Body is_enemy: ", body.get("is_enemy") if body.has_method("get") else "N/A")
	
	if body is RigidBody2D:  # If the colliding body is a RigidBody2D
		# Player shape hitting enemy
		if not is_attached_to_grid and not is_enemy and body.get("is_enemy") == true:
			print("Player shape hit enemy!")
			if body.has_method("take_damage"):
				body.take_damage()  # Damage the enemy
				play_hit_effect(body.global_position)  # Play hit effect
			
		# Enemy shape hitting player shape on grid
		elif not is_attached_to_grid and not is_enemy:  # If we're not attached to grid and not an enemy
			if has_signal("shape_collided"):
				emit_signal("shape_collided", self, global_position)  # Emit collision signal
			else:
				print("Signal 'shape_collided' not found")
			
		# Enemy taking damage
		elif is_enemy:  # If we're an enemy
			print("Enemy taking damage")
			take_damage()  # Take damage from collision

func play_hit_effect(hit_position):  # Play visual effect when hitting an enemy
	# Create a small explosion particle effect
	var particles = CPUParticles2D.new()
	get_tree().root.add_child(particles)
	particles.position = hit_position
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 0.8
	particles.spread = 180
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 150
	particles.scale_amount_min = 3.0  # Changed from scale_amount
	particles.scale_amount_max = 3.0  # Added to match min value
	particles.color = get_color_from_enum().lightened(0.3)
	
	# Add a flash effect
	var flash = Sprite2D.new()
	get_tree().root.add_child(flash)
	flash.position = hit_position
	
	var flash_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	flash_img.fill(Color(1, 1, 1, 1))
	flash.texture = ImageTexture.create_from_image(flash_img)
	flash.modulate = get_color_from_enum()
	flash.scale = Vector2(0.1, 0.1)
	
	# Play hit sound directly instead of using SoundManager
	play_safe_sound("hit", randf_range(1.1, 1.3))
	
	# Animate the flash and then clean up
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(flash.queue_free)
	
	# Auto-remove the particles after they're done
	var particles_timer = Timer.new()
	particles.add_child(particles_timer)
	particles_timer.wait_time = 1.0
	particles_timer.one_shot = true
	particles_timer.timeout.connect(func(): particles.queue_free())
	particles_timer.start()

# Play a sound effect safely without relying on SoundManager
func play_safe_sound(sound_name: String, pitch_scale: float = 1.0, volume_db: float = -5.0):
	# Try to find the sound file in various locations
	var dirs_to_try = ["res://assets/sounds/", "res://assets/audio/", "res://sounds/"]
	var extensions = [".wav", ".ogg", ".mp3"]
	var sound_stream = null
	
	# Try to load the sound
	for dir in dirs_to_try:
		for ext in extensions:
			var path = dir + sound_name + ext
			if ResourceLoader.exists(path):
				sound_stream = load(path)
				if sound_stream:
					break
		if sound_stream:
			break
	
	# If we found the sound, play it
	if sound_stream:
		var player = AudioStreamPlayer.new()
		get_tree().root.add_child(player)
		player.stream = sound_stream
		player.pitch_scale = pitch_scale
		player.volume_db = volume_db
		player.play()
		
		# Clean up the player when done
		player.finished.connect(player.queue_free)
		
		return player
	
	return null

func take_damage():  # Handles shape taking damage
	health -= 1  # Reduce health by 1
	
	# Flash effect when taking damage but not destroyed
	if health > 0:
		var tween = create_tween()
		tween.tween_property(outline, "modulate", Color(2, 2, 2, 1), 0.1)
		tween.tween_property(outline, "modulate", Color(1, 1, 1, 1), 0.1)
		return
		
	if health <= 0:  # If health is 0 or less
		destroy()  # Destroy the shape
		SignalBus.shapes_popped.emit(1)  # Emit signal that shape was popped
		
func attach_to_grid(pos: Vector2i):  # Attaches shape to a grid position
	is_attached_to_grid = true  # Mark as attached to grid
	grid_position = pos  # Set grid position
	set_deferred("freeze", true)  # Freeze physics body (deferred to avoid physics errors)
	
	# Add a small effect when attaching to grid
	var scale_factor = 3  # Use the same scale factor as in create_shape_visual
	var tween = create_tween()
	tween.tween_property(outline, "scale", Vector2(1.2 / scale_factor, 1.2 / scale_factor), 0.1)
	tween.tween_property(outline, "scale", Vector2(1.0 / scale_factor, 1.0 / scale_factor), 0.1)
	
func get_neighbors() -> Array:  # Gets neighboring shapes on grid
	return []  # Currently returns empty array, would be implemented in child classes

func destroy():
	# Create destruction effect
	create_destroy_effect()
	
	# Detach from grid
	is_attached_to_grid = false
	grid_position = Vector2i(-1, -1)
	
	# Queue for deletion
	queue_free()

func create_destroy_effect():
	# Enhanced destruction particle effect
	var global_pos = global_position
	var effect_color = get_color_from_enum()
	
	# Create a soft light flash
	var flash = ColorRect.new()
	get_tree().root.add_child(flash)
	flash.size = Vector2(radius * 6, radius * 6)
	flash.position = global_pos - Vector2(radius * 3, radius * 3)
	flash.color = Color(1.0, 0.98, 0.95, 0.7)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.4)
	flash_tween.tween_callback(flash.queue_free)
	
	# Main explosion particles
	var particles = CPUParticles2D.new()
	get_tree().root.add_child(particles)
	particles.position = global_pos
	particles.amount = 50 # More particles
	particles.lifetime = 1.2
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.emitting = true
	particles.spread = 180
	particles.gravity = Vector2(0, 70)
	particles.initial_velocity_min = 70
	particles.initial_velocity_max = 160
	particles.scale_amount_min = 3.5
	particles.scale_amount_max = 8.0
	particles.color = effect_color.lightened(0.25)
	
	# Small sparkle particles
	var sparkles = CPUParticles2D.new()
	get_tree().root.add_child(sparkles)
	sparkles.position = global_pos
	sparkles.amount = 25
	sparkles.lifetime = 1.4
	sparkles.explosiveness = 1.0
	sparkles.one_shot = true
	sparkles.emitting = true
	sparkles.spread = 180
	sparkles.gravity = Vector2(0, 35)
	sparkles.initial_velocity_min = 100
	sparkles.initial_velocity_max = 200
	sparkles.scale_amount_min = 2.0
	sparkles.scale_amount_max = 4.0
	sparkles.color = Color(1.0, 0.98, 0.9, 0.8)
	
	# Add some heart-shaped particles for extra cuteness!
	var heart_particles = CPUParticles2D.new()
	get_tree().root.add_child(heart_particles)
	heart_particles.position = global_pos
	heart_particles.amount = 8
	heart_particles.lifetime = 1.8
	heart_particles.explosiveness = 0.9
	heart_particles.one_shot = true
	heart_particles.emitting = true
	heart_particles.spread = 180
	heart_particles.gravity = Vector2(0, 25)
	heart_particles.initial_velocity_min = 45
	heart_particles.initial_velocity_max = 90
	heart_particles.scale_amount_min = 5.0
	heart_particles.scale_amount_max = 9.0
	heart_particles.color = Color(1.0, 0.5, 0.6, 0.8) # Pink hearts
	
	# Create heart texture (simplified)
	var heart_texture = create_heart_texture()
	if heart_texture != null:
		heart_particles.texture = heart_texture
	
	# Expanding ring effect
	var ring = Sprite2D.new()
	get_tree().root.add_child(ring)
	ring.position = global_pos
	
	# Create soft blurred ring
	var ring_img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	ring_img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(64, 64)
	var ring_radius = 60
	var ring_width = 10
	
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist > ring_radius - ring_width && dist < ring_radius + ring_width:
				var alpha = 1.0 - abs(dist - ring_radius) / ring_width
				var color = effect_color.lightened(0.4)
				color.a = alpha * 0.8
				ring_img.set_pixel(x, y, color)
	
	ring.texture = ImageTexture.create_from_image(ring_img)
	ring.scale = Vector2(0.5, 0.5)
	
	# Animate ring
	var ring_tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(3.5, 3.5), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.8)
	ring_tween.tween_callback(ring.queue_free)
	
	# Add star burst
	var star_burst = Sprite2D.new()
	get_tree().root.add_child(star_burst)
	star_burst.position = global_pos
	
	# Create star burst texture
	var star_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	star_img.fill(Color(0, 0, 0, 0))
	
	var star_center = Vector2(32, 32)
	var ray_count = 8
	
	for ray in range(ray_count):
		var angle = ray * 2 * PI / ray_count
		var direction = Vector2(cos(angle), sin(angle))
		var ray_length = 25.0
		
		for step in range(int(ray_length)):
			var pos = star_center + direction * step
			if pos.x >= 0 and pos.x < 64 and pos.y >= 0 and pos.y < 64:
				var alpha = 1.0 - step / ray_length
				star_img.set_pixel(int(pos.x), int(pos.y), Color(1.0, 0.95, 0.7, alpha * 0.6))
	
	star_burst.texture = ImageTexture.create_from_image(star_img)
	star_burst.scale = Vector2(0.1, 0.1)
	
	var star_tween = create_tween()
	star_tween.tween_property(star_burst, "scale", Vector2(2.5, 2.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	star_tween.parallel().tween_property(star_burst, "modulate:a", 0.0, 0.5).set_delay(0.2)
	star_tween.tween_callback(star_burst.queue_free)
	
	# Clean up particles
	var timer = Timer.new()
	particles.add_child(timer)
	timer.wait_time = 1.8
	timer.one_shot = true
	timer.timeout.connect(func(): 
		particles.queue_free()
		sparkles.queue_free()
		heart_particles.queue_free()
	)
	timer.start()

func create_heart_texture() -> Texture2D:
	# Create a simple heart shape texture
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center_x = 16
	var center_y = 20
	
	for x in range(32):
		for y in range(32):
			var px = float(x - center_x) / 16
			var py = float(y - center_y) / 16
			
			# Heart shape formula - simplified
			var inside_heart = pow(px, 2) + pow(py - 0.5 * sqrt(abs(px)), 2) < 0.6
			
			if inside_heart:
				var dist_from_center = Vector2(px, py).length()
				var brightness = 1.0 - min(1.0, dist_from_center * 0.8)
				img.set_pixel(x, y, Color(1, 0.5, 0.6, brightness))
	
	return ImageTexture.create_from_image(img)

func preload_sounds():
	# Try to find sound files in common locations
	var sounds_dir = "res://assets/sounds/"
	var sounds_dir2 = "res://assets/audio/"
	var sounds_dir3 = "res://sounds/"
	
	# No need to do anything here, just making the preloads available
