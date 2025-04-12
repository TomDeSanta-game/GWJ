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

func _ready():  # Called when node enters scene tree
	# Create enhanced crosshair
	var crosshair = Node2D.new()
	crosshair.name = "Crosshair"
	crosshair.z_index = 10
	add_child(crosshair)
	
	# Create outer glow
	var outer_glow = ColorRect.new()
	outer_glow.size = Vector2(80, 80)
	outer_glow.position = Vector2(-40, -40)
	outer_glow.color = Color(1.0, 0.8, 0.6, 0.3)
	crosshair.add_child(outer_glow)
	
	# Create inner crosshair
	var inner_crosshair = Sprite2D.new()
	
	# Create a more visually appealing crosshair with rounded style
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw circle outline with fuzzy edge
	var center = Vector2(32, 32)
	var radius = 24
	var outline_color = Color(1.0, 0.8, 0.6, 0.9)
	var outline_width = 3
	
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x, y).distance_to(center)
			if dist > radius - outline_width && dist < radius + outline_width:
				# Make the edge fuzzy for a softer look
				var alpha = 1.0 - abs(dist - radius) / outline_width
				var pixel_color = outline_color
				pixel_color.a *= alpha
				img.set_pixel(x, y, pixel_color)
	
	# Add dots instead of crosshairs for a cozier look
	for i in range(8):
		var angle = i * PI / 4
		var dot_pos = center + Vector2(cos(angle), sin(angle)) * (radius * 0.6)
		var dot_radius = 3
		
		for x in range(max(0, dot_pos.x - dot_radius), min(64, dot_pos.x + dot_radius + 1)):
			for y in range(max(0, dot_pos.y - dot_radius), min(64, dot_pos.y + dot_radius + 1)):
				var dot_dist = Vector2(x, y).distance_to(dot_pos)
				if dot_dist <= dot_radius:
					var alpha = 1.0 - dot_dist / dot_radius
					var pixel_color = outline_color
					pixel_color.a *= alpha
					img.set_pixel(x, y, pixel_color)
	
	inner_crosshair.texture = ImageTexture.create_from_image(img)
	inner_crosshair.scale = Vector2(0.9, 0.9)
	inner_crosshair.modulate = Color(1, 0.9, 0.8, 0.9)
	crosshair.add_child(inner_crosshair)
	
	# Add pulsing effect to crosshair
	var pulse = CPUParticles2D.new()
	pulse.amount = 12
	pulse.lifetime = 1.0
	pulse.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	pulse.emission_sphere_radius = 30
	pulse.spread = 180
	pulse.gravity = Vector2.ZERO
	pulse.initial_velocity_min = 5
	pulse.initial_velocity_max = 10
	pulse.scale_amount_min = 2
	pulse.scale_amount_max = 4
	pulse.color = Color(1.0, 0.9, 0.7, 0.3)
	crosshair.add_child(pulse)
	
	# Create enhanced trajectory points
	for i in range(max_trajectory_points):
		var point = Node2D.new()
		point.z_index = 5
		add_child(point)
		
		# Create a circle for trajectory points instead of squares
		var inner_point = Node2D.new()
		point.add_child(inner_point)
		
		var circle = Sprite2D.new()
		var size = 14 - i * 1.2
		
		# Create round dot image
		var dot_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		dot_img.fill(Color(0, 0, 0, 0))
		
		var dot_center = Vector2(8, 8)
		var dot_radius = 6
		for x in range(16):
			for y in range(16):
				var dist = Vector2(x, y).distance_to(dot_center)
				if dist <= dot_radius:
					# Create soft-edged dot
					var alpha = 1.0 - (dist / dot_radius) * 0.8
					var color = Color(1.0, 0.9, 0.7, alpha)
					dot_img.set_pixel(x, y, color)
		
		circle.texture = ImageTexture.create_from_image(dot_img)
		circle.scale = Vector2(size/16.0, size/16.0)
		inner_point.add_child(circle)
		
		trajectory_points.append(point)
	
	# Make sure required launcher parts exist
	ensure_launcher_parts()
	
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
		var launcher_core = ColorRect.new()
		launcher_core.name = "LauncherCore"
		launcher_core.size = Vector2(30, 30)
		launcher_core.position = Vector2(-15, -15)
		launcher_core.color = Color(1.0, 0.7, 0.4, 1.0)
		launcher_core.z_index = 2
		add_child(launcher_core)
	
	# Create LauncherInner if needed
	if not has_node("LauncherInner"):
		var launcher_inner = ColorRect.new()
		launcher_inner.name = "LauncherInner"
		launcher_inner.size = Vector2(20, 20)
		launcher_inner.position = Vector2(-10, -10)
		launcher_inner.color = Color(1.0, 0.8, 0.5, 1.0)
		launcher_inner.z_index = 3
		add_child(launcher_inner)

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
	glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
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
	
	# Apply enhanced effects
	next_shape.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(next_shape, "modulate:a", 0.7, 0.5).set_trans(Tween.TRANS_SINE)

