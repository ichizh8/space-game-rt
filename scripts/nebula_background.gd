extends Node2D

var _blobs: Array = []
var _zone_blobs: Array = []
var _nebula_accents: Array = []
const PARALLAX_FACTOR := 0.05

var current_biome: int = 0
var _last_active_zone: String = ""

# Biome color + density configs: [color, min_blobs, max_blobs, min_radius, max_radius]
const BIOME_CONFIGS: Array = [
	# MIXED (0): blue-grey
	[Color(0.4, 0.6, 0.9, 0.06), 4, 6, 200.0, 500.0],
	# ASTEROID_BELT (1): dusty orange-brown, big sparse
	[Color(0.8, 0.55, 0.2, 0.07), 2, 3, 400.0, 900.0],
	# DEBRIS_FIELD (2): grey-green metallic haze, dense small
	[Color(0.5, 0.55, 0.5, 0.08), 5, 8, 150.0, 350.0],
	# DEEP_SPACE (3): very dark blue near-black, huge faint
	[Color(0.05, 0.05, 0.2, 0.09), 2, 3, 600.0, 1200.0],
	# NEBULA (4): bright purple-pink, vibrant dense
	[Color(0.6, 0.2, 0.9, 0.12), 6, 9, 300.0, 700.0],
]

# Hunting zone overlay configs: [color, min_blobs, max_blobs, min_radius, max_radius]
const ZONE_CONFIGS: Dictionary = {
	"hunt_void_grubs": [Color(0.5, 0.8, 0.2, 0.05), 3, 4, 200.0, 500.0],
	"hunt_skim_rays": [Color(0.1, 0.8, 0.8, 0.06), 3, 4, 400.0, 700.0],
	"hunt_snarlers": [Color(0.9, 0.3, 0.1, 0.06), 4, 6, 150.0, 350.0],
	"hunt_drifters": [Color(0.6, 0.1, 1.0, 0.10), 5, 7, 400.0, 700.0],
	"hunt_feeders": [Color(0.2, 0.9, 0.8, 0.07), 4, 5, 250.0, 500.0],
	"hunt_leviathan": [Color(0.3, 0.0, 0.5, 0.08), 2, 3, 600.0, 1000.0],
}


func _ready() -> void:
	z_index = -9
	_generate_blobs()
	queue_redraw()


func _generate_blobs() -> void:
	_blobs.clear()
	_nebula_accents.clear()
	var cfg: Array = BIOME_CONFIGS[current_biome] if current_biome < BIOME_CONFIGS.size() else BIOME_CONFIGS[0]
	var base_color: Color = cfg[0]
	var blob_count: int = randi_range(int(cfg[1]), int(cfg[2]))
	var min_r: float = float(cfg[3])
	var max_r: float = float(cfg[4])

	for i in range(blob_count):
		var pos: Vector2 = Vector2(randf_range(-1200.0, 1200.0), randf_range(-1200.0, 1200.0))
		var radius: float = randf_range(min_r, max_r)
		var col: Color = base_color
		col.r += randf_range(-0.05, 0.05)
		col.g += randf_range(-0.05, 0.05)
		col.b += randf_range(-0.05, 0.05)
		_blobs.append({"pos": pos, "radius": radius, "color": col})

	# NEBULA biome: extra bright accent circles
	if current_biome == 4:
		for i in range(randi_range(3, 5)):
			var parent_blob: Dictionary = _blobs[randi() % _blobs.size()]
			var offset: Vector2 = Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0))
			var accent_pos: Vector2 = parent_blob["pos"] + offset
			var accent_r: float = randf_range(80.0, 200.0)
			var accent_alpha: float = randf_range(0.04, 0.08)
			var accent_color: Color
			if randf() < 0.5:
				accent_color = Color(0.9, 0.3, 0.7, accent_alpha)  # pink
			else:
				accent_color = Color(0.2, 0.8, 0.9, accent_alpha)  # cyan
			_nebula_accents.append({"pos": accent_pos, "radius": accent_r, "color": accent_color})


func _generate_zone_blobs(zone_id: String) -> void:
	_zone_blobs.clear()
	if zone_id == "" or not ZONE_CONFIGS.has(zone_id):
		return
	var cfg: Array = ZONE_CONFIGS[zone_id]
	var base_color: Color = cfg[0]
	var blob_count: int = randi_range(int(cfg[1]), int(cfg[2]))
	var min_r: float = float(cfg[3])
	var max_r: float = float(cfg[4])

	for i in range(blob_count):
		var pos: Vector2 = Vector2(randf_range(-800.0, 800.0), randf_range(-800.0, 800.0))
		var radius: float = randf_range(min_r, max_r)
		var col: Color = base_color
		col.r += randf_range(-0.03, 0.03)
		col.g += randf_range(-0.03, 0.03)
		col.b += randf_range(-0.03, 0.03)
		_zone_blobs.append({"pos": pos, "radius": radius, "color": col})


func _process(_delta: float) -> void:
	# Check biome from sector_generator/sector_loader
	var sg: Node = get_tree().get_first_node_in_group("sector_generator")
	if is_instance_valid(sg) and sg.get("_current_biome") != null:
		var new_biome: int = int(sg.get("_current_biome"))
		if new_biome != current_biome:
			current_biome = new_biome
			_generate_blobs()

	# Check hunting zone
	var active_zone: String = GameState.active_hunting_zone
	if active_zone != _last_active_zone:
		_last_active_zone = active_zone
		_generate_zone_blobs(active_zone)

	queue_redraw()


func _draw() -> void:
	var cam_pos := Vector2.ZERO
	var cameras := get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		cam_pos = cameras[0].global_position

	# Draw biome blobs
	for blob in _blobs:
		var pos: Vector2 = blob["pos"]
		var offset: Vector2 = cam_pos * PARALLAX_FACTOR
		var draw_pos: Vector2 = pos - offset + cam_pos
		draw_circle(draw_pos, blob["radius"], blob["color"])

	# Draw nebula accent circles
	for accent in _nebula_accents:
		var pos: Vector2 = accent["pos"]
		var offset: Vector2 = cam_pos * PARALLAX_FACTOR
		var draw_pos: Vector2 = pos - offset + cam_pos
		draw_circle(draw_pos, accent["radius"], accent["color"])

	# Draw hunting zone overlay blobs
	for blob in _zone_blobs:
		var pos: Vector2 = blob["pos"]
		var offset: Vector2 = cam_pos * PARALLAX_FACTOR
		var draw_pos: Vector2 = pos - offset + cam_pos
		draw_circle(draw_pos, blob["radius"], blob["color"])
