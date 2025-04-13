extends RigidBody2D
class_name Shape

enum ShapeColor { RED, BLUE, GREEN, YELLOW, PURPLE, ORANGE }
enum ShapeType { CIRCLE, TRIANGLE, SQUARE }

var color: ShapeColor
var shape_type: ShapeType
var radius: float = 48.0
var is_attached_to_grid: bool = false
var grid_position: Vector2i = Vector2i(-1, -1)
var is_enemy: bool = false
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 80.0
var health: int = 1
var has_launched: bool = false
var destroyed: bool = false
var match_checking: bool = false

var outline: Node2D

static var cached_textures = {}

func _ready():
	initialize_shape()
	preload_sounds()
	connect_signals()
	
func initialize_shape():
	set_random_color()
	set_random_shape()
	setup_collision()
	create_shape_visual()
	
	var visual = get_node_or_null("Visual")
	if visual:
		visual.queue_free()
	
	gravity_scale = 0.0

func _process(delta: float):
	if is_enemy and not is_attached_to_grid:
		move_towards_target(delta)

func move_towards_target(delta: float):
	var direction = (target_position - global_position).normalized()
	global_position += direction * move_speed * delta
	rotation = direction.angle() + PI/2
	
	if global_position.y > 700:
		var game_controller = get_node("/root/Main")
		if game_controller:
			game_controller.check_enemies_reached_bottom()

func set_launched():
	has_launched = true
	
	# Reset physics state to allow movement
	freeze = false
	gravity_scale = 0.0
	linear_damp = -1
	
	# Apply impulse for movement if not already moving
	var min_velocity_threshold = 10.0
	if linear_velocity.length() < min_velocity_threshold:
		# Apply impulse in the forward direction based on rotation
		var forward_direction = Vector2(0, -1).rotated(rotation)
		apply_central_impulse(forward_direction * 300.0)
	
	var trail = get_node_or_null("Trail")
	if trail:
		trail.emitting = true

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
	
	if is_enemy:
		collision_layer = 2
		collision_mask = 1
	else:
		collision_layer = 1
		collision_mask = 2
	
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape

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
var shadow_enabled: bool = true

func _draw():
	var shadow_color = color.darkened(0.4)
	var highlight_color = color.lightened(0.1)
	
	if shape_type == ShapeType.CIRCLE:
		draw_circle_shape(radius, color, shadow_color, highlight_color)
	elif shape_type == ShapeType.TRIANGLE:
		draw_triangle_shape(radius, color, shadow_color, highlight_color)
	elif shape_type == ShapeType.SQUARE:
		draw_square_shape(radius, color, shadow_color, highlight_color)
		
func draw_circle_shape(r: float, c: Color, shadow_color: Color, highlight_color: Color):
	var shadow_offset = Vector2(r * 0.05, r * 0.08)
	draw_circle(shadow_offset, r * 1.05, shadow_color)
	draw_circle(Vector2.ZERO, r, c)
	
	var highlight_offset = Vector2(-r * 0.15, -r * 0.15)
	var highlight_radius = r * 0.5
	highlight_color.a = 0.2
	draw_circle(highlight_offset, highlight_radius, highlight_color)

func draw_triangle_shape(r: float, c: Color, shadow_color: Color, highlight_color: Color):
	var points = [
		Vector2(0, -r),
		Vector2(-r * 0.866, r * 0.5),
		Vector2(r * 0.866, r * 0.5)
	]
	
	var shadow_offset = Vector2(r * 0.05, r * 0.08)
	var shadow_points = []
	for point in points:
		shadow_points.append(point + shadow_offset)
	
	draw_polygon(shadow_points, [shadow_color])
	draw_polygon(points, [c])
	
	var highlight_points = []
	var highlight_scale = 0.6
	var highlight_offset_dir = Vector2(-r * 0.08, -r * 0.08)
	for point in points:
		highlight_points.append(point * highlight_scale + highlight_offset_dir)
	
	highlight_color.a = 0.2
	draw_polygon(highlight_points, [highlight_color])

func draw_square_shape(r: float, c: Color, shadow_color: Color, highlight_color: Color):
	var side_length = r * 1.6
	var corner_radius = side_length * 0.2
	
	# Draw shadow first
	var shadow_offset = Vector2(r * 0.05, r * 0.08)
	draw_rounded_rect(shadow_offset, side_length, corner_radius, shadow_color)
	
	# Draw main shape
	draw_rounded_rect(Vector2.ZERO, side_length, corner_radius, c)
	
	# Draw highlight
	var highlight_scale = 0.7
	var highlight_size = side_length * highlight_scale
	var highlight_corner = highlight_size * 0.2
	var highlight_offset = Vector2(-r * 0.05, -r * 0.05)
	
	highlight_color.a = 0.2
	draw_rounded_rect(highlight_offset, highlight_size, highlight_corner, highlight_color)

