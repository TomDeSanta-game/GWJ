extends RigidBody2D

signal bounced

enum ShapeType { SQUARE, CIRCLE, TRIANGLE }
enum ShapeColor { RED, BLUE, GREEN, YELLOW, PURPLE, ORANGE }

var shape_type: ShapeType = ShapeType.SQUARE
var color: ShapeColor = ShapeColor.RED
var launched: bool = false
var is_enemy: bool = false
var cluster_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 80.0
var health: int = 1
var rotation_speed: float = 0.0

var has_launched: bool = false
var in_grid: bool = false

func _ready():
	initialize_shape()
	
	if is_enemy:
		add_to_group("enemies")
		add_to_group("Enemies")
		rotation_speed = randf_range(-2.0, 2.0)
	else:
		add_to_group("shapes")
		
	contact_monitor = true
	max_contacts_reported = 20
	
	if is_in_group("launcher_shapes"):
		call_deferred("check_for_overlapping_shapes")
		
	# Ensure default physics properties
	freeze = true
	can_sleep = false

func check_for_overlapping_shapes():
	await get_tree().process_frame
	
	if is_queued_for_deletion():
		return
	
	var launcher_shapes = get_tree().get_nodes_in_group("launcher_shapes")
	if launcher_shapes.size() > 1:
		launcher_shapes.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
		
		if self != launcher_shapes[0]:
			queue_free()
			return

func _process(delta):
	if is_enemy and not launched:
		move_towards_target(delta)
		check_player_collision()
		
		if rotation_speed != 0:
			rotation += rotation_speed * delta
	
	if launched and not is_enemy:
		check_direct_collisions()
		
		if linear_velocity.length() < 10:
			linear_velocity = Vector2.ZERO
		else:
			linear_velocity = linear_velocity.lerp(Vector2.ZERO, delta * 0.1)
		
		# Ensure proper physics properties when launched
		if has_launched and freeze:
			freeze = false
			gravity_scale = 0.3
			linear_damp = 0.0
			angular_damp = 0.5

func initialize_shape():
	var collision_shape = CollisionShape2D.new()
	var size = 40
	
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.5
	physics_material.friction = 0.2
	
	self.physics_material_override = physics_material
	self.gravity_scale = 0.0
	self.linear_damp = 0.0
	self.angular_damp = 0.1
	self.freeze = true
	self.can_sleep = false
	
	if is_enemy:
		self.collision_layer = 2
		self.collision_mask = 1
	else:
		self.collision_layer = 1
		self.collision_mask = 2
	
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	body_entered.connect(_on_body_entered)
	
	match shape_type:
		ShapeType.SQUARE:
			var rectangle = RectangleShape2D.new()
			rectangle.size = Vector2(size, size)
			collision_shape.shape = rectangle
		ShapeType.CIRCLE:
			var circle = CircleShape2D.new()
			circle.radius = size / 2.0
			collision_shape.shape = circle
		ShapeType.TRIANGLE:
			var triangle = ConvexPolygonShape2D.new()
			var points = PackedVector2Array([
				Vector2(0, -size / 2.0),
				Vector2(-size / 2.0, size / 2.0),
				Vector2(size / 2.0, size / 2.0)
			])
			triangle.points = points
			collision_shape.shape = triangle
	
	add_child(collision_shape)
	create_pixel_art_shape()
	
func create_pixel_art_shape():
	var existing_visual = get_node_or_null("ShapeVisual")
	if existing_visual:
		existing_visual.queue_free()
	
	var visual = Node2D.new()
	visual.name = "ShapeVisual"
	add_child(visual)
	
	var color_value: Color
	match color:
		ShapeColor.RED:
			color_value = Color(0.9, 0.2, 0.2)
		ShapeColor.BLUE:
			color_value = Color(0.2, 0.4, 0.9)
		ShapeColor.GREEN:
			color_value = Color(0.2, 0.8, 0.3)
		ShapeColor.YELLOW:
			color_value = Color(0.9, 0.8, 0.2)
		ShapeColor.PURPLE:
			color_value = Color(0.7, 0.3, 0.8)
		ShapeColor.ORANGE:
			color_value = Color(0.9, 0.5, 0.2)
	
	var sprite = Sprite2D.new()
	var texture_size = 32
	var img = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	match shape_type:
		ShapeType.SQUARE:
			draw_pixel_square(img, texture_size, color_value)
		ShapeType.CIRCLE:
			draw_pixel_circle(img, texture_size, color_value)
		ShapeType.TRIANGLE:
			draw_pixel_triangle(img, texture_size, color_value)
	
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2(3.0, 3.0)
	visual.add_child(sprite)

