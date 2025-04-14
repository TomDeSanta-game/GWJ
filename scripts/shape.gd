extends RigidBody2D
class_name Shape

signal shape_popped(size, position)

enum ShapeColor { RED, BLUE, GREEN, YELLOW, PURPLE, ORANGE, WHITE }
enum ShapeType { CIRCLE, TRIANGLE, SQUARE }

var color: ShapeColor
var shape_type: ShapeType
var radius: float = 48.0
var is_enemy: bool = false
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 80.0
var health: int = 1
var has_launched: bool = false
var destroyed: bool = false
var match_checking: bool = false
var rotation_speed: float = 0.0
var rotation_direction: float = 1.0
var rotation_tween: Tween = null
var wobble_amplitude: float = 0.0
var base_scale: Vector2 = Vector2(1, 1)
var is_floating: bool = false
var cluster_position: Vector2 = Vector2.ZERO
var separation_force: float = 150.0
var min_separation_distance: float = 120.0
var viewport_rect: Rect2

var outline: Node2D

static var cached_textures = {}
static var cached_gradients = {}
static var cached_curves = {}

func _ready():
	initialize_shape()
	connect_signals()
	
	rotation_speed = randf_range(3.0, 6.0)
	rotation_direction = 1.0 if randf() > 0.5 else -1.0
	wobble_amplitude = randf_range(0.1, 0.2)
	base_scale = scale
	
	is_floating = true
	if !is_enemy:
		if has_node("ShapeVisual"):
			outline = get_node("ShapeVisual")
			outline.scale = base_scale * (1.0 + wobble_amplitude)
	
	contact_monitor = true
	max_contacts_reported = 8
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	
	viewport_rect = get_viewport_rect()

func _process(delta: float):
	if Engine.time_scale == 0:
		return
		
	if has_launched:
		apply_resistance()
		
		if !is_enemy and has_launched:
			var buffer = 100
			if position.x < viewport_rect.position.x - buffer or \
			   position.x > viewport_rect.size.x + buffer or \
			   position.y < viewport_rect.position.y - buffer or \
			   position.y > viewport_rect.size.y + buffer:
				queue_free()
	
	if is_enemy and !has_launched:
		move_towards_target(delta)
		check_shape_contact()
	
	if outline != null:
		if has_launched || is_enemy:
			outline.rotation += rotation_speed * rotation_direction * delta
		else:
			outline.rotation = 0.0

func _physics_process(_delta: float):
	if destroyed:
		return
		
	if !is_enemy && !freeze && has_launched:
		apply_separation_forces()
		check_direct_collisions()
		apply_resistance()
		check_off_screen()

func move_towards_target(delta: float):
	var direction = (target_position - global_position).normalized()
	global_position += direction * move_speed * delta
	rotation = direction.angle() + PI/2
	
	if global_position.y > 700:
		var game_controller = get_tree().current_scene
		if game_controller:
			game_controller.check_enemies_reached_bottom()

func set_launched():
	has_launched = true
	
	# Make sure we're properly set up for collision detection
	if !is_enemy:
		if not is_in_group("shapes"):
			add_to_group("shapes")
		
		# Force proper collision masks for player shapes
		collision_layer = 1  # Layer 1 = player shapes
		collision_mask = 2   # Layer 2 = enemy shapes
	
	# Make sure the physics body is ready for movement
	freeze = false
	sleeping = false
	gravity_scale = 0.0
	linear_damp = 0.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	# Ensure collision detection is enabled
	contact_monitor = true
	max_contacts_reported = 8
	
	# Make sure the collision shape is enabled
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").disabled = false
	
	# Apply initial impulse if needed
	var min_velocity_threshold = 100.0
	if linear_velocity.length() < min_velocity_threshold:
		var forward_direction = Vector2(0, -1).rotated(rotation)
		# Apply a stronger impulse to ensure movement
		apply_central_impulse(forward_direction * 1500.0)
	
	rotation_speed = rotation_speed * 20.0
	
	if rotation_tween:
		rotation_tween.kill()
		rotation_tween = null
		
	if outline:
		outline.scale = base_scale

