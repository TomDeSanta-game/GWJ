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
		
func draw_circle_shape(radius: float, color: Color, shadow_color: Color, highlight_color: Color):
	var shadow_offset = Vector2(radius * 0.05, radius * 0.08)
	draw_circle(shadow_offset, radius * 1.05, shadow_color)
	draw_circle(Vector2.ZERO, radius, color)
	
	var highlight_offset = Vector2(-radius * 0.15, -radius * 0.15)
	var highlight_radius = radius * 0.5
	highlight_color.a = 0.2
	draw_circle(highlight_offset, highlight_radius, highlight_color)

func draw_triangle_shape(radius: float, color: Color, shadow_color: Color, highlight_color: Color):
	var points = [
		Vector2(0, -radius),
		Vector2(-radius * 0.866, radius * 0.5),
		Vector2(radius * 0.866, radius * 0.5)
	]
	
	var shadow_offset = Vector2(radius * 0.05, radius * 0.08)
	var shadow_points = []
	for point in points:
		shadow_points.append(point + shadow_offset)
	
	draw_rounded_polygon(Vector2.ZERO, shadow_points, shadow_color, radius * 0.15)
	draw_rounded_polygon(Vector2.ZERO, points, color, radius * 0.15)
	
	var highlight_points = []
	var highlight_scale = 0.6
	var highlight_offset_dir = Vector2(-radius * 0.08, -radius * 0.08)
	for point in points:
		highlight_points.append(point * highlight_scale + highlight_offset_dir)
	
	highlight_color.a = 0.2
	draw_rounded_polygon(Vector2.ZERO, highlight_points, highlight_color, radius * 0.1)

func draw_rounded_polygon(center: Vector2, points, color, corner_radius):
	if corner_radius <= 0:
		draw_polygon(points, [color])
		return
		
	var point_count = points.size()
	if point_count < 3:
		return
		
	var arc_points = 5
	var all_points = PackedVector2Array()
	
	for i in range(point_count):
		var prev = points[(i - 1 + point_count) % point_count]
		var current = points[i]
		var next = points[(i + 1) % point_count]
		
		var to_prev = (prev - current).normalized()
		var to_next = (next - current).normalized()
		
		var angle_prev = to_prev.angle()
		var angle_next = to_next.angle()
		
		while angle_next < angle_prev:
			angle_next += 2 * PI
			
		var angle_diff = angle_next - angle_prev
		var bisector = (to_prev + to_next).normalized()
		
		if bisector.length() < 0.1:
			bisector = Vector2(to_prev.y, -to_prev.x)
			
		var offset = bisector * corner_radius / cos(angle_diff / 2)
		var corner_center = current + offset
		
		var start_angle = (current - corner_center).angle()
		var end_angle = (next - corner_center).angle()
		
		if end_angle < start_angle:
			end_angle += 2 * PI
			
		for j in range(arc_points + 1):
			var t = float(j) / arc_points
			var angle = start_angle + t * (end_angle - start_angle)
			all_points.append(corner_center + Vector2(cos(angle), sin(angle)) * corner_radius)
	
	draw_polygon(all_points, [color])
		
