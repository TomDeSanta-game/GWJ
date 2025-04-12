extends Node2D  # 2D Node with position in the game world

@export var shape_scene: PackedScene  # Reference to the shape scene to be launched
@export var launch_speed: float = 700.0  # Speed at which shapes are launched
@export var cooldown_time: float = 0.5  # Time between launches

var current_shape: Node = null  # Currently loaded shape
var next_shape: Node = null  # Next shape in the sequence
var can_launch: bool = true  # Whether launcher can fire
var cooldown_timer: float = 0.0  # Timer for launch cooldown
var aim_direction: Vector2 = Vector2.UP  # Current direction of launch
var trajectory_points = []
var max_trajectory_points = 8  # Increased for better trajectory visualization
var crosshair_rotation = 0.0  # Rotation for crosshair animation

# Required launcher parts
var launcher_direction: Marker2D
var launcher_core: Node2D
var launcher_inner: Node2D

# Trajectory visualization
var trajectory_marker: Node2D
const MAX_DOTS = 10

func _ready():  # Called when node enters scene tree
	ensure_launcher_parts()
	create_enhanced_crosshair()
	create_ambient_glow()
	create_trajectory_dots()
	
	spawn_current_shape()
	spawn_next_shape()

# Ensure all required launcher parts exist
func ensure_launcher_parts():
	# Create LauncherDirection if needed
	if not has_node("LauncherDirection"):
		var launcher_dir = Line2D.new()
		launcher_dir.name = "LauncherDirection"
		launcher_dir.width = 2.0
		launcher_dir.default_color = Color(1.0, 0.8, 0.5, 0.5)
		launcher_dir.points = [Vector2.ZERO, Vector2(0, -50)]
		launcher_dir.z_index = 1
		add_child(launcher_dir)
	
	# Create LauncherCore if needed
	if not has_node("LauncherCore"):
		create_launcher_components()
	
	# Create LauncherInner if needed
	if not has_node("LauncherInner"):
		# Create a more rounded launcher inner core
		var launcher_inner_container = Node2D.new()
		launcher_inner_container.name = "LauncherInner"
		add_child(launcher_inner_container)
		
		var inner = Sprite2D.new()
		var inner_size = 20
		var inner_img = Image.create(inner_size, inner_size, false, Image.FORMAT_RGBA8)
		inner_img.fill(Color(0, 0, 0, 0))
		
		var center = Vector2(inner_size / 2.0, inner_size / 2.0)
		var radius = inner_size / 2.0
		
		for x in range(inner_size):
			for y in range(inner_size):
				var dist = Vector2(x, y).distance_to(center)
				if dist < radius:
					var gradient_factor = 1.0 - (dist / radius)
					var color = Color(1.0, 0.8, 0.5, 1.0).lightened(0.3 * gradient_factor)
					inner_img.set_pixel(x, y, color)
		
		inner.texture = ImageTexture.create_from_image(inner_img)
		inner.z_index = 3
		launcher_inner_container.add_child(inner)
		
		# Add subtle pulsing particles inside
		var inner_particles = CPUParticles2D.new()
		inner_particles.amount = 6
		inner_particles.lifetime = 1.0
		inner_particles.local_coords = true
		inner_particles.emission_shape = 0  # Sphere shape
		inner_particles.emission_sphere_radius = 6
		inner_particles.gravity = Vector2.ZERO
		inner_particles.initial_velocity_min = 2
		inner_particles.initial_velocity_max = 5
		inner_particles.scale_amount_min = 1.0
		inner_particles.scale_amount_max = 2.0
		inner_particles.color = Color(1.0, 0.9, 0.7, 0.6)
		launcher_inner_container.add_child(inner_particles)

func _process(delta):  # Called every frame
	# Handle cooldown timer
	if not can_launch:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_launch = true
			cooldown_timer = 0.0
			
		# Update cooldown visual
		update_cooldown_visual()
	
	# Get mouse position and calculate aim direction
	var mouse_pos = get_global_mouse_position()
	
	# Position crosshair at mouse position with smooth movement
	var crosshair = get_node_or_null("Crosshair")
	if crosshair:
		# Smoothly move crosshair to mouse position
		crosshair.global_position = crosshair.global_position.lerp(mouse_pos, 0.2)
		
		# Add rotation animation to crosshair
		crosshair_rotation += delta * 0.5
		var inner_crosshair = crosshair.get_child(1)
		if inner_crosshair:
			inner_crosshair.rotation = crosshair_rotation
	
	# Calculate launch direction based on launcher to crosshair
	if crosshair:
		aim_direction = (crosshair.global_position - global_position).normalized()
		
		# Update launcher direction line
		$LauncherDirection.rotation = aim_direction.angle()
	
	# Update trajectory preview
	update_trajectory()
	
	# Handle input
	if Input.is_action_just_pressed("fire") and can_launch:
		launch_shape()