func set_random_color():
	color = ShapeColor.values()[randi() % ShapeColor.size()]
	
func set_color(new_color: ShapeColor):
	color = new_color
	
func set_random_shape():
	shape_type = ShapeType.values()[randi() % ShapeType.size()]
	
func set_shape(new_shape: ShapeType):
	shape_type = new_shape
	
func setup_collision():
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	
	collision_shape.disabled = false
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	
	if is_enemy:
		collision_layer = 2
		collision_mask = 1
		
		if not is_in_group("enemies"):
			add_to_group("enemies")
	else:
		if has_launched:
			collision_layer = 1
			collision_mask = 2
			
			if not is_in_group("shapes"):
				add_to_group("shapes")
		else:
			collision_layer = 1
			collision_mask = 0

func connect_signals():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if is_enemy:
		collision_layer = 2
		collision_mask = 1
		if not is_in_group("enemies"):
			add_to_group("enemies")
	else:
		if has_launched:
			collision_layer = 1
			collision_mask = 2
			if not is_in_group("shapes"):
				add_to_group("shapes")
		else:
			collision_layer = 1
			collision_mask = 0

func _on_body_entered(body):
	if destroyed or (is_enemy and body.is_enemy):
		return
	
	if not is_instance_valid(body) or not body is Shape:
		return
	
	if !is_enemy and has_launched and body.is_enemy:
		body.freeze = true
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		
		body.destroy()
		
		SignalBus.emit_signal("shapes_popped", 1)
		SignalBus.emit_signal("enemy_destroyed", body)
		return
		
	if is_enemy and !body.is_enemy and !body.has_launched:
		destroy()
		body.destroy()
		SignalBus.emit_signal("shapes_popped", 1)
		SignalBus.emit_signal("enemy_destroyed", self)
		return

func take_damage():
	health -= 1
	
	if is_enemy:
		destroy()
		SignalBus.emit_shapes_popped(1)
		return
	
	if health > 0:
		var tween = create_tween()
		if tween and outline:
			tween.tween_property(outline, "modulate", Color(1.5, 1.5, 1.5, 1), 0.1)
			tween.tween_property(outline, "modulate", Color(1, 1, 1, 1), 0.1)
		return
		
	if health <= 0:
		destroy()
		SignalBus.emit_shapes_popped(1)

func destroy():
	if destroyed:
		return
	
	destroyed = true
	
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").disabled = true
	
	var visual = get_node_or_null("ShapeVisual")
	if visual:
		var death_tween = create_tween()
		death_tween.set_parallel(true)
		
		death_tween.tween_property(visual, "scale", visual.scale * 1.4, 0.1)
		
		death_tween.chain().set_parallel(true)
		death_tween.tween_property(visual, "modulate", Color(1, 1, 1, 0), 0.3)
		death_tween.tween_property(visual, "rotation", visual.rotation + PI * 1.5 * rotation_direction, 0.3)
		death_tween.tween_property(visual, "scale", visual.scale * 0.1, 0.3)
	
	create_vector_explosion()
	
	await get_tree().create_timer(0.4).timeout
	queue_free()

func create_vector_explosion():
	var explosion_container = Node2D.new()
	explosion_container.name = "VectorExplosion"
	add_child(explosion_container)
	
	var shape_color = get_color_from_enum(color)
	var num_fragments = 10
	var fragment_scale = 0.6
	
	# Create a bunch of vector fragments
	for i in range(num_fragments):
		var fragment = create_explosion_fragment(shape_type, shape_color)
		fragment.position = Vector2.ZERO
		fragment.scale = Vector2(fragment_scale, fragment_scale)
		fragment.rotation = randf_range(0, TAU)
		explosion_container.add_child(fragment)
		
		var direction = Vector2.from_angle(randf_range(0, TAU))
		var distance = randf_range(40, 120)
		var duration = randf_range(0.3, 0.7)
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(fragment, "position", direction * distance, duration)
		tween.tween_property(fragment, "scale", Vector2.ZERO, duration)
		tween.tween_property(fragment, "rotation", fragment.rotation + PI * 2 * (1 if randf() > 0.5 else -1), duration)
		tween.tween_property(fragment, "modulate", Color(shape_color.r, shape_color.g, shape_color.b, 0), duration)
	
	# Add a flash effect
	var flash = create_vector_flash(shape_color)
	explosion_container.add_child(flash)
	
	var flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.2)
	flash_tween.tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.2)

