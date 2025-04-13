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

func _ready():  
	ensure_launcher_parts()
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
	
	
	if not has_node("LauncherInner"):
		
		pass

func _process(delta):  
	
	if not can_launch:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_launch = true
			cooldown_timer = 0.0
			
		
		update_cooldown_visual()
	
	
	var mouse_pos = get_global_mouse_position()
	
	
	var crosshair = get_node_or_null("Crosshair")
	if crosshair:
		
		crosshair.global_position = crosshair.global_position.lerp(mouse_pos, 0.2)
		
		
		crosshair_rotation += delta * 0.5
		var inner_crosshair = crosshair.get_child(1) if crosshair.get_child_count() > 1 else crosshair.get_child(0) if crosshair.get_child_count() > 0 else null
		if inner_crosshair:
			inner_crosshair.rotation = crosshair_rotation
	
	
	if crosshair:
		aim_direction = (crosshair.global_position - global_position).normalized()
		
		
		if has_node("LauncherDirection"):
			$LauncherDirection.rotation = aim_direction.angle()
	
	
	update_trajectory()
	
	
	if Input.is_action_just_pressed("fire"):
		if can_launch and current_shape != null:
			launch_shape()


func _input(event):
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if can_launch and current_shape != null:
				launch_shape()

func launch_shape():
	
	add_launch_effect()
		
	
	current_shape.apply_central_impulse(aim_direction * launch_speed)
	current_shape.set_launched()
		
	
	can_launch = false
	cooldown_timer = cooldown_time
		
	
	play_launch_sound()
		
	
	var launched_shape = current_shape
	current_shape = null
		
	
	spawn_current_shape()
	spawn_next_shape()

func update_trajectory():
	var start_pos = global_position
	var vel = aim_direction * launch_speed
	var gravity = Vector2(0, 980)  
	var time_step = 0.15  
	
	for i in range(max_trajectory_points):
		var time = time_step * i
		var pos = start_pos + vel * time + 0.5 * gravity * time * time
		
		
		if i < trajectory_points.size() and trajectory_points[i] != null:
			trajectory_points[i].global_position = pos
			
			
			var inner_point = trajectory_points[i].get_child(0) if trajectory_points[i].get_child_count() > 0 else null
			if inner_point:
				var scale_pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005 + i * 0.3) * 0.2
				inner_point.scale = Vector2(scale_pulse, scale_pulse)
				
				
				var fade = i / float(max_trajectory_points)
				var alpha = 0.8 - (i * 0.1)
				
				
				if inner_point.get_child_count() > 0 and inner_point.get_child(0) != null:
					inner_point.get_child(0).modulate = Color(1.0, 0.9 - fade * 0.2, 0.7 - fade * 0.3, alpha)

