extends Node2D  

@export var shape_scene: PackedScene  
@export var launch_speed: float = 700.0  
@export var cooldown_time: float = 0.5  

var current_shape: Node = null  
var next_shape: Node = null  
var can_launch: bool = true  
var cooldown_timer: float = 0.0  
var aim_direction: Vector2 = Vector2.UP  
var trajectory_points = []
var max_trajectory_points = 8  
var crosshair_rotation = 0.0  

var launcher_direction: Marker2D
var launcher_core: Node2D
var launcher_inner: Node2D

var trajectory_marker: Node2D
const MAX_DOTS = 10

var target_node: Node2D = null
var target_particles: CPUParticles2D = null
var game_over: bool = false

func _ready():  
	ensure_launcher_parts()
	create_launcher_visuals()
	create_enhanced_crosshair()
	create_ambient_glow()
	create_trajectory_dots()
	
	spawn_current_shape()
	spawn_next_shape()

func ensure_launcher_parts():
	if not has_node("LauncherDirection"):
		var launcher_dir = Line2D.new()
		launcher_dir.name = "LauncherDirection"
		launcher_dir.width = 2.0
		launcher_dir.default_color = Color(1.0, 0.8, 0.5, 0.3)
		launcher_dir.points = [Vector2.ZERO, Vector2(0, -50)]
		launcher_dir.z_index = 1
		add_child(launcher_dir)
	
	if not has_node("LauncherCore"):
		create_launcher_components()

func _process(delta):  
	if not can_launch:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_launch = true
			cooldown_timer = 0.0
		
		update_cooldown_visual()
	
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	
	if has_node("LauncherDirection"):
		$LauncherDirection.rotation = aim_direction.angle() + PI/2
	
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
	
	update_trajectory()
	
	if Input.is_action_just_pressed("fire") and can_launch and current_shape != null:
		launch_shape()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if can_launch and current_shape != null:
				launch_shape()

func launch_shape():
	if not can_launch or not current_shape:
		return
		
	add_launch_effect()
	create_launch_flash()
	
	if current_shape is RigidBody2D:
		remove_child(current_shape)
		get_parent().add_child(current_shape)
		current_shape.global_position = global_position
		
		current_shape.freeze = false
		current_shape.gravity_scale = 0.0
		current_shape.linear_damp = -1
		
		current_shape.apply_central_impulse(aim_direction * launch_speed)
		if current_shape.has_method("set_launched"):
			current_shape.set_launched()
		else:
			current_shape.launched = true
			
		# Add a spin to make it more dynamic
		current_shape.apply_torque_impulse(randf_range(-5000, 5000))
	else:
		print("Warning: current_shape is not a RigidBody2D")
		
	can_launch = false
	cooldown_timer = cooldown_time
		
	play_launch_sound()
	
	var old_shape = current_shape
	current_shape = null
	
	# Use a timer to delay spawning the new shape
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.1
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	spawn_timer.timeout.connect(func():
		spawn_current_shape()
		
		if next_shape:
			next_shape.queue_free()
		spawn_next_shape()
		
		spawn_timer.queue_free()
	)
	spawn_timer.start()
	
	SignalBus.emit_signal("shape_launched", old_shape)

func update_trajectory():
	var start_pos = global_position
	var vel = aim_direction * launch_speed
	var gravity = Vector2(0, 980)  
	var time_step = 0.15  
	
	if not trajectory_marker:
		create_trajectory_dots()
	
	var max_dots = min(max_trajectory_points, trajectory_points.size())
	for i in range(max_dots):
		var time = time_step * i
		var pos = start_pos + vel * time + 0.5 * gravity * time * time
		
		if i < trajectory_points.size() and trajectory_points[i] != null:
			trajectory_points[i].global_position = pos
			trajectory_points[i].visible = can_launch
			
			var inner_point = trajectory_points[i].get_child(0) if trajectory_points[i].get_child_count() > 0 else null
			if inner_point:
				var scale_pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005 + i * 0.3) * 0.2
				inner_point.scale = Vector2(scale_pulse, scale_pulse)
				
				var fade = i / float(max_trajectory_points)
				var alpha = 0.8 - (i * 0.1)
				
				if inner_point.get_child_count() > 0 and inner_point.get_child(0) != null:
					inner_point.get_child(0).modulate = Color(1.0, 0.9 - fade * 0.2, 0.7 - fade * 0.3, alpha)

