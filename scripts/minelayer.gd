extends Node2D

var hp: float = 35.0
var max_hp: float = 35.0
var is_dead := false
var speed: float = 110.0
var difficulty_mult: float = 1.0

signal died()

const AGGRO_RANGE := 500.0
const MINE_INTERVAL := 3.5
const XP_REWARD := 18
const CREDIT_REWARD := 25

enum State { PATROL, LAY_MINES, FLEE }
var state: State = State.PATROL

var _mine_timer: float = 0.0
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0

func _ready() -> void:
	add_to_group("enemies")
	_patrol_dir = Vector2.from_angle(randf() * TAU)
	_mine_timer = MINE_INTERVAL
	queue_redraw()

func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult
	hp = 35.0 * difficulty_mult
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

	match state:
		State.PATROL:
			_patrol_timer -= delta
			if _patrol_timer <= 0:
				_patrol_dir = Vector2.from_angle(randf() * TAU)
				_patrol_timer = randf_range(2.0, 4.0)
			position += _patrol_dir * speed * delta
			if dist < AGGRO_RANGE:
				state = State.LAY_MINES
				_mine_timer = 0.5

		State.LAY_MINES:
			# Fly in a wide arc around player
			var angle_to_player := (player.global_position - global_position).angle()
			var arc_dir := Vector2.from_angle(angle_to_player + PI * 0.7)
			position += arc_dir * speed * delta
			rotation = arc_dir.angle() + PI / 2.0

			_mine_timer -= delta
			if _mine_timer <= 0:
				_mine_timer = MINE_INTERVAL
				call_deferred("_drop_mine")

			if dist > AGGRO_RANGE * 1.5:
				state = State.PATROL

		State.FLEE:
			var away := (global_position - player.global_position).normalized()
			position += away * speed * 1.4 * delta
			if dist > AGGRO_RANGE * 1.2:
				state = State.LAY_MINES

	if dist < 120.0:
		state = State.FLEE

func _drop_mine() -> void:
	if is_dead:
		return
	var mine_scene := load("res://scenes/mine.tscn") as PackedScene
	if not is_instance_valid(mine_scene):
		return
	var mine := mine_scene.instantiate() as Node2D
	mine.global_position = global_position
	if mine.has_method("setup"):
		mine.setup(difficulty_mult)
	var parent := get_parent()
	if is_instance_valid(parent):
		parent.add_child(mine)

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
		em.add_explosion(global_position, 1.1)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.4
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
		loot.setup(cr, {"scrap": randi_range(3, 6)})
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
	# Fallback: stocky hexagonal ship
	var points := PackedVector2Array([
		Vector2(0, -14), Vector2(12, -7), Vector2(12, 7),
		Vector2(0, 14), Vector2(-12, 7), Vector2(-12, -7)
	])
	var col := Color(0.7, 0.45, 0.1)
	draw_colored_polygon(points, col)
	# Mine ports
	draw_circle(Vector2(10, 0), 3.0, Color(0.9, 0.2, 0.2))
	draw_circle(Vector2(-10, 0), 3.0, Color(0.9, 0.2, 0.2))