func update_trajectory():
	var start_pos = global_position
	var vel = aim_direction * launch_speed
	var gravity = Vector2(0, 980)  # Approximate gravity
	var time_step = 0.15  # Smaller step for smoother trajectory
	
	for i in range(max_trajectory_points):
		var time = time_step * i
		var pos = start_pos + vel * time + 0.5 * gravity * time * time
		trajectory_points[i].global_position = pos
		
		# Add pulse effect to trajectory points
		var inner_point = trajectory_points[i].get_child(0)
		var scale_pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005 + i * 0.3) * 0.2
		inner_point.scale = Vector2(scale_pulse, scale_pulse)
		
		# Enhanced color animation with warmer colors
		var fade = i / float(max_trajectory_points)
		var alpha = 0.8 - (i * 0.1)
		inner_point.get_child(0).modulate = Color(1.0, 0.9 - fade * 0.2, 0.7 - fade * 0.3, alpha)

func spawn_current_shape():
	if current_shape:
		current_shape.queue_free()
	
	current_shape = shape_scene.instantiate()
	current_shape.position = Vector2.ZERO
	add_child(current_shape)
	
	# Apply enhanced initial effects
	current_shape.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(current_shape, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Add glow particles
	var glow = CPUParticles2D.new()
	glow.amount = 15
	glow.lifetime = 1.0
	glow.local_coords = true
	glow.emission_shape = 0  # Sphere shape
	glow.emission_sphere_radius = 30
	glow.spread = 180
	glow.gravity = Vector2.ZERO
	glow.initial_velocity_min = 5
	glow.initial_velocity_max = 20
	glow.scale_amount_min = 3
	glow.scale_amount_max = 6
	glow.color = Color(0.7, 0.9, 1.0, 0.3)
	current_shape.add_child(glow)

func spawn_next_shape():
	if next_shape:
		next_shape.queue_free()
	
	next_shape = shape_scene.instantiate()
	next_shape.position = Vector2(0, 50)  # Position below main shape
	next_shape.scale = Vector2(0.5, 0.5)  # Smaller preview
	add_child(next_shape)
	
	# Create a preview container for enhanced effects
	var preview_container = Node2D.new()
	preview_container.name = "PreviewContainer"
	preview_container.position = next_shape.position
	add_child(preview_container)
	
	# Add soft glow behind next shape
	var preview_glow = Sprite2D.new()
	var glow_size = 48
	var glow_img = Image.create(glow_size, glow_size, false, Image.FORMAT_RGBA8)
	glow_img.fill(Color(0, 0, 0, 0))
	
	var center = Vector2(glow_size / 2.0, glow_size / 2.0)
	var radius = glow_size / 2.0
	
	for x in range(glow_size):
		for y in range(glow_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var alpha = 1.0 - pow(dist / radius, 1.5)
				glow_img.set_pixel(x, y, Color(0.9, 0.8, 1.0, alpha * 0.2))
	
	preview_glow.texture = ImageTexture.create_from_image(glow_img)
	preview_glow.z_index = -1
	preview_container.add_child(preview_glow)
	
	# Add subtle sparkle particles around next shape
	var sparkles = CPUParticles2D.new()
	sparkles.amount = 5
	sparkles.lifetime = 1.5
	sparkles.emission_shape = 0  # Sphere shape
	sparkles.emission_sphere_radius = 30
	sparkles.local_coords = true
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 2
	sparkles.initial_velocity_max = 5
	sparkles.scale_amount_min = 1.0
	sparkles.scale_amount_max = 2.5
	sparkles.color = Color(1.0, 0.95, 0.9, 0.4)
	preview_container.add_child(sparkles)
	
	# Create a preview "coming next" text
	var preview_label = Label.new()
	preview_label.text = "Next"
	preview_label.position = Vector2(-20, -40)
	preview_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8, 0.6))
	preview_label.add_theme_font_size_override("font_size", 12)
	preview_container.add_child(preview_label)
	
	# Enhanced fade-in with scale bounce
	next_shape.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(next_shape, "modulate:a", 0.7, 0.5).set_trans(Tween.TRANS_SINE)
	
	# Add slow rotation to preview
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(next_shape, "rotation", PI / 8.0, 3.0).set_trans(Tween.TRANS_SINE)
	rotation_tween.tween_property(next_shape, "rotation", -PI / 8.0, 3.0).set_trans(Tween.TRANS_SINE)
	
	# Add subtle pulsing to preview glow
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(preview_glow, "scale", Vector2(1.2, 1.2), 1.5).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(preview_glow, "scale", Vector2(0.9, 0.9), 1.5).set_trans(Tween.TRANS_SINE)