func draw_square_shape(radius: float, color: Color, shadow_color: Color, highlight_color: Color):
	var side_length = radius * 1.6
	var corner_radius = side_length * 0.2
	var half_side = side_length / 2
	
	var square_points = [
		Vector2(-half_side, -half_side),
		Vector2(half_side, -half_side),
		Vector2(half_side, half_side),
		Vector2(-half_side, half_side)
	]
	
	var shadow_offset = Vector2(radius * 0.05, radius * 0.08)
	var shadow_points = []
	for point in square_points:
		shadow_points.append(point + shadow_offset)
	
	draw_rounded_polygon(Vector2.ZERO, shadow_points, shadow_color, corner_radius)
	draw_rounded_polygon(Vector2.ZERO, square_points, color, corner_radius)
	
	var highlight_scale = 0.7
	var highlight_offset = Vector2(-radius * 0.05, -radius * 0.05)
	var highlight_points = []
	for point in square_points:
		highlight_points.append(point * highlight_scale + highlight_offset)
		
	highlight_color.a = 0.2
	draw_rounded_polygon(Vector2.ZERO, highlight_points, highlight_color, corner_radius * highlight_scale)
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
	var dirs_to_try = ["res:
	var extensions = [".wav", ".ogg", ".mp3"]
	var sound_stream = null
	
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
	create_destroy_effect()
	
	is_attached_to_grid = false
	grid_position = Vector2i(-1, -1)
	
	queue_free()

func create_destroy_effect():
	var global_pos = global_position
	var effect_color = get_color_from_enum(shape_type)
	
	var flash = ColorRect.new()
	get_tree().root.add_child(flash)
	flash.size = Vector2(radius * 6, radius * 6)
	flash.position = global_pos - Vector2(radius * 3, radius * 3)
	flash.color = Color(0.9, 0.85, 0.8, 0.5)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.4)
	flash_tween.tween_callback(flash.queue_free)
	
	var particles = CPUParticles2D.new()
	get_tree().root.add_child(particles)
	particles.position = global_pos
	particles.amount = 40
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.emitting = true
	particles.spread = 180
	particles.gravity = Vector2(0, 60)
	particles.initial_velocity_min = 60
	particles.initial_velocity_max = 120
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.0
	particles.color = effect_color.lightened(0.15)
	
	var sparkles = CPUParticles2D.new()
	get_tree().root.add_child(sparkles)
	sparkles.position = global_pos
	sparkles.amount = 15
	sparkles.lifetime = 1.0
	sparkles.explosiveness = 1.0
	sparkles.one_shot = true
	sparkles.emitting = true
	sparkles.spread = 180
	sparkles.gravity = Vector2(0, 25)
	sparkles.initial_velocity_min = 80
	sparkles.initial_velocity_max = 150
	sparkles.scale_amount_min = 1.5
	sparkles.scale_amount_max = 3.0
	sparkles.color = Color(0.85, 0.8, 0.7, 0.6)
	
	var heart_particles = CPUParticles2D.new()
	get_tree().root.add_child(heart_particles)
	heart_particles.position = global_pos
	heart_particles.amount = 5
	heart_particles.lifetime = 1.2
	heart_particles.explosiveness = 0.9
	heart_particles.one_shot = true
	heart_particles.emitting = true
	heart_particles.spread = 180
	heart_particles.gravity = Vector2(0, 20)
	heart_particles.initial_velocity_min = 35
	heart_particles.initial_velocity_max = 70
	heart_particles.scale_amount_min = 3.0
	heart_particles.scale_amount_max = 6.0
	heart_particles.color = Color(0.8, 0.4, 0.5, 0.6)
	
	var heart_texture = create_heart_texture()
	if heart_texture != null:
		heart_particles.texture = heart_texture
	
	var ring = Sprite2D.new()
	get_tree().root.add_child(ring)
	ring.position = global_pos
	
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
	ring_tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.7)
	ring_tween.tween_callback(ring.queue_free)
	
	var star_burst = Sprite2D.new()
	get_tree().root.add_child(star_burst)
	star_burst.position = global_pos
	
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
				star_img.set_pixel(int(pos.x), int(pos.y), Color(0.9, 0.85, 0.65, alpha * 0.4))
	
	star_burst.texture = ImageTexture.create_from_image(star_img)
	star_burst.scale = Vector2(0.1, 0.1)
	
	var star_tween = create_tween()
	star_tween.tween_property(star_burst, "scale", Vector2(2.0, 2.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	star_tween.parallel().tween_property(star_burst, "modulate:a", 0.0, 0.5).set_delay(0.2)
	star_tween.tween_callback(star_burst.queue_free)
	
	var timer = Timer.new()
	particles.add_child(timer)
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(func(): 
		particles.queue_free()
		sparkles.queue_free()
		heart_particles.queue_free()
	)
	timer.start()

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
	var sounds_dir = "res:
	var sounds_dir2 = "res:
	var sounds_dir3 = "res:

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
