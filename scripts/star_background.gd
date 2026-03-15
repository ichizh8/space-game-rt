extends ParallaxLayer

var _stars: Array[Vector2] = []
var _star_sizes: Array[float] = []
var _star_colors: Array[Color] = []


func _ready() -> void:
	# Generate random star positions
	for i in range(150):
		_stars.append(Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000)))
		_star_sizes.append(randf_range(1.0, 2.5))
		var brightness := randf_range(0.5, 1.0)
		_star_colors.append(Color(brightness, brightness, brightness, brightness))
	queue_redraw()


func _draw() -> void:
	for i in range(_stars.size()):
		draw_circle(_stars[i], _star_sizes[i], _star_colors[i])
