extends Node2D

var _stars: Array[Vector2] = []
var _star_sizes: Array[float] = []
var _star_colors: Array[Color] = []
var _scroll_speed: float = 0.2
var _offset: Vector2 = Vector2.ZERO
var _viewport_size: Vector2


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_generate_stars()


func _generate_stars() -> void:
	_stars.clear()
	_star_sizes.clear()
	_star_colors.clear()
	var w := _viewport_size.x * 2.0
	var h := _viewport_size.y * 2.0
	for i in range(200):
		_stars.append(Vector2(randf_range(0, w), randf_range(0, h)))
		_star_sizes.append(randf_range(0.8, 2.0))
		var brightness := randf_range(0.4, 1.0)
		_star_colors.append(Color(brightness, brightness, brightness + 0.1, 1.0))


func _process(delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := _viewport_size.x * 2.0
	var h := _viewport_size.y * 2.0
	for i in range(_stars.size()):
		var pos := Vector2(
			fmod(_stars[i].x, w),
			fmod(_stars[i].y, h)
		) - Vector2(_viewport_size.x * 0.5, _viewport_size.y * 0.5)
		draw_circle(pos, _star_sizes[i], _star_colors[i])
