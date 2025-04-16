extends Node2D  

@export var shape_scene: PackedScene  
@export var launch_speed: float = 700.0  
@export var cooldown_time: float = 1.5  

var current_shape: Node = null  
var next_shape: Node = null  
var can_launch: bool = true  
var cooldown_timer: float = 0.0  
var aim_direction: Vector2 = Vector2.UP  
var game_over: bool = false
var multi_shot_count: int = 1  # Default to 1 shot
var is_spawning_shape: bool = false # Mutex flag to prevent concurrent spawns

var launcher_core: Node2D
var launcher_inner: Node2D
var target_node: Node2D = null
var target_particles: CPUParticles2D = null

var trajectory_points = []
var max_trajectory_points = 10  
var crosshair_rotation = 0.0

var launcher_direction: Marker2D
var trajectory_marker: Node2D
const MAX_DOTS = 10

func _ready():  
	initialize_launcher()
	spawn_current_shape()
	
	# Connect to the upgrades signal
	if not SignalBus.upgrades_changed.is_connected(_on_upgrades_changed):
		SignalBus.upgrades_changed.connect(_on_upgrades_changed)
	
	# Get initial upgrades from game controller
	var game_controller = get_node_or_null("/root/Main")
	if game_controller and game_controller.has_method("get_upgrades"):
		var upgrades = game_controller.get_upgrades()
		if upgrades.has("multi_shot"):
			multi_shot_count = upgrades["multi_shot"]
			print("Initial multi_shot_count set to: ", multi_shot_count)

func _on_upgrades_changed(upgrades: Dictionary):
	if upgrades.has("multi_shot"):
		multi_shot_count = upgrades["multi_shot"]
		print("Multi-shot updated to: ", multi_shot_count)

func initialize_launcher():
	ensure_launcher_parts()
	create_launcher_visuals()
	create_enhanced_crosshair()
	create_ambient_glow()
	modify_existing_trajectory_pointer()
	
	var existing_shape = get_node_or_null("Shape")
	if existing_shape:
		existing_shape.queue_free()

func ensure_launcher_parts():
	if not has_node("LauncherCore"):
		create_launcher_components()

func _process(delta):  
	update_cooldown(delta)
	update_aim()
	update_visuals(delta)
	
	if Input.is_action_just_pressed("fire"):
		if can_launch and current_shape != null:
			launch_shape()
		elif not can_launch:
			show_cannot_fire_animation()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if can_launch and current_shape != null:
				launch_shape()
			elif not can_launch:
				show_cannot_fire_animation()

func update_cooldown(delta):
	if not can_launch:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_launch = true
			cooldown_timer = 0.0
		
			if not has_node("ReadyAnimation"):
				var ready_node = Node2D.new()
				ready_node.name = "ReadyAnimation"
				add_child(ready_node)
				
				var crosshair = get_node_or_null("Crosshair")
				if crosshair:
					var original_scale = crosshair.scale
					var inner_crosshair = crosshair.get_child(1) if crosshair.get_child_count() > 1 else null
					if inner_crosshair:
						var tween = create_tween()
						tween.tween_property(crosshair, "scale", original_scale * 1.3, 0.2)
						tween.tween_property(crosshair, "scale", original_scale, 0.3)
						tween.tween_callback(func():
							if is_instance_valid(ready_node) and not ready_node.is_queued_for_deletion():
								ready_node.queue_free()
						)
		
		update_cooldown_visual()

func update_aim():
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	update_trajectory_pointer(mouse_pos)

func update_visuals(delta: float = 0.0):
	var mouse_pos = get_global_mouse_position()
	
	var crosshair = get_node_or_null("Crosshair")
	if crosshair:
		crosshair.global_position = mouse_pos
		
		crosshair_rotation += delta * 0.5
		var inner_crosshair = crosshair.get_child(1) if crosshair.get_child_count() > 1 else crosshair.get_child(0) if crosshair.get_child_count() > 0 else null
		if inner_crosshair:
			inner_crosshair.rotation = crosshair_rotation
	
	var reticle = get_node_or_null("LauncherReticle")
	if reticle:
		reticle.rotation = aim_direction.angle() + PI/2

