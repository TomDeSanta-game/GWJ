extends Line2D

var max_points = 10
var point_age = 0.1
var parent_node

func _ready():
	parent_node = get_parent()
	z_index = -1

func _process(delta):
	add_point(Vector2.ZERO)
	
	if points.size() > max_points:
		remove_point(0)
		
	for i in range(points.size()):
		points[i] = points[i] - parent_node.linear_velocity * delta * 0.3 