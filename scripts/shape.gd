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

var has_launched: bool = false
var in_grid: bool = false

func _ready():
	print("Shape created: ", self, " is_enemy: ", is_enemy)
	initialize_shape()
	
	# Force immediate group assignment
	if is_enemy:
		add_to_group("enemies")
		add_to_group("Enemies")
	else:
		add_to_group("shapes")
		
	# Monitor collisions
	contact_monitor = true
	max_contacts_reported = 20
	
func _process(delta):
	if is_enemy and not launched:
		move_towards_target(delta)
		check_player_collision()
	
	if launched and not is_enemy:
		check_direct_collisions()
		
		if linear_velocity.length() < 10:
			linear_velocity = Vector2.ZERO
		else:
			linear_velocity = linear_velocity.lerp(Vector2.ZERO, delta * 0.1)

func initialize_shape():
	var collision_shape = CollisionShape2D.new()
	var size = 40
	
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.0
	physics_material.friction = 1.0
	
	self.physics_material_override = physics_material
	self.gravity_scale = 0.0
	self.linear_damp = 5.0
	self.angular_damp = 5.0
	
	if is_enemy:
		self.collision_layer = 2  # Layer for enemy shapes
		self.collision_mask = 1   # Collide with player shapes
	else:
		self.collision_layer = 1  # Layer for player shapes
		self.collision_mask = 2   # Collide with enemy shapes
	
	# Reconnect signal to make sure it's not connected multiple times
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
	var inner_size = size_px - 2 * border_size
	
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
		var progress = float(y - top_y) / (bottom_y - top_y)
		var width = int((size_px - 4) * progress)
		var start_x = int(center_x - width / 2.0)
		var end_x = start_x + width
		
		for x in range(start_x, end_x + 1):
			if x == start_x or x == end_x or y == top_y or y == bottom_y - 1:
				img.set_pixel(x, y, border_color)
			else:
				var highlight = 0.0
				if x < center_x and y < size_px / 2:
					highlight = 0.2
				
				img.set_pixel(x, y, color_value.lightened(highlight))

func _on_body_entered(body):
	print("Body entered: ", body, " is enemy: ", is_enemy, " body is enemy: ", body.get("is_enemy") if body else "N/A")
	
	if not is_instance_valid(body):
		return
		
	var body_is_enemy = body.get("is_enemy")
	
	# Player shape hits enemy
	if launched and not is_enemy and body_is_enemy:
		print("Player hit enemy!")
		body.create_pixel_explosion()
		body.queue_free()
		SignalBus.emit_shapes_popped(1)
		SignalBus.emit_enemy_destroyed(body)
	
	# Enemy hits player shape
	elif is_enemy and not body_is_enemy and body.get("launched"):
		print("Enemy hit by player!")
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
		
		# If player shape detects colliding with enemy
		if not is_enemy and body_is_enemy:
			print("Direct collision: player with enemy")
			body.create_pixel_explosion()
			body.queue_free()
			SignalBus.emit_shapes_popped(1)
			SignalBus.emit_enemy_destroyed(body)

func set_launched():
	print("Shape launched: ", self, " is_enemy: ", is_enemy)
	has_launched = true
	launched = true
	
	# Reset physics properties to ensure movement and collision work
	self.freeze = false
	self.sleeping = false
	self.gravity_scale = 0.0
	self.collision_layer = 1  # Layer for player shapes
	self.collision_mask = 2   # Collide with enemy shapes
	self.contact_monitor = true
	self.max_contacts_reported = 20
	
	# Force reactivate collision detection
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.disabled = false

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
	rotation = direction.angle() + PI/2
	
	if global_position.y > 700:
		var game_controller = get_tree().current_scene
		if game_controller and game_controller.has_method("check_enemies_reached_bottom"):
			game_controller.check_enemies_reached_bottom()

func check_player_collision():
	# Extra check specifically for enemy shapes
	if not is_enemy:
		return
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	# Get the shape from our collision shape
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		query.set_shape(collision_shape.shape)
		query.transform = collision_shape.global_transform
		query.collision_mask = 1  # Layer for player shapes
		
		var results = space_state.intersect_shape(query)
		for result in results:
			var collider = result.collider
			if is_instance_valid(collider) and not collider.is_enemy and collider.launched:
				print("Enemy detected player collision via query!")
				create_pixel_explosion()
				queue_free()
				SignalBus.emit_shapes_popped(1)
				SignalBus.emit_enemy_destroyed(self)
				return

func create_pixel_explosion():
	# Store position before removal
	var original_position = global_position
	var original_color = get_shape_color()
	var parent = get_parent()
	
	# Make the original shape invisible
	visible = false

	# Create single pop effect
	var pop_effect = Node2D.new()
	pop_effect.name = "PopEffect"
	pop_effect.global_position = original_position
	parent.add_child(pop_effect)
	
	# Simple white flash
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.7)
	flash.size = Vector2(40, 40)
	flash.position = Vector2(-20, -20)
	pop_effect.add_child(flash)
	
	# Flash animation - just fade out
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.2)
	
	# Simple expanding circles
	for i in range(2):
		var circle = Line2D.new()
		circle.width = 2.0
		circle.default_color = original_color
		
		# Create circle points
		var points = []
		var segments = 6
		for j in range(segments + 1):
			var angle = TAU * j / segments
			points.append(Vector2(cos(angle), sin(angle)) * 5.0)
		
		circle.points = PackedVector2Array(points)
		pop_effect.add_child(circle)
		
		# Simple expand and fade animation
		var circle_tween = create_tween()
		circle_tween.tween_property(circle, "scale", Vector2(5, 5), 0.3)
		circle_tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.3)
		
		# Start second circle slightly delayed
		if i == 1:
			circle.modulate.a = 0.7
			circle.scale = Vector2(0.5, 0.5)
			circle_tween.set_delay(0.1)
	
	# Add tiny screen shake
	var camera = get_viewport().get_camera_2d()
	if camera:
		var shake_tween = create_tween()
		shake_tween.tween_property(camera, "offset", Vector2(2, 0), 0.05)
		shake_tween.tween_property(camera, "offset", Vector2(-2, 0), 0.05)
		shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)
	
	# Cleanup timer
	var cleanup_timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 0.4
	pop_effect.add_child(cleanup_timer)
	cleanup_timer.start()
	
	cleanup_timer.timeout.connect(func():
		pop_effect.queue_free()
	)
	
	# Queue self for deletion immediately
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
