extends RigidBody2D

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

var base_health: int = 1
var damage_flash_time: float = 0.1
var is_flashing: bool = false
var has_collided_with_player: bool = false

var color_values = {
	ShapeColor.RED: Color(0.9, 0.2, 0.2),
	ShapeColor.BLUE: Color(0.2, 0.4, 0.9),
	ShapeColor.GREEN: Color(0.2, 0.8, 0.3),
	ShapeColor.YELLOW: Color(0.9, 0.8, 0.2),
	ShapeColor.PURPLE: Color(0.7, 0.3, 0.8),
	ShapeColor.ORANGE: Color(0.9, 0.5, 0.2)
}

var game_controller = null

var sprite
var collision_shape
var area_2d
var area_collision

func _ready():
	setup_required_nodes()
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
		
	freeze = true
	can_sleep = false

func setup_required_nodes():
	sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	
	area_2d = get_node_or_null("Area2D")
	if not area_2d:
		area_2d = Area2D.new()
		area_2d.name = "Area2D"
		area_2d.collision_layer = 4
		area_2d.collision_mask = 2
		area_2d.body_entered.connect(_on_area_body_entered)
		
		area_collision = area_2d.get_node_or_null("CollisionShape2D")
		if not area_collision:
			area_collision = CollisionShape2D.new()
			area_collision.name = "CollisionShape2D"
			area_2d.add_child(area_collision)
		
		add_child(area_2d)
	else:
		area_collision = area_2d.get_node_or_null("CollisionShape2D")
		if not area_collision:
			area_collision = CollisionShape2D.new()
			area_collision.name = "CollisionShape2D"
			area_2d.add_child(area_collision)

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
	if is_flashing:
		return
	
	is_flashing = true
	if sprite:
		var original_color = sprite.modulate
		sprite.modulate = Color.WHITE
		
		await get_tree().create_timer(damage_flash_time).timeout
		
		if is_instance_valid(self) and sprite:
			sprite.modulate = original_color
	
	is_flashing = false

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
		
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.8
	particles.amount = 32
	particles.speed_scale = 2.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 3.0
	
	var shape_color = color_values[color]
	particles.color = shape_color
	particles.position = Vector2.ZERO
	get_parent().add_child(particles)
	particles.global_position = global_position
	
	health = 0
	queue_free()

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

func _integrate_forces(state):
	if not has_launched:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0

func setup_health():
	match shape_type:
		ShapeType.SQUARE:
			base_health = 3
		ShapeType.CIRCLE:
			base_health = 2
		ShapeType.TRIANGLE:
			base_health = 1
	
	health = base_health

func find_game_controller():
	var potential_paths = [
		"/root/Main/GameController",
		"/root/Main/World/GameController",
		"/root/GameController"
	]
	
	for path in potential_paths:
		var node = get_node_or_null(path)
		if node:
			return node
	
	var parent = get_parent()
	while parent:
		if parent.has_method("on_shape_destroyed"):
			return parent
		parent = parent.get_parent()
	
	return null

func handle_static_collision(body):
	if has_launched and body is StaticBody2D:
		take_damage()

func _on_area_body_entered(body):
	if has_launched and body.is_in_group("player"):
		health = 0
		take_damage()
		if game_controller:
			game_controller.on_shape_hit_player(self)
