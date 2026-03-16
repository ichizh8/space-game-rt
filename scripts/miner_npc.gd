extends Node2D

enum State { TRAVELING, MINING, RETURNING, FLEEING }

var state: State = State.TRAVELING
var speed: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _mining_timer: float = 0.0
var _mining_duration: float = 0.0
var _state_timer: float = 0.0

const FLEE_SPEED := 100.0
const FLEE_RANGE := 150.0
const MINING_RANGE := 40.0
const STATION_RANGE := 60.0


func _ready() -> void:
	add_to_group("npc_miners")
	speed = randf_range(40.0, 60.0)
	_pick_asteroid_target()
	queue_redraw()


func _process(delta: float) -> void:
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


func _draw() -> void:
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