# Helper function to draw a rounded rectangle
func draw_rounded_rect(pos: Vector2, size: float, corner_radius: float, color: Color):
	var half_size = size / 2.0
	var inner_size = half_size - corner_radius
	
	# First fill the entire square with a solid rect to prevent holes
	draw_rect(Rect2(pos.x - half_size, pos.y - half_size, size, size), color)
	
	# Draw the four corners
	draw_circle(pos + Vector2(-inner_size, -inner_size), corner_radius, color)  # Top-left
	draw_circle(pos + Vector2(inner_size, -inner_size), corner_radius, color)   # Top-right
	draw_circle(pos + Vector2(inner_size, inner_size), corner_radius, color)    # Bottom-right
	draw_circle(pos + Vector2(-inner_size, inner_size), corner_radius, color)   # Bottom-left
"""
	
	script.reload()
	shape_drawing.set_script(script)
	
	shape_drawing.shape_type = shape_type
	shape_drawing.color = get_color_from_enum(color)
	shape_drawing.radius = radius
	
	add_glow_effect(shape_visual)
	add_cozy_particles(shape_visual)
	
	return shape_visual

func add_cozy_particles(parent_node):
	var particles = CPUParticles2D.new()
	particles.amount = 8
	particles.lifetime = 1.2
	particles.preprocess = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.8
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius * 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 5
	particles.initial_velocity_max = 10
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.5
	var color_obj = get_color_from_enum(color)
	particles.color = color_obj.lightened(0.2)
	particles.color.a = 0.2
	parent_node.add_child(particles)
	
	var twinkle_particles = CPUParticles2D.new()
	twinkle_particles.amount = 3
	twinkle_particles.lifetime = 1.8
	twinkle_particles.preprocess = 1.0
	twinkle_particles.explosiveness = 0.1
	twinkle_particles.randomness = 0.9
	twinkle_particles.local_coords = false
	twinkle_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	twinkle_particles.emission_sphere_radius = radius * 0.6
	twinkle_particles.direction = Vector2(0, 0)
	twinkle_particles.spread = 180
	twinkle_particles.gravity = Vector2.ZERO
	twinkle_particles.initial_velocity_min = 0
	twinkle_particles.initial_velocity_max = 0
	
	twinkle_particles.scale_amount_min = 1.0
	twinkle_particles.scale_amount_max = 1.5
	twinkle_particles.color = Color(0.9, 0.85, 0.7, 0.3)
	parent_node.add_child(twinkle_particles)

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
	return color

func connect_signals():
	connect("body_entered", _on_body_entered)
	
	collision_layer = 1
	if is_enemy:
		collision_mask = 1
	else:
		collision_mask = 2

func _on_body_entered(body):
	print("Collision detected between: ", self, " and ", body)
	print("Self is_enemy: ", is_enemy, " - Body is_enemy: ", body.get("is_enemy") if body.has_method("get") else "N/A")
	
	if body is RigidBody2D:
		if not is_attached_to_grid and not is_enemy and body.get("is_enemy") == true:
			print("Player shape hit enemy!")
			if body.has_method("take_damage"):
				body.take_damage()
				play_hit_effect(body.global_position)
			
		elif not is_attached_to_grid and not is_enemy:
			if has_signal("shape_collided"):
				emit_signal("shape_collided", self, global_position)
			else:
				print("Signal 'shape_collided' not found")
			
		elif is_enemy:
			print("Enemy taking damage")
			take_damage()

func play_hit_effect(hit_position):
	var particles = CPUParticles2D.new()
	get_tree().root.add_child(particles)
	particles.position = hit_position
	particles.amount = 15
	particles.lifetime = 0.4
	particles.explosiveness = 0.8
	particles.spread = 180
	particles.gravity = Vector2(0, 150)
	particles.initial_velocity_min = 40
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 2.0
	particles.color = get_color_from_enum(shape_type).lightened(0.2)
	
	var flash = Sprite2D.new()
	get_tree().root.add_child(flash)
	flash.position = hit_position
	
	var flash_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	flash_img.fill(Color(1, 1, 1, 1))
	flash.texture = ImageTexture.create_from_image(flash_img)
	flash.modulate = get_color_from_enum(shape_type)
	flash.scale = Vector2(0.1, 0.1)
	
	play_safe_sound("hit", randf_range(1.1, 1.3))
	
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(flash.queue_free)
	
	var particles_timer = Timer.new()
	particles.add_child(particles_timer)
	particles_timer.wait_time = 1.0
	particles_timer.one_shot = true
	particles_timer.timeout.connect(func(): particles.queue_free())
	particles_timer.start()

func play_safe_sound(sound_name: String, pitch_scale: float = 1.0, volume_db: float = -5.0):
	var dirs_to_try = ["res://audio/", "res://sounds/"]
	var extensions = [".wav", ".ogg", ".mp3"]
	var sound_stream = null
	
	# Skip trying to play "launch" sound which doesn't exist
	if sound_name == "launch":
		return null
	
	for dir in dirs_to_try:
		for ext in extensions:
			var path = dir + sound_name + ext
			if ResourceLoader.exists(path):
				sound_stream = load(path)
				if sound_stream:
					break
		if sound_stream:
			break
	
	if sound_stream:
		var player = AudioStreamPlayer.new()
		get_tree().root.add_child(player)
		player.stream = sound_stream
		player.pitch_scale = pitch_scale
		player.volume_db = volume_db
		player.play()
		
		player.finished.connect(player.queue_free)
		
		return player
	
	return null

func take_damage():
	health -= 1
	
	if health > 0:
		var tween = create_tween()
		tween.tween_property(outline, "modulate", Color(1.5, 1.5, 1.5, 1), 0.1)
		tween.tween_property(outline, "modulate", Color(1, 1, 1, 1), 0.1)
		return
		
	if health <= 0:
		destroy()
		SignalBus.shapes_popped.emit(1)
		
func attach_to_grid(pos: Vector2i):
	is_attached_to_grid = true
	grid_position = pos
	set_deferred("freeze", true)
	
	var scale_factor = 3
	var tween = create_tween()
	tween.tween_property(outline, "scale", Vector2(1.2 / scale_factor, 1.2 / scale_factor), 0.1)
	tween.tween_property(outline, "scale", Vector2(1.0 / scale_factor, 1.0 / scale_factor), 0.1)
	
func get_neighbors() -> Array:
	return []

func destroy():
	if destroyed:
		return
		
	destroyed = true
	
	match_checking = false
	
	if is_in_group("shapes"):
		remove_from_group("shapes")
	
	freeze = true
	
	if has_node("ShapeVisual"):
		var visual = get_node("ShapeVisual")
		var tween = create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	
	await get_tree().create_timer(0.3).timeout
	
	queue_free()

func create_destroy_effect():
	var global_pos = global_position
	var effect_color = get_color_from_enum(shape_type)
	
	# Create a parent node to manage all effect elements
	var effect_root = Node2D.new()
	effect_root.name = "DestroyEffectRoot"
	effect_root.position = global_pos
	get_tree().root.add_child(effect_root)
	
	# Flash effect
	var flash = ColorRect.new()
	effect_root.add_child(flash)
	flash.size = Vector2(radius * 6, radius * 6)
	flash.position = Vector2(-radius * 3, -radius * 3)
	flash.color = Color(1.0, 1.0, 1.0, 0.7)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color", effect_color.lightened(0.4), 0.1)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.3)
	
	# Main explosion particles
	var particles = CPUParticles2D.new()
	effect_root.add_child(particles)
	particles.z_index = 1
	particles.amount = 45
	particles.lifetime = 0.7
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.emitting = true
	particles.spread = 180
	particles.gravity = Vector2(0, 70)
	particles.initial_velocity_min = 80
	particles.initial_velocity_max = 160
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = effect_color.lightened(0.2)
	particles.color_ramp = create_fade_out_gradient()
	
	# Sparkle particles
	var sparkles = CPUParticles2D.new()
	effect_root.add_child(sparkles)
	sparkles.z_index = 2
	sparkles.amount = 20
	sparkles.lifetime = 0.6
	sparkles.explosiveness = 1.0
	sparkles.one_shot = true
	sparkles.emitting = true
	sparkles.spread = 180
	sparkles.gravity = Vector2(0, 30)
	sparkles.initial_velocity_min = 100
	sparkles.initial_velocity_max = 180
	sparkles.scale_amount_min = 1.5
	sparkles.scale_amount_max = 3.0
	sparkles.color = effect_color.lightened(0.5)
	sparkles.color_ramp = create_fade_out_gradient()
	
	# Heart particles
	var heart_particles = CPUParticles2D.new()
	effect_root.add_child(heart_particles)
	heart_particles.z_index = 3
	heart_particles.amount = 4
	heart_particles.lifetime = 0.8
	heart_particles.explosiveness = 0.9
	heart_particles.one_shot = true
	heart_particles.emitting = true
	heart_particles.spread = 180
	heart_particles.gravity = Vector2(0, 25)
	heart_particles.initial_velocity_min = 40
	heart_particles.initial_velocity_max = 80
	heart_particles.scale_amount_min = 3.0
	heart_particles.scale_amount_max = 4.5
	heart_particles.color = Color(0.9, 0.5, 0.6, 0.8)
	heart_particles.color_ramp = create_fade_out_gradient()
	
	var heart_texture = create_heart_texture()
	if heart_texture != null:
		heart_particles.texture = heart_texture
	
	# Ring effect
	var ring = Sprite2D.new()
	effect_root.add_child(ring)
	ring.z_index = -1
	
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
				var color = effect_color.lightened(0.3)
				color.a = alpha * 0.6
				ring_img.set_pixel(x, y, color)
	
	ring.texture = ImageTexture.create_from_image(ring_img)
	ring.scale = Vector2(0.5, 0.5)
	
	var ring_tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.6)
	
	# Burst circle
	var burst_circle = Sprite2D.new()
	effect_root.add_child(burst_circle)
	burst_circle.z_index = 2
	
	var burst_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	burst_img.fill(Color(0, 0, 0, 0))
	
	var burst_center = Vector2(32, 32)
	var burst_radius = 25
	
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x, y).distance_to(burst_center)
			if dist < burst_radius:
				var alpha = 1.0 - (dist / burst_radius)
				var color = Color(1, 1, 1, alpha * 0.9)
				burst_img.set_pixel(x, y, color)
	
	burst_circle.texture = ImageTexture.create_from_image(burst_img)
	burst_circle.modulate = effect_color.lightened(0.4)
	burst_circle.scale = Vector2(0.1, 0.1)
	
	var burst_tween = create_tween()
	burst_tween.tween_property(burst_circle, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	burst_tween.parallel().tween_property(burst_circle, "modulate:a", 0.0, 0.3)
	
	# Master cleanup timer for the entire effect
	var cleanup_timer = Timer.new()
	effect_root.add_child(cleanup_timer)
	cleanup_timer.wait_time = 1.2  # Slightly longer to ensure all effects complete
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): effect_root.queue_free())
	cleanup_timer.start()

# Helper function to create a gradient for fading out particles
func create_fade_out_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	gradient.offsets = [0.7, 1.0]
	return gradient

func create_heart_texture() -> Texture2D:
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
	
	return ImageTexture.create_from_image(img)

func preload_sounds():
	var _sounds_dir = "res://audio/effects/"
	var _sounds_dir2 = "res://audio/impacts/"
	var _sounds_dir3 = "res://sounds/"

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

func add_glow_effect(parent_node: Node2D) -> void:
	var glow = Sprite2D.new()
	glow.name = "Glow"
	
	var gradient = Gradient.new()
	gradient.colors = [Color(1, 1, 1, 0.1), Color(1, 1, 1, 0)]
	gradient.offsets = [0.7, 1.0]
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256
	gradient_texture.height = 256
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1, 0.5)
	
	glow.texture = gradient_texture
	glow.modulate = Color(1, 1, 1, 0.3)
	glow.scale = Vector2(2.5, 2.5)
	parent_node.add_child(glow)
	
	var inner_glow = Sprite2D.new()
	inner_glow.name = "InnerGlow"
	
	var inner_gradient = Gradient.new()
	inner_gradient.colors = [Color(1, 1, 1, 0.05), Color(1, 1, 1, 0)]
	inner_gradient.offsets = [0, 0.7]
	
	var inner_gradient_texture = GradientTexture2D.new()
	inner_gradient_texture.gradient = inner_gradient
	inner_gradient_texture.width = 128
	inner_gradient_texture.height = 128
	inner_gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	inner_gradient_texture.fill_from = Vector2(0.5, 0.5)
	inner_gradient_texture.fill_to = Vector2(1, 0.5)
	
	inner_glow.texture = inner_gradient_texture
	inner_glow.scale = Vector2(0.5, 0.5)
	parent_node.add_child(inner_glow)

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
	var gradient = Gradient.new()
	gradient.colors = [Color(0.9, 0.85, 0.8, 0.0), Color(0.9, 0.85, 0.8, 0.5), Color(0.9, 0.85, 0.8, 0.0)]
	gradient.offsets = [0.0, 0.5, 1.0]
	return gradient

func draw_triangle_shape(_radius: float, _color: Color, _shadow_color: Color, _highlight_color: Color):
	pass
	
func draw_square_shape(_radius: float, _color: Color, _shadow_color: Color, _highlight_color: Color):
	pass