func launch_shape():
	if current_shape:
		# Enhanced visual feedback
		add_launch_effect()
		
		current_shape.apply_central_impulse(get_launch_direction() * get_launch_power())
		current_shape.has_launched = true
		current_shape = null
		
		# Play improved launch sound
		play_launch_sound()

func add_launch_effect():
	# Create a trail effect behind the launched shape
	var trail = Line2D.new()
	trail.name = "LaunchTrail"
	trail.width = 12.0
	trail.default_color = Color(1.0, 0.7, 0.3, 0.7)
	trail.gradient = create_warm_gradient()
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	
	# Position the trail based on launch direction
	var start_point = Vector2.ZERO
	var end_point = aim_direction * 150
	trail.points = [start_point, end_point]
	
	# Add particles to the trail
	var particles = CPUParticles2D.new()
	particles.name = "LaunchParticles"
	particles.amount = 40
	particles.lifetime = 0.6
	particles.explosiveness = 0.6
	particles.emission_shape = 1  # Line shape
	particles.emission_rect_extents = Vector2(end_point.length(), 1)
	particles.direction = Vector2(0, 0)
	particles.spread = 15.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.7, 0.4, 1.0)
	particles.color_ramp = create_warm_gradient()
	
	# Rotate particles to align with launch direction
	particles.rotation = aim_direction.angle()
	add_child(particles)
	
	# Add camera shake effect
	var cam_shake_intensity = 0.5
	var root = get_tree().root
	if root.has_node("Main/Camera2D"):
		var camera = root.get_node("Main/Camera2D")
		var orig_pos = camera.position
		
		var cam_tween = create_tween()
		cam_tween.tween_property(camera, "position", orig_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10 * cam_shake_intensity, 0.05)
		cam_tween.tween_property(camera, "position", orig_pos, 0.1)
	
	# Play launch sound
	if ResourceLoader.exists("res://assets/sounds/launch.wav"):
		var sound = AudioStreamPlayer.new()
		sound.stream = load("res://assets/sounds/launch.wav")
		sound.volume_db = -10.0
		add_child(sound)
		sound.play()
	
	# Create a timer to fade out the trail
	var timer = Timer.new()
	timer.wait_time = 0.4
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_trail_timer_timeout").bind(trail, particles))
	timer.start()

func _on_trail_timer_timeout(trail, particles):
	# Create fade-out animation
	var tween = create_tween()
	tween.tween_property(trail, "modulate", Color(1, 1, 1, 0), 0.3)
	
	# Stop emitting particles but let existing ones finish their lifetime
	particles.emitting = false
	
	# Create timer to remove the nodes
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.7
	cleanup_timer.one_shot = true
	add_child(cleanup_timer)
	cleanup_timer.connect("timeout", Callable(self, "_cleanup_launch_effect").bind(trail, particles, cleanup_timer))
	cleanup_timer.start()

func _cleanup_launch_effect(trail, particles, timer):
	# Remove all effect nodes
	trail.queue_free()
	particles.queue_free()
	timer.queue_free()

func create_warm_gradient():
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.8, 0.3, 0.8))
	gradient.add_point(0.4, Color(1.0, 0.6, 0.2, 0.6))
	gradient.add_point(0.7, Color(0.9, 0.4, 0.2, 0.3))
	gradient.add_point(1.0, Color(0.7, 0.3, 0.2, 0.0))
	return gradient

