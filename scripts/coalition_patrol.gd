extends Node2D

enum State { PATROL, CHASE, ORBIT }

var state: State = State.PATROL
var speed: float = 0.0
var hp: float = 120.0
var max_hp: float = 120.0
var is_dead := false
var _target_pos: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false
var _patrol_timer: float = 0.0

var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.0
var orbit_angle: float = 0.0
var bullet_scene: PackedScene

const AGGRO_RANGE := 250.0
const ORBIT_RANGE := 140.0
const DEAGGRO_RANGE := 400.0
const REP_THRESHOLD := 20


func _ready() -> void:
	add_to_group("npc_ships")
	add_to_group("npc_coalition")
	speed = randf_range(50.0, 70.0)
	bullet_scene = load("res://scenes/bullet.tscn")
	orbit_angle = randf() * TAU
	_pick_station_target()
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

	var player := _get_player()
	var is_hostile: bool = GameState.faction_rep.get("coalition", 50) < REP_THRESHOLD

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
					_pick_station_target()
				elif dist < ORBIT_RANGE:
					state = State.ORBIT
			State.ORBIT:
				if dist > DEAGGRO_RANGE:
					state = State.PATROL
					_pick_station_target()
	elif state != State.PATROL:
		state = State.PATROL
		_pick_station_target()

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
	var dir: Vector2 = (_target_pos - global_position).normalized()
	position += dir * speed * delta
	rotation = dir.angle() + PI / 2.0
	if global_position.distance_to(_target_pos) < 60.0:
		_pick_station_target()


func _do_chase(player: Node2D, delta: float) -> void:
	var dir: Vector2 = (player.global_position - global_position).normalized()
	position += dir * speed * 1.2 * delta
	rotation = dir.angle() + PI / 2.0


func _do_orbit(player: Node2D, delta: float) -> void:
	orbit_angle += delta * (speed / ORBIT_RANGE) * 0.8
	var target_pos: Vector2 = player.global_position + Vector2.from_angle(orbit_angle) * ORBIT_RANGE
	var dir: Vector2 = (target_pos - global_position).normalized()
	position += dir * speed * delta
	var face_dir: Vector2 = (player.global_position - global_position).normalized()
	rotation = face_dir.angle() + PI / 2.0
	_handle_shooting(delta)


func _handle_shooting(delta: float) -> void:
	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		call_deferred("_shoot")


func _shoot() -> void:
	if not is_instance_valid(bullet_scene):
		return
	var bullet := bullet_scene.instantiate() as Node2D
	var forward := Vector2.UP.rotated(rotation)
	bullet.global_position = global_position + forward * -20.0
	bullet.rotation = rotation
	bullet.set("is_player_bullet", false)
	bullet.set("damage", 12.0)
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
		em.add_explosion(global_position, 1.5)
		em.add_float("COALITION REP -12", global_position + Vector2(0, -20), Color.ORANGE)
	GameState.add_faction_rep("coalition", -12)
	call_deferred("_spawn_loot")
	_despawn_timer = 1.5


func _spawn_loot() -> void:
	var loot_scene: PackedScene = load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		return
	var drop_count: int = randi_range(6, 10)
	var types: Array[String] = ["ore", "crystal"]
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
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 800.0
		return
	var idx: int = randi() % stations.size()
	var station: Node2D = stations[idx] as Node2D
	if is_instance_valid(station):
		_target_pos = station.global_position
	else:
		_target_pos = global_position + Vector2.from_angle(randf() * TAU) * 800.0


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-16-void-sentinel-ship.png") as Texture2D
	if not is_instance_valid(tex):
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var scale_factor: float = 50.0 / max(tex.get_size().x, tex.get_size().y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.rotation = PI
	add_child(sprite)
	_has_sprite = true

func _draw() -> void:
	if _has_sprite:
		return
	if is_dead:
		return
	# Blue/white diamond shape
	var col: Color = Color(0.3, 0.5, 1.0, 0.9) if state == State.PATROL else Color(0.5, 0.3, 1.0, 0.9)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -10), Vector2(-7, 0), Vector2(0, 10), Vector2(7, 0)
	]), col)
	# White accent stripe
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(0.9, 0.95, 1.0, 0.6), 1.5)
	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-18, -14), "COALITION",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.6, 1.0, 0.6))
	# HP bar when damaged
	if hp < max_hp:
		var bw := 30.0
		var pct: float = hp / max_hp
		draw_rect(Rect2(-bw / 2.0, -24, bw, 3), Color(0.2, 0.2, 0.2, 0.7))
		draw_rect(Rect2(-bw / 2.0, -24, bw * pct, 3), Color(0.2, 0.9, 0.2))
