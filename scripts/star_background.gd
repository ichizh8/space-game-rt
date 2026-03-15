extends Node2D

var _stars: Array[Vector2] = []
var _star_sizes: Array[float] = []
var _star_colors: Array[Color] = []
var _ready_done: bool = false


func _ready() -> void:
	call_deferred("_init_stars")


func _init_stars() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0:
		vp = Vector2(390, 844)
	var w := vp.x
	var h := vp.y
	for i in range(200):
		_stars.append(Vector2(randf_range(0, w), randf_range(0, h)))
		_star_sizes.append(randf_range(0.8, 2.0))
		var brightness := randf_range(0.4, 1.0)
		_star_colors.append(Color(brightness, brightness, brightness + 0.1, 1.0))
	_ready_done = true
	queue_redraw()


func _draw() -> void:
	if not _ready_done:
		return
	for i in range(_stars.size()):
		draw_circle(_stars[i], _star_sizes[i], _star_colors[i])
