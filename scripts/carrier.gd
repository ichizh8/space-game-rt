extends Node2D

var hp: float = 80.0
var max_hp: float = 80.0
var is_dead := false
var speed: float = 45.0
var difficulty_mult: float = 1.0

signal died()

const AGGRO_RANGE := 600.0
const SPAWN_INTERVAL := 8.0
const MAX_DRONES := 4
const XP_REWARD := 40
const CREDIT_REWARD := 60

enum State { IDLE, ACTIVE }
var state: State = State.IDLE

var _spawn_timer: float = SPAWN_INTERVAL
var _drift_dir: Vector2 = Vector2.RIGHT
var _drift_timer: float = 0.0
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _spawned_drones: Array = []

func _ready() -> void:
	add_to_group("enemies")
	_drift_dir = Vector2.from_angle(randf() * TAU)
	queue_redraw()

func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult
	hp = 80.0 * difficulty_mult
	max_hp = hp


func _process(delta: float) -> void:
	if is_dead:
		if _despawn_timer > 0:
			_despawn_timer -= delta
			if _despawn_timer <= 0:
				call_deferred("queue_free")
		return

	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer <= 0:
			modulate = Color.WHITE

	var player := _get_player()
	if not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)

	# Slow drift
	_drift_timer -= delta
	if _drift_timer <= 0:
		_drift_dir = Vector2.from_angle(randf() * TAU)
		_drift_timer = randf_range(3.0, 6.0)

	match state:
		State.IDLE:
			position += _drift_dir * speed * 0.5 * delta
			if dist < AGGRO_RANGE:
				state = State.ACTIVE
				_spawn_timer = 1.0  # first drone quick

		State.ACTIVE:
			# Slowly orbit player
			var orbit_dir := (global_position - player.global_position).normalized()
			var perp := Vector2(-orbit_dir.y, orbit_dir.x)
			position += (perp + orbit_dir * 0.3) * speed * delta

			_spawn_timer -= delta
			if _spawn_timer <= 0:
				_spawn_timer = SPAWN_INTERVAL
				_clean_drone_list()
				if _spawned_drones.size() < MAX_DRONES:
					call_deferred("_spawn_drone")

			if dist > AGGRO_RANGE * 1.5:
				state = State.IDLE


func _clean_drone_list() -> void:
	var alive: Array = []
	for d in _spawned_drones:
		if is_instance_valid(d) and not d.get("is_dead"):
			alive.append(d)
	_spawned_drones = alive

func _spawn_drone() -> void:
	if is_dead:
		return
	var drone_scene := load("res://scenes/enemy.tscn") as PackedScene
	if not is_instance_valid(drone_scene):
		return
	var drone := drone_scene.instantiate() as Node2D
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(30.0, 60.0)
	drone.global_position = global_position + offset
	drone.set("enemy_type", 1)  # EnemyType.DRONE
	if drone.has_method("setup"):
		drone.setup(difficulty_mult)
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(drone)
		_spawned_drones.append(drone)
	# Notify player
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_float"):
		em.add_float("DRONE!", global_position + Vector2(0, -30), Color(1.0, 0.7, 0.0))

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.12
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
		call_deferred("_die")

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	GameState.record_kill()
	GameState.add_xp(XP_REWARD)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 2.0)
	call_deferred("_spawn_loot")
	_despawn_timer = 2.0
	queue_redraw()
	died.emit()

func _spawn_loot() -> void:
	var loot_scene := load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		GameState.add_credits(CREDIT_REWARD)
		return
	var loot := loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	var cr := int(float(CREDIT_REWARD) * difficulty_mult)
	if loot.has_method("setup"):
		loot.setup(cr, {"scrap": randi_range(4, 8), "ore": randi_range(2, 4)})
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(loot)

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _draw() -> void:
	if is_dead:
		return
	# Fallback: wide flat ship
	var points := PackedVector2Array([
		Vector2(0, -10), Vector2(22, -8), Vector2(24, 0),
		Vector2(22, 8), Vector2(0, 10), Vector2(-22, 8),
		Vector2(-24, 0), Vector2(-22, -8)
	])
	var hull_ratio := hp / max_hp
	var col := Color(0.35 + 0.15 * hull_ratio, 0.35 + 0.15 * hull_ratio, 0.4)
	draw_colored_polygon(points, col)
	# Bay indicators
	draw_circle(Vector2(14, 0), 4.0, Color(0.8, 0.6, 0.1, 0.8))
	draw_circle(Vector2(-14, 0), 4.0, Color(0.8, 0.6, 0.1, 0.8))
	# HP bar
	var bar_w := 30.0 * hull_ratio
	draw_rect(Rect2(-15, -16, 30, 3), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-15, -16, bar_w, 3), Color(0.2, 0.9, 0.3))
