extends Node2D

var _blobs: Array = []
const PARALLAX_FACTOR := 0.05


func _ready() -> void:
	z_index = -9  # behind starfield but above clear color
	_generate_blobs()
	queue_redraw()


func _generate_blobs() -> void:
	_blobs.clear()
	var sector: int = int(GameState.get("current_sector")) if GameState.get("current_sector") != null else 1
	var base_color: Color
	match sector:
		1:
			base_color = Color(1.0, 0.8, 0.3, 0.04)  # warm yellows/oranges
		2:
			base_color = Color(0.8, 0.4, 0.9, 0.03)  # contested orange-purple
		3:
			base_color = Color(0.9, 0.2, 0.1, 0.05)  # red/dark
		4:
			base_color = Color(0.3, 0.0, 0.5, 0.06)  # deep purple/void
		_:
			base_color = Color(0.5, 0.5, 0.7, 0.03)

	for i in range(randi_range(3, 5)):
		var pos: Vector2 = Vector2(randf_range(-1200.0, 1200.0), randf_range(-1200.0, 1200.0))
		var radius: float = randf_range(300.0, 800.0)
		var col: Color = base_color
		# Slight color variation per blob
		col.r += randf_range(-0.05, 0.05)
		col.g += randf_range(-0.05, 0.05)
		col.b += randf_range(-0.05, 0.05)
		_blobs.append({"pos": pos, "radius": radius, "color": col})


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam_pos := Vector2.ZERO
	var cameras := get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		cam_pos = cameras[0].global_position

	for blob in _blobs:
		var pos: Vector2 = blob["pos"]
		var offset: Vector2 = cam_pos * PARALLAX_FACTOR
		var draw_pos: Vector2 = pos - offset + cam_pos
		draw_circle(draw_pos, blob["radius"], blob["color"])
