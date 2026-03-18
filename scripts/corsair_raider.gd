extends Node2D

enum State { PATROL, CHASE, ORBIT }

var state: State = State.PATROL
var speed: float = 0.0
var hp: float = 50.0
var max_hp: float = 50.0
var is_dead := false
var _target_pos: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _patrol_timer: float = 0.0
var patrol_direction: Vector2 = Vector2.RIGHT

var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.8
var burst_count: int = 0
var burst_max: int = 2
var burst_pause: float = 0.0
var orbit_angle: float = 0.0
var orbit_direction: int = 1
var bullet_scene: PackedScene

const AGGRO_RANGE := 200.0
const ORBIT_RANGE := 100.0
const DEAGGRO_RANGE := 350.0
const REP_THRESHOLD := 40


func _ready() -> void:
	add_to_group("npc_ships")
	add_to_group("npc_corsairs")
	speed = randf_range(90.0, 120.0)
	bullet_scene = load("res://scenes/bullet.tscn")
	orbit_angle = randf() * TAU
	orbit_direction = 1 if randf() > 0.5 else -1
	patrol_direction = Vector2.from_angle(randf() * TAU)
	_target_pos = global_position + patrol_direction * 400.0
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

	var player := _get_player()
	var is_hostile: bool = GameState.faction_rep.get("corsairs", 20) < REP_THRESHOLD

	if is_instance_valid(player) and is_hostile:
		var dist: float = global_position.distance_to(player.global_position)
		match state:
			State.PATROL:
				if dist < AGGRO_RANGE:
					state = State.CHASE
					orbit_angle = (global_position - player.global_position).angle()
			State.CHASE:
				if dist > DEAGGRO_RANGE:
					state = State.PATROL
					patrol_direction = Vector2.from_angle(randf() * TAU)
				elif dist < ORBIT_RANGE:
					state = State.ORBIT
			State.ORBIT:
				if dist > DEAGGRO_RANGE:
					state = State.PATROL
					patrol_direction = Vector2.from_angle(randf() * TAU)
	elif state != State.PATROL:
		state = State.PATROL
		patrol_direction = Vector2.from_angle(randf() * TAU)

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.CHASE:
			if is_instance_valid(player):
				_do_chase(player, delta)
		State.ORBIT:
			if is_instance_valid(player):
				_do_orbit(player, delta)

	queue_redraw()


func _do_patrol(delta: float) -> void:
	_patrol_timer += delta
	if _patrol_timer > randf_range(3.0, 5.0):
		_patrol_timer = 0.0
		patrol_direction = Vector2.from_angle(randf() * TAU)
	position += patrol_direction * speed * 0.4 * delta
	if patrol_direction.length() > 0.1:
		rotation = patrol_direction.angle() + PI / 2.0


func _do_chase(player: Node2D, delta: float) -> void:
	var dir: Vector2 = (player.global_position - global_position).normalized()
	position += dir * speed * delta
	rotation = dir.angle() + PI / 2.0


func _do_orbit(player: Node2D, delta: float) -> void:
	orbit_angle += orbit_direction * delta * (speed / ORBIT_RANGE) * 0.8
	var target_pos: Vector2 = player.global_position + Vector2.from_angle(orbit_angle) * ORBIT_RANGE
	var dir: Vector2 = (target_pos - global_position).normalized()
	position += dir * speed * delta
	var face_dir: Vector2 = (player.global_position - global_position).normalized()
	rotation = face_dir.angle() + PI / 2.0
	_handle_shooting(delta)


func _handle_shooting(delta: float) -> void:
	if burst_pause > 0:
		burst_pause -= delta
		return
	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		call_deferred("_shoot")
		burst_count += 1
		if burst_count >= burst_max:
			burst_count = 0
			burst_pause = randf_range(1.5, 2.5)


func _shoot() -> void:
	if not is_instance_valid(bullet_scene):
		return
	var bullet := bullet_scene.instantiate() as Node2D
	var forward := Vector2.UP.rotated(rotation)
	bullet.global_position = global_position + forward * -18.0
	bullet.rotation = rotation
	bullet.set("is_player_bullet", false)
	bullet.set("damage", 8.0)
	get_parent().add_child(bullet)


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
		em.add_float("CORSAIRS REP -6", global_position + Vector2(0, -20), Color.ORANGE)
	GameState.add_faction_rep("corsairs", -6)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.5


func _spawn_loot() -> void:
	var loot_scene: PackedScene = load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		return
	var credit_amount: int = randi_range(40, 80)
	var res: Dictionary = {}
	var loot: Node2D = loot_scene.instantiate() as Node2D
	loot.global_position = global_position
	if loot.has_method("setup"):
		loot.setup(credit_amount, res)
	get_parent().add_child(loot)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _draw() -> void:
	if is_dead:
		return
	# Red/dark angular shape
	var col: Color = Color(0.8, 0.15, 0.1, 0.9) if state != State.PATROL else Color(0.6, 0.1, 0.1, 0.9)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -10), Vector2(-8, -2), Vector2(-5, 10), Vector2(5, 10), Vector2(8, -2)
	]), col)
	# Dark accent
	draw_line(Vector2(-4, -4), Vector2(4, -4), Color(0.2, 0.05, 0.05, 0.8), 1.5)
	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-16, -14), "CORSAIR",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.4, 0.3, 0.6))
	# HP bar when damaged
	if hp < max_hp:
		var bw := 30.0
		var pct: float = hp / max_hp
		draw_rect(Rect2(-bw / 2.0, -24, bw, 3), Color(0.2, 0.2, 0.2, 0.7))
		draw_rect(Rect2(-bw / 2.0, -24, bw * pct, 3), Color(0.2, 0.9, 0.2))
