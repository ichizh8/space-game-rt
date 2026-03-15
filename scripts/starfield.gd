extends Node2D

# Each layer: array of {pos: Vector2, size: float, brightness: float}
var _layers: Array = []

const LAYER_CONFIG := [
	{"count": 120, "parallax": 0.05, "size_range": [0.6, 1.0], "brightness": 0.35},  # far, slow
	{"count": 80,  "parallax": 0.12, "size_range": [0.8, 1.5], "brightness": 0.55},  # mid
	{"count": 40,  "parallax": 0.22, "size_range": [1.2, 2.2], "brightness": 0.85},  # near, fast
]
const FIELD_SIZE := 2400.0  # world units covered


func _ready() -> void:
	z_index = -10
	_generate_stars()


func _generate_stars() -> void:
	_layers.clear()
	for _cfg in LAYER_CONFIG:
		var cfg: Dictionary = _cfg
		var stars: Array = []
		for _i in range(cfg["count"]):
			var sr: Array = cfg["size_range"]
			stars.append({
				"pos": Vector2(randf() * FIELD_SIZE - FIELD_SIZE * 0.5,
				               randf() * FIELD_SIZE - FIELD_SIZE * 0.5),
				"size": randf_range(sr[0], sr[1]),
				"brightness": randf_range(cfg["brightness"] * 0.7, cfg["brightness"] * 1.3),
			})
		_layers.append({"stars": stars, "parallax": cfg["parallax"]})


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam_pos := Vector2.ZERO
	# Get camera position from the scene's Camera2D
	var cameras := get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		cam_pos = cameras[0].global_position
	# Fallback: find Camera2D in scene
	if cam_pos == Vector2.ZERO:
		var cam := get_tree().get_first_node_in_group("camera")
		if not is_instance_valid(cam):
			# Try finding Camera2D directly
			var root := get_tree().current_scene
			if is_instance_valid(root):
				for child in root.get_children():
					if child is Camera2D:
						cam_pos = child.global_position
						break

	for layer_data in _layers:
		var parallax: float = layer_data["parallax"]
		var offset := cam_pos * parallax
		for star in layer_data["stars"]:
			var spos: Vector2 = star["pos"]
			var sbright: float = star["brightness"]
			var ssize: float = star["size"]
			# Wrap star position so they tile around camera
			var sx: float = fmod(spos.x - offset.x + FIELD_SIZE * 2.0, FIELD_SIZE) - FIELD_SIZE * 0.5 + cam_pos.x
			var sy: float = fmod(spos.y - offset.y + FIELD_SIZE * 2.0, FIELD_SIZE) - FIELD_SIZE * 0.5 + cam_pos.y
			var col := Color(sbright, sbright, sbright + 0.1, 1.0)
			if ssize > 1.5:
				draw_circle(Vector2(sx, sy), ssize, col)
			else:
				draw_rect(Rect2(sx - ssize * 0.5, sy - ssize * 0.5, ssize, ssize), col)