func create_explosion_fragment(shape_type: ShapeType, color: Color) -> Node2D:
	var fragment = Node2D.new()
	fragment.z_index = 5
	
	var draw_script = GDScript.new()
	draw_script.source_code = """
extends Node2D

var shape_type: int
var fragment_color: Color
var size: float = 10.0
var direction: Vector2 = Vector2.RIGHT
var highlight_color: Color

func _ready():
	highlight_color = fragment_color.lightened(0.3)
	highlight_color.a = 0.7

func _draw():
	match shape_type:
		0: # CIRCLE
			draw_circle_fragment()
		1: # TRIANGLE
			draw_triangle_fragment()
		2: # SQUARE
			draw_square_fragment()

func draw_circle_fragment():
	# Simple wedge shape
	var angle_start = randf_range(0, PI)
	var angle_end = angle_start + randf_range(PI/4, PI/2)
	
	var points = []
	points.append(Vector2.ZERO)
	
	var steps = 8
	for i in range(steps + 1):
		var angle = lerp(angle_start, angle_end, float(i) / steps)
		points.append(Vector2(cos(angle), sin(angle)) * size)
	
	# Simply draw a circle if polygons don't work
	if points.size() < 3:
		draw_circle(Vector2.ZERO, size, fragment_color)
	else:
		draw_colored_polygon(points, fragment_color)
	
	# Simple highlight
	draw_circle(Vector2(size * 0.3, -size * 0.3), size * 0.3, highlight_color)

func draw_triangle_fragment():
	# Simple triangle with fixed points to ensure valid triangulation
	var angle = randf_range(0, TAU)
	var point1 = Vector2(cos(angle), sin(angle)) * size
	var point2 = Vector2(cos(angle + 2*PI/3), sin(angle + 2*PI/3)) * size
	
	var points = [Vector2.ZERO, point1, point2]
	
	# Draw the fragment
	draw_colored_polygon(points, fragment_color)
	
	# Add a simple highlight instead of a complex polygon
	draw_circle(Vector2(size * 0.2, -size * 0.2), size * 0.3, highlight_color)

func draw_square_fragment():
	# Create a fixed-shape quadrilateral to avoid triangulation issues
	var angle = randf_range(0, TAU)
	var dist = size * 0.8
	
	# Create a simple rhombus (guaranteed to be triangulable)
	var points = [
		Vector2.ZERO,
		Vector2(cos(angle), sin(angle)) * dist,
		Vector2(cos(angle) + sin(angle), sin(angle) - cos(angle)) * dist * 0.8,
		Vector2(sin(angle), -cos(angle)) * dist
	]
	
	# Ensure all points are different
	var valid_poly = true
	for i in range(points.size()):
		for j in range(i+1, points.size()):
			if points[i].distance_to(points[j]) < 1.0:
				valid_poly = false
				break
	
	if valid_poly:
		draw_colored_polygon(points, fragment_color)
	else:
		# Fallback to a simple circle
		draw_circle(Vector2.ZERO, size * 0.7, fragment_color)
	
	# Simple highlight
	draw_circle(Vector2(size * 0.2, -size * 0.2), size * 0.3, highlight_color)
"""
	
	draw_script.reload()
	fragment.set_script(draw_script)
	fragment.shape_type = shape_type
	fragment.fragment_color = color
	
	return fragment

func create_vector_flash(color: Color) -> Node2D:
	var flash = Node2D.new()
	flash.z_index = 4
	
	var draw_script = GDScript.new()
	draw_script.source_code = """
extends Node2D

var flash_color: Color
var radius: float = 30.0

func _draw():
	var bright_color = flash_color.lightened(0.8)
	bright_color.a = 0.8
	
	# Draw outer glow
	draw_circle(Vector2.ZERO, radius, flash_color)
	
	# Draw inner bright flash
	draw_circle(Vector2.ZERO, radius * 0.7, bright_color)
	
	# Draw center highlight
	var highlight_color = Color(1, 1, 1, 0.9)
	draw_circle(Vector2.ZERO, radius * 0.3, highlight_color)
"""
	
	draw_script.reload()
	flash.set_script(draw_script)
	flash.flash_color = color
	
	return flash

