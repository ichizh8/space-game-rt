extends Node2D

var speed: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var _lifetime: float = 0.0
var _trail_points: Array[Vector2] = []
var _trail_timer: float = 0.0
var hp: float = 15.0
var is_dead := false

const MAX_LIFETIME := 25.0
const DESPAWN_DIST := 8000.0
const TRAIL_LENGTH := 8
const DAMAGE_TO_PLAYER := 5.0
const FUEL_DROP_CHANCE := 0.4
const CHECK_INTERVAL := 0.3

var _check_timer: float = 0.0


func _ready() -> void:
	add_to_group("comets")
	speed = randf_range(120.0, 180.0)
	direction = Vector2.from_angle(randf() * TAU)
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	if is_dead:
		return

	_lifetime += delta
	position += direction * speed * delta

	# Trail
	_trail_timer += delta
	if _trail_timer > 0.03:
		_trail_timer = 0.0
		_trail_points.push_front(global_position)
		if _trail_points.size() > TRAIL_LENGTH:
			_trail_points.resize(TRAIL_LENGTH)

	# Despawn checks
	if _lifetime > MAX_LIFETIME or global_position.length() > DESPAWN_DIST:
		is_dead = true
		call_deferred("queue_free")
		return

	# Player collision check
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var ship := players[0] as Node2D
			if is_instance_valid(ship) and global_position.distance_to(ship.global_position) < 25.0:
				GameState.take_damage(DAMAGE_TO_PLAYER)
				call_deferred("_die")
				return

	queue_redraw()


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	if hp <= 0:
		call_deferred("_die")


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 0.6)
	if randf() < FUEL_DROP_CHANCE:
		call_deferred("_spawn_loot")
	else:
		call_deferred("queue_free")


func _spawn_loot() -> void:
	var loot_scene: PackedScene = load("res://scenes/loot_drop.tscn") as PackedScene
	if is_instance_valid(loot_scene):
		var loot: Node2D = loot_scene.instantiate() as Node2D
		loot.global_position = global_position
		if loot.has_method("setup"):
			loot.setup(0, {"fuel": 1})
		get_parent().add_child(loot)
	call_deferred("queue_free")


func _draw() -> void:
	if is_dead:
		return
	# Head: bright white dot
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.9, 1.0))
	draw_circle(Vector2.ZERO, 6.0, Color(0.8, 0.9, 1.0, 0.3))
	# Trail
	for i in range(_trail_points.size()):
		var world_pt: Vector2 = _trail_points[i]
		var local_pt: Vector2 = to_local(world_pt)
		var t: float = 1.0 - float(i) / float(_trail_points.size())
		var radius: float = 3.0 * t
		var alpha: float = 0.5 * t
		draw_circle(local_pt, radius, Color(0.6, 0.8, 1.0, alpha))