func spawn_current_shape():
	var shape = shape_scene.instantiate()
	shape.shape_type = randi() % 5
	
	while next_shape and next_shape.shape_type == shape.shape_type:
		shape.shape_type = randi() % 5 
		
	shape.global_position = global_position
	shape.freeze = true
	
	current_shape = shape
	add_child(current_shape)

func spawn_next_shape():
	var shape = shape_scene.instantiate()
	shape.shape_type = randi() % 5  
	
	while current_shape and current_shape.shape_type == shape.shape_type:
		shape.shape_type = randi() % 5
	
	shape.global_position = Vector2(60, 12)
	shape.scale = Vector2(0.6, 0.6)
	shape.freeze = true
	
	next_shape = shape
	add_child(next_shape)

func add_launch_effect():
	var effect = CPUParticles2D.new()
	effect.position = Vector2.ZERO
	effect.amount = 16
	effect.lifetime = 0.5
	effect.explosiveness = 0.9
	effect.direction = Vector2(0, -1)
	effect.spread = 30
	effect.gravity = Vector2(0, 150)
	effect.initial_velocity_min = 70
	effect.initial_velocity_max = 100
	effect.scale_amount_min = 4
	effect.scale_amount_max = 6
	effect.color = Color(1.0, 0.7, 0.4)
	effect.color_ramp = create_particle_gradient()
	
	add_child(effect)
	effect.emitting = true
	
	await get_tree().create_timer(effect.lifetime + 0.1).timeout
	effect.queue_free()

