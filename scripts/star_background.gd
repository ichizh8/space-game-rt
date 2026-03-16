extends Node2D

var _stars: Array[Vector2] = []
var _star_sizes: Array[float] = []
var _star_colors: Array[Color] = []
var _ready_done: bool = false


func _ready() -> void:
	call_deferred("_init_stars")


func _init_stars() -> void:
	# Use design resolution to ensure full coverage regardless of when viewport reports size
	var vp := Vector2(390, 844)
	_stars.clear()
	_star_sizes.clear()
	_star_colors.clear()
	for i in range(220):
		_stars.append(Vector2(randf_range(-20, vp.x + 20), randf_range(-20, vp.y + 20)))
		_star_sizes.append(randf_range(0.8, 2.0))
		var brightness := randf_range(0.5, 1.0)
		_star_colors.append(Color(brightness, brightness, brightness + 0.05, 1.0))
	_ready_done = true
	queue_redraw()


func _process(_delta: float) -> void:
	pass  # Stars are static — no redraw needed every frame


func _draw() -> void:
	if not _ready_done:
		return
	for i in range(_stars.size()):
		draw_circle(_stars[i], _star_sizes[i], _star_colors[i])
