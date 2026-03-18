extends Node2D

enum State { TRAVELING, MINING, RETURNING, FLEEING }

var state: State = State.TRAVELING
var speed: float = 0.0
var hp: float = 60.0
var max_hp: float = 60.0
var is_dead := false
var _target_pos: Vector2 = Vector2.ZERO
var _mining_timer: float = 0.0
var _mining_duration: float = 0.0
var _state_timer: float = 0.0
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false
var _sprite_tex: Texture2D = null
var _sprite_size: float = 40.0
var _sprite_rot_offset: float = 1.570796

const FLEE_SPEED := 100.0
const FLEE_RANGE := 150.0
const MINING_RANGE := 40.0
const STATION_RANGE := 60.0


func _ready() -> void:
	add_to_group("npc_miners")
	add_to_group("npc_ships")
	speed = randf_range(40.0, 60.0)
	_pick_asteroid_target()
	_setup_sprite()
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

	# Check for nearby enemies — flee if close
	var enemies := get_tree().get_nodes_in_group("enemies")
	var flee_from: Node2D = null
	var closest_dist: float = FLEE_RANGE
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			flee_from = e

	if is_instance_valid(flee_from) and state != State.FLEEING:
		state = State.FLEEING
		_state_timer = 0.0

	match state:
		State.TRAVELING:
			_do_travel(delta)
		State.MINING:
			_do_mining(delta)
		State.RETURNING:
			_do_return(delta)
		State.FLEEING:
			_do_flee(delta, flee_from)

	queue_redraw()


func _do_travel(delta: float) -> void:
	var dir: Vector2 = (_target_pos - global_position).normalized()
	position += dir * speed * delta
	rotation = dir.angle() + PI / 2.0
	if global_position.distance_to(_target_pos) < MINING_RANGE:
		state = State.MINING
		_mining_timer = 0.0
		_mining_duration = randf_range(8.0, 12.0)


func _do_mining(_delta: float) -> void:
	_mining_timer += _delta
	if _mining_timer >= _mining_duration:
		state = State.RETURNING
		_pick_station_target()


func _do_return(delta: float) -> void:
	var dir: Vector2 = (_target_pos - global_position).normalized()
	position += dir * speed * delta
	rotation = dir.angle() + PI / 2.0
	if global_position.distance_to(_target_pos) < STATION_RANGE:
		state = State.TRAVELING
		_pick_asteroid_target()


func _do_flee(delta: float, threat: Node2D) -> void:
	_state_timer += delta
	if _state_timer > 5.0 or not is_instance_valid(threat):
		state = State.TRAVELING
		_pick_asteroid_target()
		return
	if is_instance_valid(threat):
		var away: Vector2 = (global_position - threat.global_position).normalized()
		position += away * FLEE_SPEED * delta
		rotation = away.angle() + PI / 2.0


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
		em.add_explosion(global_position, 1.0)
		em.add_float("MINERS REP -8", global_position + Vector2(0, -20), Color.ORANGE)
	GameState.add_faction_rep("miners", -8)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.5


func _spawn_loot() -> void:
	var loot_scene: PackedScene = load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		return
	var drop_count: int = randi_range(4, 8)
	var types: Array[String] = ["ore", "scrap"]
	var res: Dictionary = {}
	for i in range(drop_count):
		var t: String = types[randi() % types.size()]
		res[t] = int(res.get(t, 0)) + 1
	var loot: Node2D = loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	if loot.has_method("setup"):
		loot.setup(randi_range(10, 25), res)
	get_parent().add_child(loot)


func _pick_asteroid_target() -> void:
	var asteroids := get_tree().get_nodes_in_group("asteroids")
	if asteroids.is_empty():
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 400.0
		return
	var closest: Node2D = null
	var closest_d: float = 99999.0
	for a in asteroids:
		if not is_instance_valid(a):
			continue
		var d: float = global_position.distance_to(a.global_position)
		if d < closest_d:
			closest_d = d
			closest = a
	if is_instance_valid(closest):
		_target_pos = closest.global_position
	else:
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 400.0


func _pick_station_target() -> void:
	var stations := get_tree().get_nodes_in_group("stations")
	if stations.is_empty():
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 600.0
		return
	var closest: Node2D = null
	var closest_d: float = 99999.0
	for s in stations:
		if not is_instance_valid(s):
			continue
		var d: float = global_position.distance_to(s.global_position)
		if d < closest_d:
			closest_d = d
			closest = s
	if is_instance_valid(closest):
		_target_pos = closest.global_position
	else:
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 600.0


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-16-miner-npc.png") as Texture2D
	if not is_instance_valid(tex):
		return
	_sprite_tex = tex
	_sprite_size = 50.0
	_has_sprite = true
	queue_redraw()

func _draw() -> void:
	if _has_sprite and is_instance_valid(_sprite_tex):
		if is_dead:
			return
		var sz: float = _sprite_size
		if _sprite_rot_offset != 0.0:
			draw_set_transform(Vector2.ZERO, _sprite_rot_offset)
		draw_texture_rect(_sprite_tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false)
		if _sprite_rot_offset != 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if hp < max_hp:
			var bw: float = sz
			var by: float = -sz * 0.5 - 5.0
			var pct: float = hp / max_hp
			# Counter-rotate so HP bar stays screen-aligned
			draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
			draw_rect(Rect2(-bw*0.5, by, bw, 3.0), Color(0.2,0.2,0.2,0.8))
			var fc := Color(0.2,0.9,0.2) if pct>0.5 else (Color(0.9,0.7,0.1) if pct>0.25 else Color(0.9,0.1,0.1))
			draw_rect(Rect2(-bw*0.5, by, bw*pct, 3.0), fc)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if is_dead:
		return
	# Small gray/silver diamond shape
	var col: Color
	match state:
		State.FLEEING:
			col = Color(1.0, 0.7, 0.3, 0.9)
		State.MINING:
			col = Color(0.6, 0.8, 0.6, 0.9)
		_:
			col = Color(0.7, 0.75, 0.8, 0.9)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -8), Vector2(-5, 0), Vector2(0, 8), Vector2(5, 0)
	]), col)
	# Small label
	draw_string(ThemeDB.fallback_font, Vector2(-12, -12), "MINER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.8, 0.9, 0.6))
	# HP bar when damaged
	if hp < max_hp:
		var bw := 30.0
		var pct: float = hp / max_hp
		draw_rect(Rect2(-bw / 2.0, -24, bw, 3), Color(0.2, 0.2, 0.2, 0.7))
		draw_rect(Rect2(-bw / 2.0, -24, bw * pct, 3), Color(0.2, 0.9, 0.2))
