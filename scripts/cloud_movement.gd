extends Node2D

@export var min_scale: float = 0.8
@export var max_scale: float = 1.5
@export var min_speed: float = 10
@export var max_speed: float = 30

var screen_size
var clouds = []
var prev_scroll_y = 0

# Custom cloud class that extends Node2D
class Cloud extends Node2D:
	var speed: float = 20.0
	
	func _init(speed_value: float):
		speed = speed_value

func _ready():
	screen_size = get_viewport_rect().size
	# Reduce number of initial clouds for better performance
	spawn_initial_clouds(4) # Reduced from 6
	
	# Adjust movement calculations less frequently
	var cloud_timer = Timer.new()
	add_child(cloud_timer)
	cloud_timer.wait_time = 0.1
	cloud_timer.autostart = true
	cloud_timer.timeout.connect(check_clouds)

func spawn_initial_clouds(count: int = 4):
	for i in range(count):
		var y_pos = randf_range(0, screen_size.y)
		spawn_cloud(Vector2(randf_range(0, screen_size.x), y_pos))

func spawn_cloud(position: Vector2 = Vector2.ZERO):
	# Create a cloud instance of our custom class
	var scale_val = randf_range(min_scale, max_scale)
	var cloud = Cloud.new(randf_range(min_speed, max_speed) / scale_val)
	
	if position == Vector2.ZERO:
		# Spawn at right side of screen with random y
		position = Vector2(screen_size.x + 50, randf_range(0, screen_size.y))
	
	cloud.position = position
	
	# Assign random properties
	cloud.scale = Vector2(scale_val, scale_val)
	
	# Set z-index based on scale
	cloud.z_index = -10 - int(scale_val * 10)  # Larger clouds further back
	
	# Create cloud visuals
	var cloud_shape = ColorRect.new()
	cloud_shape.size = Vector2(80, 50)
	cloud_shape.position = Vector2(-40, -25)
	cloud_shape.color = Color(1, 1, 1, 0.5)
	cloud.add_child(cloud_shape)
	
	# Simplify cloud visuals
	cloud.modulate.a = 0.8
	if scale_val > 1.2:
		cloud.modulate.a = 0.6
	
	add_child(cloud)
	clouds.append(cloud)
	
	return cloud

func _process(delta):
	# Move each cloud based on its speed
	for cloud in clouds:
		cloud.position.x -= cloud.speed * delta
		
		# Add a slight up/down movement
		var time = Time.get_ticks_msec() / 1000.0
		cloud.position.y += sin(time + cloud.position.x * 0.01) * 0.1

func check_clouds():
	# Clean up clouds that are off-screen
	for i in range(clouds.size() - 1, -1, -1):
		if i >= clouds.size():  # Check if index is still valid
			continue
			
		var cloud = clouds[i]
		if cloud.position.x < -100:
			cloud.queue_free()
			clouds.remove_at(i)
	
	# Maintain a smaller number of clouds for better performance
	if clouds.size() < 4:  # Reduced from 6
		spawn_cloud()