func create_particle_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.colors = [Color(0.9, 0.7, 0.5, 1), Color(0.85, 0.6, 0.4, 0)]
	gradient.offsets = [0, 1]
	return gradient

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
			core_inner.modulate = Color(1.0, 0.7 + 0.3 * (1.0 - cooldown_percent), 0.7 + 0.3 * (1.0 - cooldown_percent))
		else:
			core_inner.modulate = Color(1.0, 1.0, 1.0)
			
			if not has_node("ReadyEffect"):
				var ready_effect = CPUParticles2D.new()
				ready_effect.name = "ReadyEffect"
				ready_effect.position = Vector2.ZERO
				ready_effect.amount = 20
				ready_effect.lifetime = 0.5
				ready_effect.explosiveness = 0.8
				ready_effect.one_shot = true
				ready_effect.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
				ready_effect.emission_sphere_radius = 10.0
				ready_effect.direction = Vector2(0, -1)
				ready_effect.spread = 180
				ready_effect.gravity = Vector2.ZERO
				ready_effect.initial_velocity_min = 30
				ready_effect.initial_velocity_max = 50
				ready_effect.scale_amount_min = 3
				ready_effect.scale_amount_max = 5
				ready_effect.color = Color(1.0, 0.9, 0.7, 0.8)
				add_child(ready_effect)
				ready_effect.emitting = true
				
				var timer = Timer.new()
				timer.wait_time = 1.0
				timer.one_shot = true
				ready_effect.add_child(timer)
				timer.start()
				timer.timeout.connect(func(): ready_effect.queue_free())

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
	var outer_glow = create_rounded_rect(Vector2.ZERO, 40, 40, 20, Color(0.85, 0.65, 0.45, 0.15))
	add_child(outer_glow)
	
	var crosshair = Node2D.new()
	crosshair.name = "Crosshair"
	add_child(crosshair)
	
	var crosshair_size = 24
	var crosshair_image = Image.create(crosshair_size, crosshair_size, false, Image.FORMAT_RGBA8)
	crosshair_image.fill(Color(0,0,0,0))
	
	var center = Vector2(crosshair_size / 2.0, crosshair_size / 2.0)
	var outer_radius = crosshair_size / 2.0
	var inner_radius = crosshair_size / 2.0 - 4
	var center_dot_radius = 3
	
	for x in range(crosshair_size):
		for y in range(crosshair_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist < outer_radius:
				var color_val = Color(0.9, 0.7, 0.5, 0)
				
				if dist > inner_radius:
					var ring_factor = 1.0 - (dist - inner_radius) / (outer_radius - inner_radius)
					color_val.a = 0.6 * ring_factor
				elif dist < center_dot_radius:
					var dot_factor = 1.0 - dist / center_dot_radius
					color_val.a = 0.7 * dot_factor
				
				crosshair_image.set_pixel(x, y, color_val)
	
	var crosshair_texture = ImageTexture.create_from_image(crosshair_image)
	
	var sprite = Sprite2D.new()
	sprite.texture = crosshair_texture
	crosshair.add_child(sprite)
	
	var tween = safe_tween(outer_glow)
	if tween:  
		tween.set_loops(0)  
		tween.tween_property(outer_glow, "scale", Vector2(1.2, 1.2), 1.3).set_trans(Tween.TRANS_SINE)
		tween.tween_property(outer_glow, "scale", Vector2(0.9, 0.9), 1.3).set_trans(Tween.TRANS_SINE)
	
	var rot_tween = safe_tween(crosshair)
	if rot_tween:  
		rot_tween.set_loops(0)  
		rot_tween.tween_property(crosshair, "rotation", PI / 5.0, 3.0).set_trans(Tween.TRANS_SINE)
		rot_tween.tween_property(crosshair, "rotation", -PI / 5.0, 3.0).set_trans(Tween.TRANS_SINE)
	
	var particles = CPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 2.0
	particles.local_coords = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 5
	particles.initial_velocity_max = 10
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3
	particles.color = Color(0.9, 0.7, 0.5, 0.5)
	crosshair.add_child(particles)

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

func create_trajectory_dots():
	if trajectory_marker == null:
		trajectory_marker = Node2D.new()
		trajectory_marker.name = "TrajectoryMarker"
		add_child(trajectory_marker)
	else:
		for child in trajectory_marker.get_children():
			child.queue_free()
	
	for i in range(MAX_DOTS):
		var dot = Node2D.new()
		dot.position = Vector2.ZERO
		dot.visible = false
		trajectory_marker.add_child(dot)
		
		var dot_sprite = Sprite2D.new()
		
		var dot_size = 16
		var dot_image = Image.create(dot_size, dot_size, false, Image.FORMAT_RGBA8)
		dot_image.fill(Color(0,0,0,0))
		
		var center = Vector2(dot_size / 2.0, dot_size / 2.0)
		var radius = dot_size / 2.0
		
		for x in range(dot_size):
			for y in range(dot_size):
				var pos = Vector2(x, y)
				var dist = pos.distance_to(center)
				
				if dist < radius:
					var alpha = 1.0 - pow(dist / radius, 2)
					var color = Color(1.0, 0.9, 0.7, alpha * 0.7)
					dot_image.set_pixel(x, y, color)
		
		dot_sprite.texture = ImageTexture.create_from_image(dot_image)
		dot_sprite.scale = Vector2(0.5, 0.5)
		dot.add_child(dot_sprite)
		
		var tween = safe_tween(dot_sprite)
		if tween:  
			tween.set_loops(0)  
			tween.tween_property(dot_sprite, "scale", Vector2(0.6, 0.6), 1.0).set_trans(Tween.TRANS_SINE)
			tween.tween_property(dot_sprite, "scale", Vector2(0.4, 0.4), 1.0).set_trans(Tween.TRANS_SINE)

func play_launch_sound():
	var player = AudioStreamPlayer.new()
	player.volume_db = -8
	player.pitch_scale = randf_range(0.9, 1.1)
	
	# Try to load the sound, but don't crash if it fails
	var sound
	
	# First try to load from resources
	if ResourceLoader.exists("res://assets/audio/effects/launch1.ogg"):
		sound = load("res://assets/audio/effects/launch1.ogg")
	else:
		# Create a very simple beep as fallback
		sound = AudioStreamGenerator.new()
		sound.mix_rate = 44100
		sound.buffer_length = 0.1  # 100ms buffer
	
	player.stream = sound
	add_child(player)
	player.play()
	
	# Create a timer to clean up the player after it's done
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	player.add_child(timer)
	timer.start()
	
	# Connect the timeout signal to a function that will free the player
	timer.timeout.connect(func(): player.queue_free())

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
	
	# Create a rounded launcher base with softer edges
	create_rounded_launcher_base(base, shadows)
	
	var next_shape_label = Label.new()
	next_shape_label.text = "NEXT"
	next_shape_label.position = Vector2(35, 0)
	next_shape_label.add_theme_font_size_override("font_size", 10)
	next_shape_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
	base.add_child(next_shape_label)
	
	var core_glow = create_launcher_glow()
	core_glow.name = "CoreGlow"
	core_glow.z_index = -3
	base.add_child(core_glow)

func create_rounded_launcher_base(parent, shadow_parent):
	# Create a soft rounded polygon for the base
	var base_width = 50
	var base_height = 30
	var corner_radius = 12
	
	var body = create_rounded_rect(Vector2.ZERO, base_width, base_height, corner_radius, Color(0.65, 0.5, 0.35, 0.9))
	body.z_index = -1
	parent.add_child(body)
	
	var shadow_body = create_rounded_rect(Vector2.ZERO, base_width, base_height, corner_radius, Color(0.55, 0.4, 0.25, 0.8))
	shadow_parent.add_child(shadow_body)
	
	# Add inner details with rounded corners
	var inner_width = 30
	var inner_height = 20
	var inner_corner = 8
	
	var inner_body = create_rounded_rect(Vector2(0, -5), inner_width, inner_height, inner_corner, Color(0.75, 0.6, 0.4, 0.9))
	inner_body.z_index = 0
	parent.add_child(inner_body)

# Helper function to create a rounded rectangle
func create_rounded_rect(pos: Vector2, width: float, height: float, corner_radius: float, color: Color) -> Node2D:
	var container = Node2D.new()
	container.position = pos
	
	var rect = Sprite2D.new()
	
	var img_width = int(width) + 4
	var img_height = int(height) + 4
	var img = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(img_width / 2.0, img_height / 2.0)
	
	for x in range(img_width):
		for y in range(img_height):
			var point = Vector2(x, y)
			var local_x = x - img_width / 2.0
			var local_y = y - img_height / 2.0
			
			# Check if point is within the rounded rectangle
			var in_rect = false
			
			# Center rectangle region (excluding corners)
			if abs(local_x) <= (width / 2.0 - corner_radius) or abs(local_y) <= (height / 2.0 - corner_radius):
				if abs(local_x) <= width / 2.0 and abs(local_y) <= height / 2.0:
					in_rect = true
			# Corner regions - use distance to corner center
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
	
	if next_shape:
		next_shape.queue_free()
	spawn_next_shape()
	
	cooldown_timer = cooldown_time
	can_launch = false
	
	play_launch_sound()
	add_launch_effect()
	
	SignalBus.emit_signal("shape_launched", current_shape)

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
	
	SignalBus.emit_signal("game_over")
	
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

func create_launch_flash():
	var flash = Sprite2D.new()
	flash.z_index = 10
	
	# Create a simple white flash texture
	var flash_size = 64
	var flash_image = Image.create(flash_size, flash_size, false, Image.FORMAT_RGBA8)
	flash_image.fill(Color(1, 1, 1, 0))
	
	var center = Vector2(flash_size / 2.0, flash_size / 2.0)
	var max_radius = flash_size / 2.0
	
	for x in range(flash_size):
		for y in range(flash_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			if dist < max_radius:
				var alpha = 1.0 - pow(dist / max_radius, 2)
				flash_image.set_pixel(x, y, Color(1, 0.95, 0.8, alpha))
	
	flash.texture = ImageTexture.create_from_image(flash_image)
	flash.modulate.a = 0.8
	add_child(flash)
	
	var tween = safe_tween(flash)
	if tween:
		tween.tween_property(flash, "modulate:a", 0.0, 0.3)
		tween.tween_callback(flash.queue_free)
