extends Node2D

var speed: float = 0.0
var hp: float = 80.0
var max_hp: float = 80.0
var is_dead := false
var _target_pos: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0

const AGGRO_PIRATE_RANGE := 300.0


func _ready() -> void:
	add_to_group("npc_freighters")
	speed = randf_range(55.0, 70.0)
	_pick_station_target()
	queue_redraw()


func _process(delta: float) -> void:
	if _despawn_timer > 0.0:
		_despawn_timer -= delta
		if _despawn_timer <= 0.0:
			call_deferred("queue_free")
			return

	if is_dead:
		return

	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer <= 0:
			modulate = Color.WHITE

	# Move toward target station
	var dir: Vector2 = (_target_pos - global_position).normalized()
	position += dir * speed * delta
	rotation = dir.angle() + PI / 2.0

	# Arrived at target — pick new one
	if global_position.distance_to(_target_pos) < 60.0:
		_pick_station_target()

	queue_redraw()


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.1
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
		call_deferred("_die")


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 1.5)
		em.add_float("FREIGHTER DESTROYED", global_position + Vector2(0, -20), Color.ORANGE)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.5


func _spawn_loot() -> void:
	var loot_scene: PackedScene = load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		return
	var drop_count: int = randi_range(8, 15)
	var types: Array[String] = ["ore", "crystal", "scrap"]
	var res: Dictionary = {}
	for i in range(drop_count):
		var t: String = types[randi() % types.size()]
		res[t] = int(res.get(t, 0)) + 1
	var loot: Node2D = loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	if loot.has_method("setup"):
		loot.setup(randi_range(30, 60), res)
	get_parent().add_child(loot)


func _pick_station_target() -> void:
	var stations := get_tree().get_nodes_in_group("stations")
	if stations.is_empty():
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 1500.0
		return
	# Pick a random station
	var idx: int = randi() % stations.size()
	var station: Node2D = stations[idx] as Node2D
	if is_instance_valid(station):
		_target_pos = station.global_position
	else:
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 1500.0


func _draw() -> void:
	if is_dead:
		return
	# Rectangular freighter shape
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -14), Vector2(8, -14), Vector2(10, 14), Vector2(-10, 14)
	]), Color(0.55, 0.6, 0.65, 0.9))
	# Cargo bay stripe
	draw_rect(Rect2(-6, -4, 12, 8), Color(0.4, 0.45, 0.5, 0.8))
	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-18, -18), "FREIGHTER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.8, 0.9, 0.6))
	# HP bar when damaged
	if hp < max_hp:
		var bw := 30.0
		var pct: float = hp / max_hp
		draw_rect(Rect2(-bw / 2.0, -24, bw, 3), Color(0.2, 0.2, 0.2, 0.7))
		draw_rect(Rect2(-bw / 2.0, -24, bw * pct, 3), Color(0.2, 0.9, 0.2))