func play_launch_sound():
	var sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	
	# Try to load launch sound
	var sound_path = "res://assets/sounds/launch.wav"
	var sound = load(sound_path)
	
	if sound:
		sound_player.stream = sound
		sound_player.pitch_scale = randf_range(0.9, 1.1)  # Slight random pitch
		sound_player.volume_db = -5.0
		sound_player.play()
		
		# Clean up when done
		sound_player.finished.connect(func(): sound_player.queue_free())
	else:
		sound_player.queue_free()

func create_enhanced_crosshair():
	# Create a soft outer glow
	var outer_glow = ColorRect.new()
	var glow_size = 40
	outer_glow.size = Vector2(glow_size, glow_size)
	outer_glow.position = Vector2(-glow_size / 2.0, -glow_size / 2.0)
	
	# Soft warm glow color
	outer_glow.color = Color(1.0, 0.9, 0.7, 0.15)
	add_child(outer_glow)
	
	# Create inner crosshair with fuzzy edge
	var crosshair = Node2D.new()
	crosshair.name = "Crosshair"
	add_child(crosshair)
	
	# Create circular crosshair texture
	var crosshair_size = 24
	var crosshair_image = Image.create(crosshair_size, crosshair_size, false, Image.FORMAT_RGBA8)
	crosshair_image.fill(Color(0,0,0,0))
	
	# Draw a soft circular crosshair
	var center = Vector2(crosshair_size / 2.0, crosshair_size / 2.0)
	var outer_radius = crosshair_size / 2.0
	var inner_radius = crosshair_size / 2.0 - 4
	var center_dot_radius = 3
	
	for x in range(crosshair_size):
		for y in range(crosshair_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			
			# Outer ring with soft edge
			if dist < outer_radius:
				var color = Color(1.0, 0.95, 0.8, 0)
				
				if dist > inner_radius:
					# Outer ring
					var ring_factor = 1.0 - (dist - inner_radius) / (outer_radius - inner_radius)
					color.a = 0.6 * ring_factor
				elif dist < center_dot_radius:
					# Center dot
					var dot_factor = 1.0 - dist / center_dot_radius
					color.a = 0.7 * dot_factor
				
				crosshair_image.set_pixel(x, y, color)
	
	var crosshair_texture = ImageTexture.create_from_image(crosshair_image)
	
	var sprite = Sprite2D.new()
	sprite.texture = crosshair_texture
	crosshair.add_child(sprite)
	
	# Add pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(outer_glow, "scale", Vector2(1.2, 1.2), 1.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(outer_glow, "scale", Vector2(0.9, 0.9), 1.3).set_trans(Tween.TRANS_SINE)
	
	# Add subtle rotation
	var rot_tween = create_tween()
	rot_tween.set_loops()
	rot_tween.tween_property(crosshair, "rotation", PI / 5.0, 3.0).set_trans(Tween.TRANS_SINE)
	rot_tween.tween_property(crosshair, "rotation", -PI / 5.0, 3.0).set_trans(Tween.TRANS_SINE)
	
	# Add particles
	var particles = CPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 2.0
	particles.local_coords = true
	particles.emission_shape = 0  # Sphere shape
	particles.emission_sphere_radius = 5
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 5
	particles.initial_velocity_max = 10
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3
	particles.color = Color(1.0, 0.95, 0.8, 0.5)
	crosshair.add_child(particles)

func create_ambient_glow():
	if not has_node("LauncherCore") or not has_node("LauncherInner"):
		return
		
	var launcher_core = get_node("LauncherCore")
	var launcher_inner = get_node("LauncherInner")
		
	# Create soft ambient glow for launcher core
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
	launcher_core.add_child(ambient_light)
	
	# Breathing animation
	var ambient_tween = create_tween()
	ambient_tween.set_loops()
	ambient_tween.tween_property(ambient_light, "scale", Vector2(1.2, 1.2), 3.0).set_trans(Tween.TRANS_SINE)
	ambient_tween.tween_property(ambient_light, "scale", Vector2(0.8, 0.8), 3.0).set_trans(Tween.TRANS_SINE)
	
	# Add floating ambient particles around launcher
	var ambient_particles = CPUParticles2D.new()
	ambient_particles.name = "AmbientParticles"
	ambient_particles.amount = 15
	ambient_particles.lifetime = 4.0
	ambient_particles.preprocess = 2.0
	ambient_particles.emission_shape = 0  # Sphere shape
	ambient_particles.emission_sphere_radius = 60
	ambient_particles.spread = 180
	ambient_particles.gravity = Vector2.ZERO
	ambient_particles.initial_velocity_min = 2
	ambient_particles.initial_velocity_max = 8
	ambient_particles.scale_amount_min = 2.0
	ambient_particles.scale_amount_max = 5.0
	ambient_particles.color = Color(1.0, 0.85, 0.7, 0.2)
	add_child(ambient_particles)
	
	# Add occasional sparkle effects
	var timer = Timer.new()
	timer.wait_time = 0.8
	timer.autostart = true
	add_child(timer)
	
	timer.timeout.connect(func():
		if randf() > 0.7:  # 30% chance each timer tick
			create_random_sparkle()
	)

func create_random_sparkle():
	var sparkle = Node2D.new()
	add_child(sparkle)
	
	# Random position near launcher
	var angle = randf() * 2 * PI
	var distance = randf_range(20, 60)
	sparkle.position = Vector2(cos(angle) * distance, sin(angle) * distance)
	
	# Create sparkle sprite
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
	
	# Animate and remove
	var tween = create_tween()
	sparkle.scale = Vector2(0.1, 0.1)
	sprite.modulate.a = 0
	
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
		
		# Create nicer dot visual - a circle instead of a square
		var dot_sprite = Sprite2D.new()
		
		# Create soft circular dot
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
		
		# Add subtle pulsing animation for each dot
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(dot_sprite, "scale", Vector2(0.6, 0.6), 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(dot_sprite, "scale", Vector2(0.4, 0.4), 1.0).set_trans(Tween.TRANS_SINE)

func update_cooldown_visual():
	# Enhanced cooldown visual effect with warmer colors
	if $LauncherCore:
		var progress = 1.0 - (cooldown_timer / cooldown_time)
		var cooldown_color = Color(0.6, 0.3, 0.2, 1).lerp(Color(1.0, 0.7, 0.4, 1), progress)
		$LauncherCore.color = cooldown_color
		
		# Add pulse effect when ready
		if progress >= 1.0:
			var pulse_tween = create_tween()
			pulse_tween.tween_property($LauncherCore, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_SINE)
			pulse_tween.tween_property($LauncherCore, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
		
		# Update launcher inner with gradient
		if $LauncherInner:
			$LauncherInner.color = Color(0.8, 0.4, 0.2, 1).lerp(Color(1.0, 0.8, 0.5, 1), progress)

func get_launch_direction() -> Vector2:
	# Return normalized direction vector for launch
	return (get_global_mouse_position() - global_position).normalized()

func get_launch_power() -> float:
	# Return launch power based on distance to mouse
	var distance = global_position.distance_to(get_global_mouse_position())
	return clamp(distance * 2.0, 200.0, 600.0)

func create_launcher_components():
	# Create launcher components with rounded corners for a cozier feel
	
	# Outer component
	var launcher_outer = ColorRect.new()
	launcher_outer.name = "LauncherOuter"
	launcher_outer.size = Vector2(50, 50)
	launcher_outer.position = Vector2(-25, -25)
	launcher_outer.color = Color(0.3, 0.32, 0.35)
	add_child(launcher_outer)
	
	# Add subtle glow effect to launcher outer
	var shadow = Sprite2D.new()
	var shadow_size = 80
	var shadow_image = Image.create(shadow_size, shadow_size, false, Image.FORMAT_RGBA8)
	shadow_image.fill(Color(0,0,0,0))
	
	var center = Vector2(shadow_size / 2.0, shadow_size / 2.0)
	for x in range(shadow_size):
		for y in range(shadow_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist < shadow_size / 2.0:
				var alpha = 0.2 * (1.0 - dist / (shadow_size / 2.0))
				shadow_image.set_pixel(x, y, Color(0.4, 0.45, 0.5, alpha))
	
	var shadow_texture = ImageTexture.create_from_image(shadow_image)
	shadow.texture = shadow_texture
	shadow.z_index = -1
	launcher_outer.add_child(shadow)
	shadow.position = Vector2(launcher_outer.size.x / 2.0, launcher_outer.size.y / 2.0)
	
	# Core component with rounded corners
	var launcher_core = ColorRect.new()
	launcher_core.name = "LauncherCore"
	launcher_core.size = Vector2(40, 40)
	launcher_core.position = Vector2(-20, -20)
	launcher_core.color = Color(0.8, 0.5, 0.3)
	add_child(launcher_core)
	
	# Create rounded corners mask for core
	var core_mask = Sprite2D.new()
	var core_size = 40
	var core_image = Image.create(core_size, core_size, false, Image.FORMAT_RGBA8)
	core_image.fill(Color(1,1,1,1))
	
	center = Vector2(core_size / 2.0, core_size / 2.0)
	var corner_radius = 10
	
	for x in range(core_size):
		for y in range(core_size):
			# Check each corner
			var corners = [
				Vector2(corner_radius, corner_radius),
				Vector2(core_size - corner_radius, corner_radius),
				Vector2(corner_radius, core_size - corner_radius),
				Vector2(core_size - corner_radius, core_size - corner_radius)
			]
			
			var in_corner = false
			for corner in corners:
				if Vector2(x, y).distance_to(corner) > corner_radius:
					# Only consider it a corner if outside the radius
					# and in the corner region
					var is_top_left = x < corner_radius and y < corner_radius
					var is_top_right = x >= core_size - corner_radius and y < corner_radius
					var is_bottom_left = x < corner_radius and y >= core_size - corner_radius
					var is_bottom_right = x >= core_size - corner_radius and y >= core_size - corner_radius
					
					if ((is_top_left and corner == corners[0]) or
						(is_top_right and corner == corners[1]) or
						(is_bottom_left and corner == corners[2]) or
						(is_bottom_right and corner == corners[3])):
						in_corner = true
						break
			
			if in_corner:
				core_image.set_pixel(x, y, Color(0,0,0,0))
	
	var core_texture = ImageTexture.create_from_image(core_image)
	core_mask.texture = core_texture
	launcher_core.add_child(core_mask)
	core_mask.position = Vector2(launcher_core.size.x / 2.0, launcher_core.size.y / 2.0)
	
	# Inner component
	var launcher_inner = ColorRect.new()
	launcher_inner.name = "LauncherInner"
	launcher_inner.size = Vector2(26, 26)
	launcher_inner.position = Vector2(-13, -13)
	launcher_inner.color = Color(0.9, 0.7, 0.4)
	add_child(launcher_inner)
	
	# Create rounded corners mask for inner
	var inner_mask = Sprite2D.new()
	var inner_size = 26
	var inner_image = Image.create(inner_size, inner_size, false, Image.FORMAT_RGBA8)
	inner_image.fill(Color(1,1,1,1))
	
	center = Vector2(inner_size / 2.0, inner_size / 2.0)
	corner_radius = 8
	
	for x in range(inner_size):
		for y in range(inner_size):
			# Check each corner
			var corners = [
				Vector2(corner_radius, corner_radius),
				Vector2(inner_size - corner_radius, corner_radius),
				Vector2(corner_radius, inner_size - corner_radius),
				Vector2(inner_size - corner_radius, inner_size - corner_radius)
			]
			
			var in_corner = false
			for corner in corners:
				if Vector2(x, y).distance_to(corner) > corner_radius:
					# Only consider it a corner if outside the radius
					# and in the corner region
					var is_top_left = x < corner_radius and y < corner_radius
					var is_top_right = x >= inner_size - corner_radius and y < corner_radius
					var is_bottom_left = x < corner_radius and y >= inner_size - corner_radius
					var is_bottom_right = x >= inner_size - corner_radius and y >= inner_size - corner_radius
					
					if ((is_top_left and corner == corners[0]) or
						(is_top_right and corner == corners[1]) or
						(is_bottom_left and corner == corners[2]) or
						(is_bottom_right and corner == corners[3])):
						in_corner = true
						break
			
			if in_corner:
				inner_image.set_pixel(x, y, Color(0,0,0,0))
	
	var inner_texture = ImageTexture.create_from_image(inner_image)
	inner_mask.texture = inner_texture
	launcher_inner.add_child(inner_mask)
	inner_mask.position = Vector2(launcher_inner.size.x / 2.0, launcher_inner.size.y / 2.0)