func spawn_current_shape():
	if current_shape:
		current_shape.queue_free()
	
	current_shape = shape_scene.instantiate()
	current_shape.position = Vector2.ZERO
	add_child(current_shape)
	
	
	current_shape.scale = Vector2(0.1, 0.1)
	var tween = safe_tween(current_shape)
	if tween:  
		tween.tween_property(current_shape, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	
	var glow = CPUParticles2D.new()
	glow.amount = 15
	glow.lifetime = 1.0
	glow.local_coords = true
	glow.emission_shape = 0  
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
	next_shape.position = Vector2(0, 50)  
	next_shape.scale = Vector2(0.5, 0.5)  
	add_child(next_shape)
	
	
	var preview_container = Node2D.new()
	preview_container.name = "PreviewContainer"
	preview_container.position = next_shape.position
	add_child(preview_container)
	
	
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
	
	
	var sparkles = CPUParticles2D.new()
	sparkles.amount = 5
	sparkles.lifetime = 1.5
	sparkles.emission_shape = 0  
	sparkles.emission_sphere_radius = 30
	sparkles.local_coords = true
	sparkles.gravity = Vector2.ZERO
	sparkles.initial_velocity_min = 2
	sparkles.initial_velocity_max = 5
	sparkles.scale_amount_min = 1.0
	sparkles.scale_amount_max = 2.5
	sparkles.color = Color(1.0, 0.95, 0.9, 0.4)
	preview_container.add_child(sparkles)
	
	
	var preview_label = Label.new()
	preview_label.text = "Next"
	preview_label.position = Vector2(-20, -40)
	preview_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8, 0.6))
	preview_label.add_theme_font_size_override("font_size", 12)
	preview_container.add_child(preview_label)
	
	
	next_shape.modulate.a = 0
	var tween = safe_tween(next_shape)
	if tween:  
		tween.tween_property(next_shape, "modulate:a", 0.7, 0.5).set_trans(Tween.TRANS_SINE)
	
	
	var rotation_tween = safe_tween(next_shape)
	if rotation_tween:  
		rotation_tween.set_loops(0)  
		rotation_tween.tween_property(next_shape, "rotation", PI / 8.0, 3.0).set_trans(Tween.TRANS_SINE)
		rotation_tween.tween_property(next_shape, "rotation", -PI / 8.0, 3.0).set_trans(Tween.TRANS_SINE)
	
	
	var glow_tween = safe_tween(preview_glow)
	if glow_tween:  
		glow_tween.set_loops(0)  
		glow_tween.tween_property(preview_glow, "scale", Vector2(1.2, 1.2), 1.5).set_trans(Tween.TRANS_SINE)
		glow_tween.tween_property(preview_glow, "scale", Vector2(0.9, 0.9), 1.5).set_trans(Tween.TRANS_SINE)