func launch_shape():
	if not can_launch or not current_shape:
		return
		
	# Set spawning flag to false to cancel any ongoing spawn operations
	is_spawning_shape = false
	
	add_launch_effect()
	create_launch_flash()
	
	var crosshair = get_node_or_null("Crosshair")
	if crosshair:
		var inner_crosshair = crosshair.get_child(1) if crosshair.get_child_count() > 1 else null
		if inner_crosshair:
			var original_scale = crosshair.scale
			
			var tween = create_tween()
			tween.tween_property(crosshair, "scale", original_scale * 1.3, 0.1)
			tween.tween_property(crosshair, "scale", original_scale, 0.2)
	
	# Print the current multi_shot_count to debug
	print("Launching with multi_shot_count: ", multi_shot_count)
	
	# Get the last shape that was launched for signal
	var last_launched_shape = null
	
	# Store and clear the original shape
	var original_shape = current_shape
	current_shape = null
	
	# Launch multiple shapes based on multi_shot_count
	for i in range(multi_shot_count):
		var shot_shape = null
		
		if i == 0 and original_shape and is_instance_valid(original_shape):
			# Use the original shape for the first shot
			shot_shape = original_shape
			if shot_shape.is_in_group("launcher_shapes"):
				shot_shape.remove_from_group("launcher_shapes")
		else:
			# Create additional shapes for multi-shot
			shot_shape = shape_scene.instantiate()
			shot_shape.shape_type = randi() % 3
			shot_shape.color = randi() % 6
			get_parent().add_child(shot_shape)
			shot_shape.position = position
			
			# Force the additional shapes to be properly initialized
			shot_shape.initialize_shape()
		
		if shot_shape and is_instance_valid(shot_shape):
			last_launched_shape = shot_shape
			
			# Calculate spread angle for multiple shots
			var spread_angle = 0.0
			if multi_shot_count > 1:
				spread_angle = (i - (multi_shot_count - 1) / 2.0) * 0.15  # Increased spread angle
			
			var shot_direction = aim_direction.rotated(spread_angle)
			
			shot_shape.freeze = false
			shot_shape.gravity_scale = 0.0
			shot_shape.linear_damp = 0.0  
			shot_shape.contact_monitor = true
			shot_shape.max_contacts_reported = 10
			shot_shape.lock_rotation = false
			shot_shape.add_to_group("shapes")
			
			var launch_impulse = shot_direction * launch_speed
			shot_shape.apply_central_impulse(launch_impulse)
			
			if shot_shape.has_method("set_launched"):
				shot_shape.set_launched()
			else:
				shot_shape.launched = true
				
			shot_shape.apply_torque_impulse(randf_range(-10000, 10000))
			
			# Debug print for each shape launched
			print("Launched shape ", i+1, " of ", multi_shot_count)
	
	can_launch = false
	cooldown_timer = cooldown_time
	
	# Wait until we've finished launching before spawning a new shape
	await get_tree().process_frame
	
	spawn_current_shape()
	
	if last_launched_shape:
		SignalBus.emit_shape_launched(last_launched_shape)

func spawn_current_shape():
	# If we're already spawning a shape, don't start another spawn
	if is_spawning_shape:
		print("Prevented concurrent shape spawn")
		return
		
	is_spawning_shape = true
	
	# First, clean up the current shape
	if current_shape and is_instance_valid(current_shape):
		current_shape.queue_free()
		current_shape = null
	
	# Then, forcefully clean up ALL launcher shapes - more aggressive cleanup
	var launcher_shapes = get_tree().get_nodes_in_group("launcher_shapes")
	for shape in launcher_shapes:
		if is_instance_valid(shape):
			shape.queue_free()
	
	# Wait for a frame to ensure cleanup is complete
	await get_tree().process_frame
	
	# Final check for any shapes at the launcher position
	var all_shapes = get_tree().get_nodes_in_group("shapes")
	for shape in all_shapes:
		if is_instance_valid(shape) and shape.position.distance_to(position) < 20:
			shape.queue_free()
	
	# Wait again to ensure all cleanups have processed
	await get_tree().process_frame
	
	# Only continue if we're still supposed to be spawning
	# (check if something canceled the spawning while we were waiting)
	if !is_spawning_shape:
		return
	
	# Create a new shape
	var shape = shape_scene.instantiate() 
	shape.shape_type = randi() % 3
	shape.color = randi() % 6
	shape.freeze = true
	shape.add_to_group("launcher_shapes")
	
	var glow = ColorRect.new()
	glow.color = Color(1, 0.9, 0.7, 0.2)
	glow.size = Vector2(60, 60)
	glow.position = Vector2(-30, -30)
	glow.z_index = -1
	shape.add_child(glow)
	
	# Add shape directly
	get_parent().add_child(shape)
	shape.position = position
	
	current_shape = shape
	
	# Brief delay to ensure the shape is fully setup before allowing another spawn
	await get_tree().create_timer(0.05).timeout
	is_spawning_shape = false