func create_explosion_particles():
	# This legacy function is kept for compatibility but now redirects to the vector explosion
	create_vector_explosion()

func get_particle_scale_curve() -> Curve:
	var curve_key = "particle_scale"
	if cached_curves.has(curve_key):
		return cached_curves[curve_key]
		
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.5, 0.8))
	curve.add_point(Vector2(1, 0))
	
	cached_curves[curve_key] = curve
	return curve

func get_particle_color_ramp() -> Gradient:
	var gradient_key = str(int(color))
	if cached_gradients.has(gradient_key):
		return cached_gradients[gradient_key]
		
	var gradient = Gradient.new()
	var base_color = get_color_from_enum(color)
	var bright_color = base_color.lightened(0.5)
	bright_color.a = 1.0
	var transparent = base_color
	transparent.a = 0
	
	gradient.colors = [bright_color, base_color, transparent]
	gradient.offsets = [0, 0.6, 1.0]
	
	cached_gradients[gradient_key] = gradient
	return gradient

func create_explosion_texture() -> Texture2D:
	var texture_key = "explosion_" + str(int(color))
	if cached_textures.has(texture_key):
		return cached_textures[texture_key]
		
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(16, 16)
	var radius = 14
	
	for x in range(32):
		for y in range(32):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			if distance < radius:
				var alpha = clamp(1.0 - (distance / radius), 0, 1)
				var explosion_color = get_color_from_enum(color)
				explosion_color.a = alpha
				img.set_pixel(x, y, explosion_color)
	
	var texture = ImageTexture.create_from_image(img)
	cached_textures[texture_key] = texture
	return texture

func create_fade_out_gradient() -> Gradient:
	var gradient_key = "fade_out"
	if cached_gradients.has(gradient_key):
		return cached_gradients[gradient_key]
		
	var gradient = Gradient.new()
	gradient.colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	gradient.offsets = [0.7, 1.0]
	
	cached_gradients[gradient_key] = gradient
	return gradient

func create_heart_texture() -> Texture2D:
	var texture_key = "heart"
	if cached_textures.has(texture_key):
		return cached_textures[texture_key]
		
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center_x = 16
	var center_y = 20
	
	for x in range(32):
		for y in range(32):
			var px = float(x - center_x) / 16
			var py = float(y - center_y) / 16
			
			var inside_heart = pow(px, 2) + pow(py - 0.5 * sqrt(abs(px)), 2) < 0.6
			
			if inside_heart:
				var dist_from_center = Vector2(px, py).length()
				var brightness = 1.0 - min(1.0, dist_from_center * 0.8)
				img.set_pixel(x, y, Color(0.8, 0.4, 0.5, brightness))
	
	var texture = ImageTexture.create_from_image(img)
	cached_textures[texture_key] = texture
	return texture

func _draw():
	if not has_node("ShapeVisual"):
		var color_obj = get_color_from_enum(color)
		var shadow_color = color_obj.darkened(0.4)
		var highlight_color = color_obj.lightened(0.1)
		
		match shape_type:
			ShapeType.CIRCLE:
				draw_circle(Vector2.ZERO, radius, color_obj)
			ShapeType.TRIANGLE:
				draw_triangle_shape(radius, color_obj, shadow_color, highlight_color)
			ShapeType.SQUARE:
				draw_square_shape(radius, color_obj, shadow_color, highlight_color)