func launch_shape():
	# Can't launch if on cooldown
	if not can_launch:
		return
	
	# Set cooldown
	can_launch = false
	cooldown_timer = cooldown_time
	
	# Get direction towards crosshair
	var vel = aim_direction * launch_speed
	
	# Configure physics
	current_shape.freeze = false
	current_shape.gravity_scale = 1.0
	current_shape.linear_velocity = vel
	
	# Make visible
	current_shape.visible = true
	
	# Remove from launcher's children and add to scene tree
	var current_global_pos = current_shape.global_position
	var current_shape_ref = current_shape
	remove_child(current_shape)
	get_tree().root.add_child(current_shape_ref)
	current_shape_ref.global_position = current_global_pos
	
	# Add enhanced launch effect
	add_launch_effect(current_shape_ref.global_position, vel)
	
	# Move next shape to current
	current_shape = next_shape
	next_shape = null
	
	# Enhanced tween for next shape movement
	var tween = create_tween()
	tween.tween_property(current_shape, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(current_shape, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(current_shape, "modulate:a", 1.0, 0.2)
	
	# Create new next shape
	spawn_next_shape()
	
	# Play launch sound with improved error handling
	play_launch_sound()

func play_launch_sound():
	var sound = AudioStreamPlayer.new()
	sound.volume_db = -5
	sound.pitch_scale = randf_range(0.95, 1.05)
	add_child(sound)
	
	# List of possible sound file paths to try
	var sound_paths = [
		"res://assets/sounds/launch.wav",
		"res://assets/audio/launch.wav",
		"res://sounds/launch.wav"
	]
	
	var sound_loaded = false
	# Try each possible path
	for path in sound_paths:
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream:
				sound.stream = stream
				sound.play()
				sound_loaded = true
				# Auto-cleanup when sound is done playing
				sound.connect("finished", sound.queue_free)
				break
	
	# If no sound could be loaded, clean up the player
	if not sound_loaded:
		sound.queue_free()
		print("Warning: Could not load launch sound from any path")

func add_launch_effect(position, velocity):
	# Create enhanced blast particle effect
	var particles = CPUParticles2D.new()
	get_tree().root.add_child(particles)
	particles.position = position
	particles.amount = 25  # Increased amount
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.one_shot = true
	particles.emitting = true
	particles.direction = -velocity.normalized()
	particles.spread = 40
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 70
	particles.initial_velocity_max = 170
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(1.0, 0.8, 0.5, 0.7)
	
	# Create shockwave effect - round instead of square
	var shockwave = Node2D.new()
	get_tree().root.add_child(shockwave)
	shockwave.position = position
	
	# Create circular shockwave
	var shockwave_sprite = Sprite2D.new()
	var shock_img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	shock_img.fill(Color(0, 0, 0, 0))
	
	var shock_center = Vector2(50, 50)
	var shock_radius = 48
	for x in range(100):
		for y in range(100):
			var dist = Vector2(x, y).distance_to(shock_center)
			if dist <= shock_radius && dist >= shock_radius - 5:
				var alpha = 1.0 - abs(dist - (shock_radius - 2.5)) / 2.5
				shock_img.set_pixel(x, y, Color(1.0, 0.8, 0.5, 0.6 * alpha))
	
	shockwave_sprite.texture = ImageTexture.create_from_image(shock_img)
	shockwave.add_child(shockwave_sprite)
	
	var shockwave_tween = create_tween()
	shockwave_tween.tween_property(shockwave, "scale", Vector2(3, 3), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	shockwave_tween.parallel().tween_property(shockwave_sprite, "modulate:a", 0.0, 0.3)
	shockwave_tween.tween_callback(shockwave.queue_free)
	
	# Auto-remove particles when done
	var timer = Timer.new()
	particles.add_child(timer)
	timer.wait_time = 0.6
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	timer.start()

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