func update_cooldown_visual():
	var base = get_node_or_null("LauncherCore")
	if not base: 
		return
		
	var cooldown_percent = cooldown_timer / cooldown_time
	var core_inner = base.get_node_or_null("Inner")
	
	if core_inner:
		var initial_scale = 1.0
		core_inner.scale = Vector2.ONE * (1.0 - cooldown_percent * 0.5) * initial_scale
		
		if cooldown_percent > 0:
			core_inner.modulate = Color(0.5, 0.5, 0.5)
		else:
			if not has_node("ReadyAnimation"):
				var ready_node = Node2D.new()
				ready_node.name = "ReadyAnimation"
				add_child(ready_node)
				
				var crosshair = get_node_or_null("Crosshair")
				if crosshair:
					var original_scale = crosshair.scale
					var inner_crosshair = crosshair.get_child(1) if crosshair.get_child_count() > 1 else null
					if inner_crosshair:
						var tween = create_tween()
						tween.tween_property(crosshair, "scale", original_scale * 1.3, 0.2)
						tween.tween_property(crosshair, "scale", original_scale, 0.3)
						tween.tween_callback(func():
							if is_instance_valid(ready_node) and not ready_node.is_queued_for_deletion():
								ready_node.queue_free()
						)
				
			core_inner.modulate = Color(1.0, 1.0, 1.0)

func create_launcher_components():
	launcher_core = Node2D.new()
	launcher_core.name = "LauncherCore"
	launcher_core.z_index = -1
	add_child(launcher_core)
	
	var core_width = 40
	var core_height = 25
	var corner_radius = 10
	
	var base = create_rounded_rect(Vector2.ZERO, core_width, core_height, corner_radius, Color(0.65, 0.5, 0.35))
	launcher_core.add_child(base)
	
	launcher_inner = Node2D.new()
	launcher_inner.name = "Inner"
	launcher_core.add_child(launcher_inner)
	
	var inner_width = 28
	var inner_height = 18
	var inner_corner_radius = 7
	
	var inner = create_rounded_rect(Vector2(0, -3), inner_width, inner_height, inner_corner_radius, Color(0.75, 0.6, 0.4, 0.9))
	launcher_inner.add_child(inner)

func create_enhanced_crosshair():
	var crosshair = Node2D.new()
	crosshair.name = "Crosshair"
	add_child(crosshair)
	
	var bg = Polygon2D.new()
	var num_points = 16
	var radius = 12
	var points = []
	for i in range(num_points):
		var angle = 2 * PI * i / num_points
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	bg.polygon = points
	bg.color = Color(0.95, 0.95, 0.95, 0.15)
	crosshair.add_child(bg)
	
	var outer_ring = Line2D.new()
	outer_ring.width = 1.5
	outer_ring.default_color = Color(0.95, 0.95, 0.95, 0.4)
	var ring_points = []
	for i in range(num_points + 1):
		var angle = 2 * PI * i / num_points
		ring_points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	outer_ring.points = ring_points
	crosshair.add_child(outer_ring)
	
	var h_line = Line2D.new()
	h_line.width = 1.5
	h_line.default_color = Color(0.95, 0.95, 0.95, 0.5)
	h_line.points = [Vector2(-8, 0), Vector2(8, 0)]
	crosshair.add_child(h_line)
	
	var v_line = Line2D.new()
	v_line.width = 1.5
	v_line.default_color = Color(0.95, 0.95, 0.95, 0.5)
	v_line.points = [Vector2(0, -8), Vector2(0, 8)]
	crosshair.add_child(v_line)
	
	var center_dot = ColorRect.new()
	center_dot.color = Color(0.95, 0.95, 0.95, 0.6)
	center_dot.size = Vector2(3, 3)
	center_dot.position = Vector2(-1.5, -1.5)
	crosshair.add_child(center_dot)
	
	var old_crosshair = get_node_or_null("Crosshair")
	if old_crosshair and old_crosshair != crosshair:
		old_crosshair.queue_free()