func draw_pixel_square(img: Image, size_px: int, color_value: Color):
	var border_size = 1
	var _inner_size = size_px - 2 * border_size
	
	var border_color = color_value.darkened(0.3)
	for x in range(size_px):
		for y in range(size_px):
			if x < border_size or x >= size_px - border_size or y < border_size or y >= size_px - border_size:
				img.set_pixel(x, y, border_color)
	
	for x in range(border_size, size_px - border_size):
		for y in range(border_size, size_px - border_size):
			var highlight = 0.0
			if (x == border_size or x == border_size + 1) and (y == border_size or y == border_size + 1):
				highlight = 0.2
			
			var pixel_color = color_value.lightened(highlight)
			img.set_pixel(x, y, pixel_color)

func draw_pixel_circle(img: Image, size_px: int, color_value: Color):
	var center = Vector2(size_px / 2.0, size_px / 2.0)
	var radius = size_px / 2.0 - 1
	var border_radius = radius + 0.5
	
	for x in range(size_px):
		for y in range(size_px):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist <= border_radius and dist > radius:
				img.set_pixel(x, y, color_value.darkened(0.3))
			elif dist <= radius:
				var highlight = 0.0
				if x < center.x and y < center.y and dist < radius - 2:
					highlight = 0.2
				
				img.set_pixel(x, y, color_value.lightened(highlight))

func draw_pixel_triangle(img: Image, size_px: int, color_value: Color):
	var border_color = color_value.darkened(0.3)
	var center_x = size_px / 2.0
	var top_y = 2
	var bottom_y = size_px - 2
	
	for y in range(top_y, bottom_y + 1):
		var progress = float(y - top_y) / float(bottom_y - top_y)
		var width = (size_px - 4) * progress
		var start_x = center_x - width / 2
		var end_x = center_x + width / 2
		
		for x in range(size_px):
			if x >= start_x - 0.5 and x <= end_x + 0.5:
				if (x == start_x or x == end_x or y == bottom_y):
					img.set_pixel(x, y, border_color)
				else:
					var highlight = 0.0
					if y < center_x and x > center_x - 2 and x < center_x + 2:
						highlight = 0.2
					
					img.set_pixel(x, y, color_value.lightened(highlight))

func _on_body_entered(body):
	if not is_instance_valid(body):
		return
		
	var body_is_enemy = body.get("is_enemy")
	
	if launched and not is_enemy and body_is_enemy:
		body.create_pixel_explosion()
		body.queue_free()
		SignalBus.emit_shapes_popped(1)
		SignalBus.emit_enemy_destroyed(body)
	
	elif is_enemy and not body_is_enemy and body.get("launched"):
		create_pixel_explosion()
		queue_free()
		SignalBus.emit_shapes_popped(1)
		SignalBus.emit_enemy_destroyed(self)

func check_direct_collisions():
	var bodies = get_colliding_bodies()
	for body in bodies:
		if not is_instance_valid(body):
			continue
			
		var body_is_enemy = body.get("is_enemy")
		
		if not is_enemy and body_is_enemy:
			body.create_pixel_explosion()
			body.queue_free()
			SignalBus.emit_shapes_popped(1)
			SignalBus.emit_enemy_destroyed(body)

func set_launched(value: bool = true):
	if value:
		launched = true
		has_launched = true
		freeze = false
		gravity_scale = 0.3
		linear_damp = 0.0
		angular_damp = 0.5
		contact_monitor = true
		max_contacts_reported = 10
		lock_rotation = false
		process_mode = Node.PROCESS_MODE_ALWAYS
		
		var collision_shape = get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = false
			
		if not is_in_group("launched_shapes"):
			add_to_group("launched_shapes")
			
		SignalBus.emit_shape_launched(self)

func take_damage():
	health -= 1
	if health <= 0:
		queue_free()
	else:
		flash_damage()

func flash_damage():
	modulate = Color(1.5, 1.5, 1.5, 1)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)