func add_launch_effect():
	
	var trail = Line2D.new()
	trail.name = "LaunchTrail"
	trail.width = 12.0
	trail.default_color = Color(1.0, 0.7, 0.3, 0.7)
	trail.gradient = create_warm_gradient()
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	
	
	var start_point = Vector2.ZERO
	var end_point = aim_direction * 150
	trail.points = [start_point, end_point]
	
	
	var particles = CPUParticles2D.new()
	particles.name = "LaunchParticles"
	particles.amount = 40
	particles.lifetime = 0.6
	particles.explosiveness = 0.6
	particles.emission_shape = 1  
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
	
	
	particles.rotation = aim_direction.angle()
	add_child(particles)
	
	
	var cam_shake_intensity = 0.5
	var root = get_tree().root
	if root.has_node("Main/Camera2D"):
		var camera = root.get_node("Main/Camera2D")
		var orig_pos = camera.position
		
		var cam_tween = safe_tween(camera)
		if cam_tween:  
			cam_tween.tween_property(camera, "position", orig_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10 * cam_shake_intensity, 0.05)
			cam_tween.tween_property(camera, "position", orig_pos, 0.1)
	
	
	if ResourceLoader.exists("res:
		var sound = AudioStreamPlayer.new()
		sound.stream = load("res:
		sound.volume_db = -10.0
		add_child(sound)
		sound.play()
	
	
	var timer = Timer.new()
	timer.wait_time = 0.4
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_trail_timer_timeout").bind(trail, particles))
	timer.start()

func _on_trail_timer_timeout(trail, particles):
	
	var tween = safe_tween(trail)
	if tween:  
		tween.tween_property(trail, "modulate", Color(1, 1, 1, 0), 0.3)
	
	
	particles.emitting = false
	
	
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.7
	cleanup_timer.one_shot = true
	add_child(cleanup_timer)
	cleanup_timer.connect("timeout", Callable(self, "_cleanup_launch_effect").bind(trail, particles, cleanup_timer))
	cleanup_timer.start()

func _cleanup_launch_effect(trail, particles, timer):
	
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
	
	
	var sound_path = "res:
	var sound = load(sound_path)
	
	if sound:
		sound_player.stream = sound
		sound_player.pitch_scale = randf_range(0.9, 1.1)  
		sound_player.volume_db = -5.0
		sound_player.play()
		
		
		sound_player.finished.connect(func(): sound_player.queue_free())
	else:
		sound_player.queue_free()

func create_enhanced_crosshair():
	
	var outer_glow = ColorRect.new()
	var glow_size = 40
	outer_glow.size = Vector2(glow_size, glow_size)
	outer_glow.position = Vector2(-glow_size / 2.0, -glow_size / 2.0)
	
	
	outer_glow.color = Color(1.0, 0.9, 0.7, 0.15)
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
				var color = Color(1.0, 0.95, 0.8, 0)
				
				if dist > inner_radius:
					
					var ring_factor = 1.0 - (dist - inner_radius) / (outer_radius - inner_radius)
					color.a = 0.6 * ring_factor
				elif dist < center_dot_radius:
					
					var dot_factor = 1.0 - dist / center_dot_radius
					color.a = 0.7 * dot_factor
				
				crosshair_image.set_pixel(x, y, color)
	
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
	particles.emission_shape = 0  
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
	ambient_particles.emission_shape = 0  
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

func update_cooldown_visual():
	
	if $LauncherCore:
		var progress = 1.0 - (cooldown_timer / cooldown_time)
		var cooldown_color = Color(0.6, 0.3, 0.2, 1).lerp(Color(1.0, 0.7, 0.4, 1), progress)
		$LauncherCore.color = cooldown_color
		
		
		if progress >= 1.0:
			var pulse_tween = safe_tween($LauncherCore)
			if pulse_tween:  
				pulse_tween.tween_property($LauncherCore, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_SINE)
				pulse_tween.tween_property($LauncherCore, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
		
		
		if $LauncherInner:
			$LauncherInner.color = Color(0.8, 0.4, 0.2, 1).lerp(Color(1.0, 0.8, 0.5, 1), progress)

func get_launch_direction() -> Vector2:
	
	return (get_global_mouse_position() - global_position).normalized()

func get_launch_power() -> float:
	
	var distance = global_position.distance_to(get_global_mouse_position())
	return clamp(distance * 2.0, 200.0, 600.0)

func create_launcher_components():
	
	
	
	var launcher_outer = Node2D.new()
	launcher_outer.name = "LauncherOuter"
	add_child(launcher_outer)
	
	
	var outer_circle = Sprite2D.new()
	var circle_size = 80
	var circle_img = Image.create(circle_size, circle_size, false, Image.FORMAT_RGBA8)
	circle_img.fill(Color(0,0,0,0))
	
	var center = Vector2(circle_size/2, circle_size/2)
	var radius = circle_size/2
	
	for x in range(circle_size):
		for y in range(circle_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var gradient_factor = 1.0 - (dist / radius)
				var color = Color(0.98, 0.92, 0.85, 1.0)  
				circle_img.set_pixel(x, y, color)
	
	outer_circle.texture = ImageTexture.create_from_image(circle_img)
	launcher_outer.add_child(outer_circle)
	
	
	var glow = Sprite2D.new()
	var glow_size = 100
	var glow_img = Image.create(glow_size, glow_size, false, Image.FORMAT_RGBA8)
	glow_img.fill(Color(0,0,0,0))
	
	center = Vector2(glow_size/2, glow_size/2)
	radius = glow_size/2
	
	for x in range(glow_size):
		for y in range(glow_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var alpha = 0.3 * (1.0 - pow(dist / radius, 1.5))
				glow_img.set_pixel(x, y, Color(0.98, 0.85, 0.7, alpha))
	
	glow.texture = ImageTexture.create_from_image(glow_img)
	glow.z_index = -1
	launcher_outer.add_child(glow)
	
	
	var launcher_core = Node2D.new()
	launcher_core.name = "LauncherCore"
	launcher_outer.add_child(launcher_core)
	
	var core_circle = Sprite2D.new()
	var core_size = 60
	var core_img = Image.create(core_size, core_size, false, Image.FORMAT_RGBA8)
	core_img.fill(Color(0,0,0,0))
	
	center = Vector2(core_size/2, core_size/2)
	radius = core_size/2
	
	for x in range(core_size):
		for y in range(core_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var gradient_factor = 1.0 - (dist / radius)
				var color = Color(0.98, 0.8, 0.65, 1.0)  
				core_img.set_pixel(x, y, color)
	
	core_circle.texture = ImageTexture.create_from_image(core_img)
	launcher_core.add_child(core_circle)
	
	
	var launcher_inner = Node2D.new()
	launcher_inner.name = "LauncherInner"
	launcher_core.add_child(launcher_inner)
	
	var inner_circle = Sprite2D.new()
	var inner_size = 40
	var inner_img = Image.create(inner_size, inner_size, false, Image.FORMAT_RGBA8)
	inner_img.fill(Color(0,0,0,0))
	
	center = Vector2(inner_size/2, inner_size/2)
	radius = inner_size/2
	
	for x in range(inner_size):
		for y in range(inner_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < radius:
				var gradient_factor = 1.0 - (dist / radius)
				var color = Color(0.99, 0.92, 0.82, 1.0)  
				inner_img.set_pixel(x, y, color)
	
	inner_circle.texture = ImageTexture.create_from_image(inner_img)
	launcher_inner.add_child(inner_circle)
	
	
	add_launcher_decorations(launcher_inner)
	
	
	var pulse_tween = safe_tween(launcher_outer)
	if pulse_tween:
		pulse_tween.set_loops(0)  
		pulse_tween.tween_property(launcher_outer, "scale", Vector2(1.05, 1.05), 1.5).set_trans(Tween.TRANS_SINE)
		pulse_tween.tween_property(launcher_outer, "scale", Vector2(0.98, 0.98), 1.5).set_trans(Tween.TRANS_SINE)

func add_launcher_decorations(parent):
	
	
	
	var heart = Node2D.new()
	heart.position = Vector2(0, -5)
	parent.add_child(heart)
	
	
	var heart_tex = Sprite2D.new()
	heart.add_child(heart_tex)
	
	
	var heart_size = 16
	var heart_img = Image.create(heart_size, heart_size, false, Image.FORMAT_RGBA8)
	heart_img.fill(Color(0,0,0,0))
	
	
	var center_x = heart_size / 2
	var center_y = heart_size / 2
	
	for x in range(heart_size):
		for y in range(heart_size):
			var dx = (x - center_x) / float(heart_size)
			var dy = (y - center_y) / float(heart_size)
			
			
			var inside = pow(dx, 2) + pow(dy - 0.5 * sqrt(abs(dx)), 2) < 0.3
			
			if inside:
				heart_img.set_pixel(x, y, Color(0.95, 0.65, 0.65, 0.7))
	
	heart_tex.texture = ImageTexture.create_from_image(heart_img)
	
	
	var sparkles = CPUParticles2D.new()
	sparkles.amount = 5
	sparkles.lifetime = 2.0
	sparkles.preprocess = 1.0
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 25
	sparkles.gravity = Vector2(0, 0)
	sparkles.initial_velocity_min = 1
	sparkles.initial_velocity_max = 3
	sparkles.scale_amount_min = 1.0
	sparkles.scale_amount_max = 2.0
	sparkles.color = Color(1.0, 0.98, 0.9, 0.6)
	parent.add_child(sparkles)
	
	
	var heart_tween = safe_tween(heart)
	if heart_tween:
		heart_tween.set_loops(0)  
		heart_tween.tween_property(heart, "scale", Vector2(1.1, 1.1), 1.2).set_trans(Tween.TRANS_SINE)
		heart_tween.tween_property(heart, "scale", Vector2(0.9, 0.9), 1.2).set_trans(Tween.TRANS_SINE)


func safe_tween(target_node: Node = null) -> Tween:
	var tween = create_tween()
	if tween == null:
		
		if target_node:
			tween = target_node.create_tween()
	
	return tween