func create_star_texture() -> Texture2D:
	var texture_key = "star"
	if cached_textures.has(texture_key):
		return cached_textures[texture_key]
		
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(16, 16)
	var outer_radius = 14
	var inner_radius = 5
	var num_points = 5
	
	for x in range(32):
		for y in range(32):
			var pos = Vector2(x, y)
			var angle = pos.angle_to_point(center)
			var distance = pos.distance_to(center)
			var angle_step = 2 * PI / num_points
			var normalized_angle = fmod(angle + PI, angle_step) / angle_step
			var threshold = abs(normalized_angle - 0.5) * 2
			var radius = lerp(inner_radius, outer_radius, threshold)
			
			if distance <= radius:
				var alpha = clamp(1.0 - (distance / radius), 0, 1)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	var texture = ImageTexture.create_from_image(img)
	cached_textures[texture_key] = texture
	return texture

func add_twinkle_particles(parent_node: Node2D) -> void:
	var twinkle_particles = CPUParticles2D.new()
	twinkle_particles.name = "TwinkleParticles"
	twinkle_particles.amount = 6
	twinkle_particles.lifetime = 2.5
	twinkle_particles.explosiveness = 0.0
	twinkle_particles.randomness = 1.0
	twinkle_particles.lifetime_randomness = 0.5
	twinkle_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	twinkle_particles.emission_sphere_radius = 25.0
	twinkle_particles.particle_flag_align_y = false
	twinkle_particles.gravity = Vector2.ZERO
	twinkle_particles.scale_amount_min = 0.8
	twinkle_particles.scale_amount_max = 2.0
	twinkle_particles.color = Color(1, 1, 1, 0.6)
	twinkle_particles.color_ramp = create_twinkle_gradient()
	parent_node.add_child(twinkle_particles)

func create_twinkle_gradient() -> Gradient:
	var gradient_key = "twinkle"
	if cached_gradients.has(gradient_key):
		return cached_gradients[gradient_key]
		
	var gradient = Gradient.new()
	gradient.colors = [Color(0.9, 0.85, 0.8, 0.0), Color(0.9, 0.85, 0.8, 0.5), Color(0.9, 0.85, 0.8, 0.0)]
	gradient.offsets = [0.0, 0.5, 1.0]
	
	cached_gradients[gradient_key] = gradient
	return gradient

func draw_triangle_shape(_radius: float, _color: Color, _shadow_color: Color, _highlight_color: Color):
	pass
	
func draw_square_shape(_radius: float, _color: Color, _shadow_color: Color, _highlight_color: Color):
	pass

func start_floating_animation():
	is_floating = true
	
	if outline == null and has_node("ShapeVisual"):
		outline = get_node("ShapeVisual")
	
	if outline == null:
		return
	
	if rotation_tween:
		rotation_tween.kill()
	
	rotation_tween = create_tween()
	if rotation_tween == null:
		return
	
	if !has_launched && !is_enemy:
		rotation_tween.set_loops(0)
		rotation_tween.tween_property(outline, "scale", base_scale * (1.0 + wobble_amplitude), 1.2)
		rotation_tween.tween_property(outline, "scale", base_scale * (1.0 - wobble_amplitude * 0.5), 1.5)
	else:
		outline.scale = base_scale

func initialize_shape():
	set_random_color()
	set_random_shape()
	setup_collision()
	create_shape_visual()
	
	var visual = get_node_or_null("Visual")
	if visual:
		visual.queue_free()
	
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.0
	physics_material_override.friction = 1.0
	physics_material_override.absorbent = true
	physics_material_override.rough = true
	
	linear_damp = 0.2
	angular_damp = 0.2
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	can_sleep = false
	
	if !is_enemy:
		collision_layer = 1
		collision_mask = 0

func apply_separation_forces():
	if freeze:
		return
		
	var shapes = get_tree().get_nodes_in_group("shapes")
	for other_shape in shapes:
		if other_shape == self or other_shape.is_queued_for_deletion():
			continue
			
		var distance = global_position.distance_to(other_shape.global_position)
		if distance < min_separation_distance and distance > 0:
			var repulsion_vector = (global_position - other_shape.global_position).normalized()
			var force_strength = separation_force * pow(1.0 - distance / min_separation_distance, 3.0)
			apply_central_force(repulsion_vector * force_strength)