func move_towards_target(delta: float):
	var direction = (target_position - global_position).normalized()
	global_position += direction * move_speed * delta
	
	if global_position.y > 700:
		var game_controller = get_tree().current_scene
		if game_controller and game_controller.has_method("check_enemies_reached_bottom"):
			game_controller.check_enemies_reached_bottom()

func check_player_collision():
	if not is_enemy:
		return
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		query.set_shape(collision_shape.shape)
		query.transform = collision_shape.global_transform
		query.collision_mask = 1
		
		var results = space_state.intersect_shape(query)
		for result in results:
			var collider = result.collider
			if is_instance_valid(collider) and not collider.is_enemy and collider.launched:
				create_pixel_explosion()
				queue_free()
				SignalBus.emit_shapes_popped(1)
				SignalBus.emit_enemy_destroyed(self)
				return

func create_pixel_explosion():
	var visual = get_node_or_null("ShapeVisual")
	if not visual:
		queue_free()
		return
		
	var sprite = visual.get_child(0) if visual.get_child_count() > 0 else null
	if not sprite or not sprite is Sprite2D:
		queue_free()
		return
	
	var shape_color = get_shape_color()
	var duration = 0.8
	var _explosion_power = 150.0
	var num_pixels = 10
	var min_size = 8
	var max_size = 12
	
	visual.visible = false
	
	var parent = get_parent()
	if not parent:
		queue_free()
		return
		
	var particles_parent = Node2D.new()
	particles_parent.name = "ExplosionParticles"
	particles_parent.global_position = global_position
	parent.add_child(particles_parent)
	
	for i in range(num_pixels):
		var pixel_size = randf_range(min_size, max_size)
		
		var pixel = ColorRect.new()
		pixel.size = Vector2(pixel_size, pixel_size)
		
		var pixel_color = shape_color
		pixel_color = pixel_color.lightened(randf_range(-0.2, 0.2))
		pixel.color = pixel_color
		
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		pixel.position = offset - pixel.size/2
		
		var angle = randf_range(0, TAU)
		var distance = randf_range(20, 80)
		var target_pos = Vector2(cos(angle), sin(angle)) * distance
		
		particles_parent.add_child(pixel)
		
		var tween = particles_parent.create_tween()
		tween.set_parallel(true)
		tween.tween_property(pixel, "position", target_pos, duration)
		tween.tween_property(pixel, "rotation", randf_range(-PI, PI), duration)
		tween.tween_property(pixel, "color:a", 0.0, duration)
	
	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.position = -flash.size/2
	flash.color = shape_color.lightened(0.5)
	flash.color.a = 0.6
	particles_parent.add_child(flash)
	
	var flash_tween = particles_parent.create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.15)
	
	var weak_flash = weakref(flash)
	flash_tween.tween_callback(func(): 
		var flash_ref = weak_flash.get_ref()
		if flash_ref and is_instance_valid(flash_ref) and not flash_ref.is_queued_for_deletion():
			flash_ref.queue_free()
	)
	
	var self_weak = weakref(self)
	var delete_timer = get_tree().create_timer(0.1)
	delete_timer.timeout.connect(func():
		var self_ref = self_weak.get_ref()
		if self_ref and is_instance_valid(self_ref) and not self_ref.is_queued_for_deletion():
			self_ref.queue_free()
	)
	
	var weak_particles = weakref(particles_parent)
	var cleanup_timer = get_tree().create_timer(duration)
	cleanup_timer.timeout.connect(func(): 
		var particles_ref = weak_particles.get_ref()
		if particles_ref and is_instance_valid(particles_ref) and not particles_ref.is_queued_for_deletion():
			particles_ref.queue_free()
	)

func get_shape_color() -> Color:
	match color:
		ShapeColor.RED:
			return Color(0.9, 0.2, 0.2)
		ShapeColor.BLUE:
			return Color(0.2, 0.4, 0.9)
		ShapeColor.GREEN:
			return Color(0.2, 0.8, 0.3)
		ShapeColor.YELLOW:
			return Color(0.9, 0.8, 0.2)
		ShapeColor.PURPLE:
			return Color(0.7, 0.3, 0.8)
		ShapeColor.ORANGE:
			return Color(0.9, 0.5, 0.2)
	return Color(1, 1, 1)

func set_rotation_speed(speed: float):
	rotation_speed = speed
