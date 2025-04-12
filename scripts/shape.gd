extends RigidBody2D

signal shape_collided(shape, collision_point)

enum ShapeColor { RED, BLUE, GREEN, YELLOW, PURPLE }
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

var layer_nodes = []
var layer1_factor: float = 0.03
var layer2_factor: float = 0.06
var outline: Sprite2D

func _ready():
	set_random_color()
	set_random_shape()
	setup_collision()
	setup_layers()
	create_outline()
	
	var visual = get_node("Visual")
	if visual:
		visual.queue_free()
	
	gravity_scale = 0.0

func _process(delta: float):
	if is_enemy and not is_attached_to_grid:
		var direction = (target_position - global_position).normalized()
		global_position += direction * move_speed * delta
		rotation = direction.angle() + PI/2
		if global_position.y > 700:
			var game_manager = get_node("/root/Main")
			if game_manager:
				game_manager.check_enemies_reached_bottom()
	
	update_layers_position()

func set_random_color():
	color = ShapeColor.values()[randi() % ShapeColor.size()]
	
func set_color(new_color: ShapeColor):
	color = new_color
	
func set_random_shape():
	shape_type = ShapeType.values()[randi() % ShapeType.size()]
	
func set_shape(new_shape: ShapeType):
	shape_type = new_shape
	
func setup_collision():
	var collision_shape = get_node("CollisionShape2D")
	if collision_shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = radius
		collision_shape.shape = circle_shape

func create_outline():
	outline = Sprite2D.new()
	outline.z_index = 5
	
	var circle = Image.create(int(radius * 2 + 6), int(radius * 2 + 6), false, Image.FORMAT_RGBA8)
	circle.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(radius + 3, radius + 3)
	var outline_color = get_color_from_enum()
	outline_color.a = 0.8
	
	for x in range(circle.get_width()):
		for y in range(circle.get_height()):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			if distance <= radius + 3 and distance >= radius - 3:
				circle.set_pixel(x, y, outline_color)
	
	var texture = ImageTexture.create_from_image(circle)
	outline.texture = texture
	add_child(outline)

func setup_layers():
	for old_layer in layer_nodes:
		if is_instance_valid(old_layer):
			old_layer.queue_free()
	layer_nodes.clear()
	
	var layer0 = create_layer_sprite("assets/Layers/0.png", -3, Vector2(0.45, 0.45))
	var layer1 = create_layer_sprite("assets/Layers/1.png", -2, Vector2(0.35, 0.35))
	var layer2 = create_layer_sprite("assets/Layers/2.png", -1, Vector2(0.25, 0.25))
	
	if layer0:
		layer0.modulate.a = 0.9
		layer_nodes.append(layer0)
	if layer1:
		layer1.modulate.a = 0.9
		layer_nodes.append(layer1)
	if layer2:
		layer2.modulate.a = 0.9
		layer_nodes.append(layer2)

func create_layer_sprite(texture_path: String, z_idx: int, scale_val: Vector2) -> Sprite2D:
	var texture = load(texture_path)
	if not texture:
		return null
		
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.z_index = z_idx
	sprite.scale = scale_val
	add_child(sprite)
	return sprite

func update_layers_position():
	if layer_nodes.size() < 3:
		return
		
	var mouse_pos = get_viewport().get_mouse_position() - global_position
	
	layer_nodes[1].position = mouse_pos * layer1_factor
	layer_nodes[2].position = mouse_pos * layer2_factor

func get_color_from_enum() -> Color:
	match color:
		ShapeColor.RED:
			return Color(1, 0.3, 0.3, 1)
		ShapeColor.BLUE:
			return Color(0.3, 0.5, 1, 1)
		ShapeColor.GREEN:
			return Color(0.3, 1, 0.4, 1)
		ShapeColor.YELLOW:
			return Color(1, 0.9, 0.2, 1)
		ShapeColor.PURPLE:
			return Color(0.8, 0.3, 1, 1)
		_:
			return Color(1, 1, 1, 1)

func _on_body_entered(body):
	if body is RigidBody2D:
		if not is_attached_to_grid and not is_enemy:
			emit_signal("shape_collided", self, global_position)
		elif is_enemy:
			take_damage()
		
func take_damage():
	health -= 1
	if health <= 0:
		destroy()
		
		SignalBus.shapes_popped.emit(1)
		
func attach_to_grid(pos: Vector2i):
	is_attached_to_grid = true
	grid_position = pos
	set_deferred("freeze", true)
	
func get_neighbors() -> Array:
	return []

func destroy():
	queue_free()