func check_direct_collisions():
	if destroyed or !has_launched:
		return
		
	var shapes = get_tree().get_nodes_in_group("shapes") + get_tree().get_nodes_in_group("enemies")
	
	for shape in shapes:
		if shape == self or not is_instance_valid(shape) or shape.destroyed:
			continue
			
		if !is_enemy and !shape.is_enemy:
			continue
			
		if is_enemy and shape.is_enemy:
			continue
			
		var distance = global_position.distance_to(shape.global_position)
		
		if !shape.has_node("CollisionShape2D") or !has_node("CollisionShape2D"):
			continue
			
		var shape_collision = shape.get_node("CollisionShape2D")
		var self_collision = get_node("CollisionShape2D")
		
		if !shape_collision.shape or !self_collision.shape:
			continue
			
		var collision_radius = self_collision.shape.radius if self_collision.shape is CircleShape2D else 30.0
		var other_radius = shape_collision.shape.radius if shape_collision.shape is CircleShape2D else 30.0
		
		var collision_threshold = (collision_radius + other_radius) * 0.95
		
		if distance < collision_threshold:
			if !is_enemy and shape.is_enemy:
				shape.freeze = true
				shape.linear_velocity = Vector2.ZERO
				shape.angular_velocity = 0.0
				
				shape.destroy()
				
				SignalBus.emit_signal("shapes_popped", 1)
				SignalBus.emit_signal("enemy_destroyed", shape)
				
			elif is_enemy and !shape.is_enemy:
				if !shape.has_launched:
					destroy()
					shape.destroy()
					SignalBus.emit_signal("shapes_popped", 1)
					SignalBus.emit_signal("enemy_destroyed", self)
				else:
					destroy()
					SignalBus.emit_signal("shapes_popped", 1)
					SignalBus.emit_signal("enemy_destroyed", self)

func check_off_screen():
	var margin = 100
	if (global_position.x < viewport_rect.position.x - margin || 
		global_position.x > viewport_rect.size.x + margin || 
		global_position.y < viewport_rect.position.y - margin || 
		global_position.y > viewport_rect.size.y + margin):
		queue_free()

func apply_resistance():
	linear_velocity = linear_velocity * 0.99
	if linear_velocity.length() < 5:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		
func get_size():
	return radius

func check_shape_contact():
	if is_enemy:
		var shapes = get_tree().get_nodes_in_group("shapes")
		for other_shape in shapes:
			if other_shape != self and other_shape.is_in_group("shapes") and other_shape.has_launched:
				var distance = global_position.distance_to(other_shape.global_position)
				if distance < 100:
					linear_velocity = Vector2.ZERO
					angular_velocity = 0.0
					freeze = true
					break

func get_color_from_enum(color_enum: int) -> Color:
	var color = Color.WHITE
	match color_enum:
		ShapeColor.RED:
			color = Color(0.75, 0.3, 0.3, 1.0)
		ShapeColor.GREEN:
			color = Color(0.4, 0.65, 0.45, 1.0)
		ShapeColor.BLUE:
			color = Color(0.35, 0.55, 0.75, 1.0)
		ShapeColor.YELLOW:
			color = Color(0.75, 0.7, 0.35, 1.0)
		ShapeColor.PURPLE:
			color = Color(0.65, 0.5, 0.75, 1.0)
		ShapeColor.ORANGE:
			color = Color(0.75, 0.55, 0.35, 1.0)
		ShapeColor.WHITE:
			color = Color(0.9, 0.9, 0.95, 1.0)
	return color