func modify_existing_trajectory_pointer():
	var trajectory = get_node_or_null("LauncherDirection")
	if trajectory:
		trajectory.width = 4.0  
		trajectory.default_color = Color(0.85, 0.6, 0.3, 0.35)
		trajectory.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trajectory.end_cap_mode = Line2D.LINE_CAP_ROUND
		trajectory.antialiased = true
		
		trajectory.points = [Vector2(0, 0), Vector2(0, -300)]
		
		var dot = trajectory.get_node_or_null("DirectionDot")
		if dot:
			dot.queue_free()
			
		var arrow = Polygon2D.new()
		arrow.name = "ArrowHead"
		arrow.color = Color(0.85, 0.6, 0.3, 0.35)
		arrow.polygon = [Vector2(0, -8), Vector2(6, 4), Vector2(-6, 4)]
		arrow.position = Vector2(0, -300)
		trajectory.add_child(arrow)
		
		var tween = create_tween()
		tween.set_loops(0)
		tween.tween_property(trajectory, "width", 5.5, 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(trajectory, "width", 4.0, 1.0).set_trans(Tween.TRANS_SINE)

func update_trajectory_pointer(mouse_pos):
	var trajectory_line = get_node_or_null("LauncherDirection")
	if not trajectory_line:
		return
	
	trajectory_line.global_position = global_position
	
	var distance_to_mouse = global_position.distance_to(mouse_pos)
	
	var direction_to_mouse = (mouse_pos - global_position).normalized()
	
	trajectory_line.rotation = direction_to_mouse.angle() + PI/2
	
	var max_trajectory_length = max(0, distance_to_mouse - 150)
	max_trajectory_length = min(max_trajectory_length, 300)
	
	trajectory_line.points = [Vector2(0, 0), Vector2(0, -max_trajectory_length)]
	
	var arrow = trajectory_line.get_node_or_null("ArrowHead")
	if arrow:
		arrow.position = Vector2(0, -max_trajectory_length)

	var distance_factor = clamp(distance_to_mouse / 300.0, 0.0, 1.0)
	
	if arrow:
		var min_arrow_size = 0.8
		var max_arrow_size = 1.5
		var arrow_scale = lerp(min_arrow_size, max_arrow_size, distance_factor)
		arrow.scale = Vector2(arrow_scale, arrow_scale)

func add_launch_effect():
	pass

func create_launch_flash():
	pass

func create_particle_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.colors = [Color(0.9, 0.7, 0.5, 1), Color(0.85, 0.6, 0.4, 0)]
	gradient.offsets = [0, 1]
	return gradient

func create_animated_ring(radius: float, color: Color, width: float) -> Node2D:
	var ring = Node2D.new()
	
	var circle = Line2D.new()
	circle.width = width
	circle.default_color = color
	
	var num_points = 24
	var points = []
	for i in range(num_points + 1):
		var angle = 2 * PI * i / num_points
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	
	circle.points = points
	ring.add_child(circle)
	
	var tween = create_tween()
	tween.set_loops(0)
	tween.tween_property(ring, "rotation", 2*PI, 8.0).set_trans(Tween.TRANS_SINE)
	
	return ring

func create_ambient_glow():
	if not has_node("LauncherCore"):
		return
		
	var l_core = get_node("LauncherCore")
		
	var ambient_light = Sprite2D.new()
	ambient_light.z_index = -1
	
	var light_size = 128
	var light_image = Image.create(light_size, light_size, false, Image.FORMAT_RGBA8)
	light_image.fill(Color(0,0,0,0))
	
	var center = Vector2(light_size / 2.0, light_size / 2.0)
	var max_radius = light_size / 2.0
	
	for x in range(light_size):
		for y in range(light_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist < max_radius:
				var alpha = 1.0 - pow(dist / max_radius, 2)
				var color = Color(1.0, 0.9, 0.7, alpha * 0.2)
				light_image.set_pixel(x, y, color)
	
	ambient_light.texture = ImageTexture.create_from_image(light_image)
	l_core.add_child(ambient_light)
	
	var ambient_tween = safe_tween(ambient_light)
	if ambient_tween:  
		ambient_tween.set_loops(0)  
		ambient_tween.tween_property(ambient_light, "scale", Vector2(1.2, 1.2), 3.0).set_trans(Tween.TRANS_SINE)
		ambient_tween.tween_property(ambient_light, "scale", Vector2(0.8, 0.8), 3.0).set_trans(Tween.TRANS_SINE)
	
	var ambient_particles = CPUParticles2D.new()
	ambient_particles.name = "AmbientParticles"
	ambient_particles.amount = 15
	ambient_particles.lifetime = 4.0
	ambient_particles.preprocess = 2.0
	ambient_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	ambient_particles.emission_sphere_radius = 60
	ambient_particles.spread = 180
	ambient_particles.gravity = Vector2.ZERO
	ambient_particles.initial_velocity_min = 2
	ambient_particles.initial_velocity_max = 8
	ambient_particles.scale_amount_min = 2.0
	ambient_particles.scale_amount_max = 5.0
	ambient_particles.color = Color(1.0, 0.85, 0.7, 0.2)
	add_child(ambient_particles)
	
	var timer = Timer.new()
	timer.wait_time = 0.8
	timer.autostart = true
	add_child(timer)
	
	timer.timeout.connect(func():
		if randf() > 0.7:  
			create_random_sparkle()
	)

func create_random_sparkle():
	var sparkle = Node2D.new()
	add_child(sparkle)
	
	var angle = randf() * 2 * PI
	var distance = randf_range(20, 60)
	sparkle.position = Vector2(cos(angle) * distance, sin(angle) * distance)
	
	var sprite = Sprite2D.new()
	var size = 8
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	
	var center = Vector2(size / 2.0, size / 2.0)
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < size / 2.0:
				var alpha = 1.0 - dist / (size / 2.0)
				img.set_pixel(x, y, Color(1.0, 0.95, 0.9, alpha))
	
	sprite.texture = ImageTexture.create_from_image(img)
	sparkle.add_child(sprite)
	
	var tween = safe_tween(sparkle)
	sparkle.scale = Vector2(0.1, 0.1)
	sprite.modulate.a = 0
	
	if tween:  
		tween.tween_property(sparkle, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "modulate:a", 0.8, 0.2)
		tween.tween_interval(0.1)
		tween.tween_property(sparkle, "scale", Vector2(0.1, 0.1), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4)
		tween.tween_callback(sparkle.queue_free)

func safe_tween(target_obj: Node = null) -> Tween:
	var tween = create_tween()
	if tween == null:
		if target_obj:
			tween = target_obj.create_tween()
	
	return tween

func create_launcher_visuals():
	var base = Node2D.new()
	base.name = "LauncherVisuals"
	base.z_index = -2
	add_child(base)
	
	var shadows = Node2D.new()
	shadows.name = "Shadows"
	shadows.position = Vector2(3, 3)
	shadows.z_index = -1
	shadows.modulate = Color(0, 0, 0, 0.15)
	base.add_child(shadows)
	
	create_rounded_launcher_base(base, shadows)
	
	var core_glow = create_launcher_glow()
	core_glow.name = "CoreGlow"
	core_glow.z_index = -3
	base.add_child(core_glow)

func create_rounded_launcher_base(parent, shadow_parent):
	var base_width = 50
	var base_height = 30
	var corner_radius = 12
	
	var body = create_rounded_rect(Vector2.ZERO, base_width, base_height, corner_radius, Color(0.65, 0.5, 0.35, 0.9))
	body.z_index = -1
	parent.add_child(body)
	
	var shadow_body = create_rounded_rect(Vector2.ZERO, base_width, base_height, corner_radius, Color(0.55, 0.4, 0.25, 0.8))
	shadow_parent.add_child(shadow_body)
	
	var inner_width = 30
	var inner_height = 20
	var inner_corner = 8
	
	var inner_body = create_rounded_rect(Vector2(0, -5), inner_width, inner_height, inner_corner, Color(0.75, 0.6, 0.4, 0.9))
	inner_body.z_index = 0
	parent.add_child(inner_body)

func create_rounded_rect(pos: Vector2, width: float, height: float, corner_radius: float, color: Color) -> Node2D:
	var container = Node2D.new()
	container.position = pos
	
	var rect = Sprite2D.new()
	
	var img_width = int(width) + 4
	var img_height = int(height) + 4
	var img = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	for x in range(img_width):
		for y in range(img_height):
			var local_x = x - img_width / 2.0
			var local_y = y - img_height / 2.0
			
			var in_rect = false
			
			if abs(local_x) <= (width / 2.0 - corner_radius) or abs(local_y) <= (height / 2.0 - corner_radius):
				if abs(local_x) <= width / 2.0 and abs(local_y) <= height / 2.0:
					in_rect = true
			else:
				var corner_center_x = -width / 2.0 + corner_radius if local_x < 0 else width / 2.0 - corner_radius
				var corner_center_y = -height / 2.0 + corner_radius if local_y < 0 else height / 2.0 - corner_radius
				var dist = Vector2(local_x - corner_center_x, local_y - corner_center_y).length()
				
				if dist <= corner_radius:
					in_rect = true
			
			if in_rect:
				img.set_pixel(x, y, color)
	
	rect.texture = ImageTexture.create_from_image(img)
	container.add_child(rect)
	
	return container

func create_launcher_glow() -> Node2D:
	var glow_container = Node2D.new()
	
	var glow_effect = create_glow_particles()
	glow_container.add_child(glow_effect)
	
	return glow_container

func create_glow_particles() -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 1.5
	particles.explosiveness = 0.1
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 10.0
	particles.angular_velocity_min = -50.0
	particles.angular_velocity_max = 50.0
	particles.linear_accel_min = -5.0
	particles.linear_accel_max = -5.0
	particles.radial_accel_min = -10.0
	particles.radial_accel_max = -10.0
	particles.damping_min = 5.0
	particles.damping_max = 5.0
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	particles.color = Color(0.85, 0.65, 0.45, 0.2)
	particles.color_ramp = create_glow_gradient()
	
	return particles

func create_glow_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.colors = [Color(0.85, 0.65, 0.4, 0.3), Color(0.8, 0.6, 0.35, 0)]
	gradient.offsets = [0, 1]
	return gradient

func get_target_position():
	var target_pos = get_global_mouse_position()
	
	var dir = (target_pos - global_position).normalized()
	var max_distance = 300
	var distance = min((target_pos - global_position).length(), max_distance)
	
	return global_position + dir * distance

func launch_shape_at_target():
	if not can_launch:
		return
		
	var target_pos = get_target_position()
	launch_shape_at_position(target_pos)

func launch_shape_at_position(target_pos: Vector2):
	if not can_launch or not current_shape:
		return
	
	var launch_dir = (target_pos - global_position).normalized()
	
	current_shape.freeze = false
	current_shape.apply_central_impulse(launch_dir * launch_speed)
	current_shape.launched = true
	
	spawn_current_shape()
	
	cooldown_timer = cooldown_time
	can_launch = false
	
	add_launch_effect()
	
	SignalBus.emit_shape_launched(current_shape)

func highlight_target_position():
	var target_pos = get_target_position()
	
	if not target_node:
		target_node = Node2D.new()
		target_node.name = "TargetHighlight"
		target_node.z_index = -1
		get_parent().add_child(target_node)
		
		target_particles = CPUParticles2D.new()
		target_particles.amount = 12
		target_particles.lifetime = 0.8
		target_particles.explosiveness = 0.0
		target_particles.local_coords = false
		target_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		target_particles.emission_sphere_radius = 10.0
		target_particles.direction = Vector2.RIGHT
		target_particles.spread = 180.0
		target_particles.gravity = Vector2.ZERO
		target_particles.initial_velocity_min = 0.0
		target_particles.initial_velocity_max = 0.0
		target_particles.orbit_velocity_min = 1.0
		target_particles.orbit_velocity_max = 2.0
		target_particles.radial_accel_min = -10.0
		target_particles.radial_accel_max = -10.0
		target_particles.scale_amount_min = 2.0
		target_particles.scale_amount_max = 3.0
		target_particles.color = Color(1, 0.7, 0.3, 0.7)
		target_particles.color_ramp = create_target_gradient()
		
		target_node.add_child(target_particles)
		
	target_node.global_position = target_pos
	target_particles.emitting = true

func create_target_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.colors = [Color(0.9, 0.7, 0.5, 0.8), Color(0.85, 0.6, 0.4, 0)]
	gradient.offsets = [0, 1]
	return gradient

func detect_game_over():
	var tolerance = 5
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(RectangleShape2D.new())
	query.shape.extents = Vector2(tolerance, 15)
	query.transform = Transform2D(0, Vector2(global_position.x, global_position.y - 15))
	query.collision_mask = 2
	
	var results = space_state.intersect_shape(query)
	
	if results.size() > 0:
		for result in results:
			if result.collider is RigidBody2D and result.collider.is_in_group("shapes"):
				if not result.collider.launched and not result.collider.is_queued_for_deletion():
					end_game()
					break

func end_game():
	if game_over: 
		return
		
	game_over = true
	
	SignalBus.emit_game_over_triggered()
	
	var all_shapes = get_tree().get_nodes_in_group("shapes")
	for shape in all_shapes:
		shape.freeze = false
		shape.gravity_scale = 1
		
		var explosion_force = 150
		var dir = (shape.global_position - global_position).normalized()
		shape.apply_central_impulse(dir * explosion_force)

func _on_detection_timer_timeout():
	if game_over:
		return
		
	detect_game_over()

func _on_shape_bounced(body_node: Node):
	if body_node is RigidBody2D and body_node.is_in_group("shapes") and body_node.launched:
		body_node.launched = false
		
		
		var bounce_force = 80.0
		var bounce_dir = (body_node.global_position - global_position).normalized()
		body_node.apply_central_impulse(bounce_dir * bounce_force)
		
		
		check_for_matches(body_node)

func check_for_matches(shape_node):
	if not shape_node or not shape_node.has_launched:
		return
	
	var matched_shapes = []
	var shapes = get_tree().get_nodes_in_group("shapes")
	
	var match_radius = 100.0
	
	for other_shape in shapes:
		if other_shape == shape_node or not other_shape.has_launched:
			continue
			
		if other_shape.color == shape_node.color and other_shape.global_position.distance_to(shape_node.global_position) <= match_radius:
			matched_shapes.append(other_shape)
			
	if matched_shapes.size() >= 2:
		matched_shapes.append(shape_node)
		
		var center = Vector2.ZERO
		for shape in matched_shapes:
			center += shape.global_position
		center /= matched_shapes.size()
		
		for shape in matched_shapes:
			shape.cluster_position = center
		
		var score_effect = create_score_effect(center, matched_shapes.size())
		
		for shape in matched_shapes:
			shape.take_damage()
		
		SignalBus.emit_shapes_popped(matched_shapes.size())
		
		return true
		
	return false

func create_score_effect(position: Vector2, count: int):
	var score_effect = Node2D.new()
	score_effect.position = position
	get_parent().add_child(score_effect)
	
	var score_label = Label.new()
	score_label.text = "+" + str(count * 10)
	score_label.position = Vector2(-20, -20)
	score_label.modulate = Color(1, 0.8, 0.3, 1)
	score_effect.add_child(score_label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(score_label, "position:y", -40, 1.0)
	tween.tween_property(score_label, "modulate:a", 0, 1.0)
	tween.chain().tween_callback(func(): score_effect.queue_free())
	
	return score_effect

func show_cannot_fire_animation():
	if has_node("CannotFireAnimation"):
		return
		
	var cannot_fire = Node2D.new()
	cannot_fire.name = "CannotFireAnimation"
	add_child(cannot_fire)
	
	var crosshair = get_node_or_null("Crosshair")
	if crosshair:
		var original_scale = crosshair.scale
		var inner_crosshair = crosshair.get_child(1) if crosshair.get_child_count() > 1 else null
		
		if inner_crosshair:
			var tween = create_tween()
			tween.tween_property(crosshair, "scale", original_scale * 1.5, 0.15)
			tween.tween_property(crosshair, "scale", original_scale, 0.3)
			tween.tween_callback(func(): cannot_fire.queue_free())