func create_shape_visual():
	if has_node("ShapeVisual"):
		var existing = get_node("ShapeVisual")
		return existing
		
	var shape_visual = Node2D.new()
	shape_visual.name = "ShapeVisual"
	add_child(shape_visual)
	outline = shape_visual
	
	var shape_drawing = Node2D.new()
	shape_drawing.name = "ShapeDrawing"
	shape_visual.add_child(shape_drawing)
	
	var script = GDScript.new()
	script.source_code = """
extends Node2D

enum ShapeType { CIRCLE = 0, TRIANGLE = 1, SQUARE = 2 }

var shape_type: int
var color: Color
var radius: float
var shadow_enabled: bool = false
var outline_color: Color = Color(0.9, 0.6, 0.3, 0.9)
var outline_width: float = 6.0

func _draw():
	var highlight_color = color.lightened(0.1)
	
	if shape_type == ShapeType.CIRCLE:
		draw_circle_shape(radius, color, highlight_color)
	elif shape_type == ShapeType.TRIANGLE:
		draw_triangle_shape(radius, color, highlight_color)
	elif shape_type == ShapeType.SQUARE:
		draw_square_shape(radius, color, highlight_color)
		
func draw_circle_shape(r: float, c: Color, highlight_color: Color):
	draw_circle(Vector2.ZERO, r + outline_width, outline_color)
	draw_circle(Vector2.ZERO, r, c)
	
	var highlight_offset = Vector2.ZERO
	var highlight_radius = r * 0.5
	highlight_color.a = 0.2
	draw_circle(highlight_offset, highlight_radius, highlight_color)

func draw_triangle_shape(r: float, c: Color, highlight_color: Color):
	var points = [
		Vector2(0, -r),
		Vector2(-r * 0.866, r * 0.5),
		Vector2(r * 0.866, r * 0.5)
	]
	
	draw_rounded_polygon(points, Vector2.ZERO, r * 0.15 + outline_width, outline_color, outline_width)
	draw_rounded_polygon(points, Vector2.ZERO, r * 0.15, c)
	
	var highlight_points = []
	var highlight_scale = 0.6
	for point in points:
		highlight_points.append(point * highlight_scale)
	
	highlight_color.a = 0.2
	draw_rounded_polygon(highlight_points, Vector2.ZERO, r * 0.08, highlight_color)

func draw_rounded_polygon(points: Array, offset: Vector2, corner_radius: float, color: Color, _outline_size: float = 0.0):
	if points.size() < 3:
		return
		
	var num_points = points.size()
	
	var base_points = []
	for point in points:
		base_points.append(point + offset)
	draw_polygon(base_points, [color])
	
	for i in range(num_points):
		var point = points[i] + offset
		draw_circle(point, corner_radius, color)
		
	for i in range(num_points):
		var p1 = points[i] + offset
		var p2 = points[(i + 1) % num_points] + offset
		
		var dir = (p2 - p1).normalized()
		var perp = Vector2(-dir.y, dir.x) * corner_radius
		
		var rect_points = [
			p1 + perp,
			p2 + perp,
			p2 - perp,
			p1 - perp
		]
		
		draw_polygon(rect_points, [color])

func draw_square_shape(r: float, c: Color, highlight_color: Color):
	var side_length = r * 1.6
	var corner_radius = side_length * 0.25
	
	draw_rounded_rect(Vector2.ZERO, side_length + outline_width*2, corner_radius + outline_width, outline_color)
	draw_rounded_rect(Vector2.ZERO, side_length, corner_radius, c)
	
	var highlight_scale = 0.7
	var highlight_size = side_length * highlight_scale
	var highlight_corner = highlight_size * 0.25
	var highlight_offset = Vector2.ZERO
	
	highlight_color.a = 0.2
	draw_rounded_rect(highlight_offset, highlight_size, highlight_corner, highlight_color)

func draw_rounded_rect(pos: Vector2, size: float, corner_radius: float, color: Color):
	var half_size = size / 2.0
	var inner_size = half_size - corner_radius
	
	draw_rect(Rect2(pos.x - inner_size, pos.y - half_size, inner_size * 2, size), color)
	draw_rect(Rect2(pos.x - half_size, pos.y - inner_size, size, inner_size * 2), color)
	
	draw_circle(pos + Vector2(-inner_size, -inner_size), corner_radius, color)
	draw_circle(pos + Vector2(inner_size, -inner_size), corner_radius, color)
	draw_circle(pos + Vector2(inner_size, inner_size), corner_radius, color)
	draw_circle(pos + Vector2(-inner_size, inner_size), corner_radius, color)
"""
	
	script.reload()
	shape_drawing.set_script(script)
	
	shape_drawing.shape_type = shape_type
	shape_drawing.color = get_color_from_enum(color)
	shape_drawing.radius = radius
	
	return shape_visual
