extends Node2D

enum State { PATROL, CHASE, ORBIT, RETREAT }
enum EnemyType { PIRATE, DRONE }
enum AIStyle { STANDARD, AGGRESSIVE, SNIPER, FLANKER, COWARD }

@export var enemy_type: EnemyType = EnemyType.PIRATE

var hp: float = 30.0
var max_hp: float = 30.0
var is_dead := false
var damage: float = 10.0
var speed: float = 160.0
var state: State = State.PATROL
var ai_style: AIStyle = AIStyle.STANDARD

var velocity: Vector2 = Vector2.ZERO
var patrol_direction: Vector2 = Vector2.RIGHT
var patrol_timer: float = 0.0

var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.2
var burst_count: int = 0
var burst_max: int = 3
var burst_pause: float = 0.0

var orbit_angle: float = 0.0
var orbit_direction: int = 1

var _flash_timer: float = 0.0
var _has_sprite := false
var _despawn_timer: float = -1.0

var bullet_scene: PackedScene

const AGGRO_RANGE := 180.0
const ORBIT_RANGE := 120.0
const RETREAT_RANGE := 50.0
const DEAGGRO_RANGE := 400.0

# AI style overrides
var _aggro_range_override: float = -1.0
var _orbit_range_override: float = -1.0
var _deaggro_range_override: float = -1.0
var _no_retreat: bool = false
var _direction_flip_timer: float = 0.0
var _coward_fled: bool = false
var _coward_hit: bool = false


var difficulty_mult: float = 1.0

func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult

func _apply_difficulty() -> void:
	hp = hp * difficulty_mult
	max_hp = hp
	damage = damage * difficulty_mult
	speed = speed * (1.0 + (difficulty_mult - 1.0) * 0.4)

func _ready() -> void:
	add_to_group("enemies")
	bullet_scene = load("res://scenes/bullet.tscn")
	match enemy_type:
		EnemyType.PIRATE:
			# Balanced: lower base damage, slower, fewer bursts
			speed = 120.0; hp = 30.0; max_hp = 30.0; damage = 6.0
			shoot_cooldown = 0.8; burst_max = 2
			orbit_direction = 1 if randf() > 0.5 else -1
			# Assign random AI style
			var roll: int = randi() % 4
			if roll == 0:
				ai_style = AIStyle.AGGRESSIVE
			elif roll == 1:
				ai_style = AIStyle.SNIPER
			elif roll == 2:
				ai_style = AIStyle.FLANKER
			else:
				ai_style = AIStyle.COWARD
		EnemyType.DRONE:
			speed = 80.0; hp = 60.0; max_hp = 60.0; damage = 18.0
			shoot_cooldown = 1.5; burst_max = 1
	orbit_angle = randf() * TAU
	patrol_direction = Vector2.from_angle(randf() * TAU)
	_apply_difficulty()
	_apply_ai_style()
	_setup_sprite()
	queue_redraw()


func _apply_ai_style() -> void:
	if enemy_type != EnemyType.PIRATE:
		return
	match ai_style:
		AIStyle.AGGRESSIVE:
			# Head-on attacker — charges in, fires, pulls back. No orbit.
			_aggro_range_override = 280.0
			_orbit_range_override = 30.0   # basically never orbits — stays in chase
			shoot_cooldown = 0.6
			burst_max = 2
			_no_retreat = true
		AIStyle.SNIPER:
			# Hangs back and takes single shots — not circling
			_orbit_range_override = 260.0
			shoot_cooldown = 2.5
			burst_max = 1
			damage *= 1.3
			_deaggro_range_override = 600.0
		AIStyle.FLANKER:
			# Tries to get beside you — moderate orbit range
			_orbit_range_override = 150.0
			orbit_direction = -1
			_direction_flip_timer = 0.0
			speed *= 1.05
			shoot_cooldown = 1.0
			burst_max = 2
		AIStyle.COWARD:
			# Hit and run — shoot once, retreat, come back
			_aggro_range_override = 200.0
			_orbit_range_override = 190.0
			burst_max = 1
			shoot_cooldown = 1.5


func _get_aggro_range() -> float:
	return _aggro_range_override if _aggro_range_override > 0.0 else AGGRO_RANGE

func _get_orbit_range() -> float:
	return _orbit_range_override if _orbit_range_override > 0.0 else ORBIT_RANGE

func _get_deaggro_range() -> float:
	return _deaggro_range_override if _deaggro_range_override > 0.0 else DEAGGRO_RANGE


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
			queue_redraw()

	var player := _get_player()

	if not is_instance_valid(player):
		_do_patrol(delta)
		position += velocity * delta
		return

	var dist := global_position.distance_to(player.global_position)

	match state:
		State.PATROL:
			if dist < _get_aggro_range():
				# Pirates ignore players with high pirate rep
				if enemy_type == EnemyType.PIRATE and GameState.faction_rep.get("pirates", 0) >= 70:
					pass  # skip aggro
				else:
					state = State.CHASE
					orbit_angle = (global_position - player.global_position).angle()
		State.CHASE:
			if dist > _get_deaggro_range():
				state = State.PATROL
			elif dist < _get_orbit_range():
				state = State.ORBIT
		State.ORBIT:
			if dist > _get_deaggro_range():
				state = State.PATROL
			elif dist < RETREAT_RANGE:
				state = State.RETREAT
		State.RETREAT:
			if _no_retreat:
				state = State.ORBIT
			elif dist > RETREAT_RANGE * 1.5:
				state = State.ORBIT

	match state:
		State.PATROL:   _do_patrol(delta)
		State.CHASE:    _do_chase(player, delta)
		State.ORBIT:    _do_orbit(player, delta)
		State.RETREAT:  _do_retreat(player, delta)

	position += velocity * delta


func _do_patrol(delta: float) -> void:
	patrol_timer += delta
	if patrol_timer > randf_range(2.0, 4.0):
		patrol_timer = 0.0
		patrol_direction = Vector2.from_angle(randf() * TAU)
	velocity = patrol_direction * speed * 0.3
	if velocity.length() > 0.1:
		rotation = velocity.angle() + PI / 2.0


func _do_chase(player: Node2D, _delta: float) -> void:
	var dir := (player.global_position - global_position).normalized()
	var chase_speed: float = speed * 1.3 if ai_style == AIStyle.AGGRESSIVE else speed
	velocity = dir * chase_speed
	rotation = dir.angle() + PI / 2.0


func _do_orbit(player: Node2D, delta: float) -> void:
	# Pirates don't circle — they do strafe passes
	# SNIPER: just hold range and face player
	if ai_style == AIStyle.SNIPER:
		var cur_range: float = _get_orbit_range()
		var dist: float = global_position.distance_to(player.global_position)
		var dir_to_player := (player.global_position - global_position).normalized()
		if dist < cur_range * 0.85:
			# Back away
			velocity = -dir_to_player * speed * 0.5
		elif dist > cur_range * 1.15:
			# Drift in
			velocity = dir_to_player * speed * 0.4
		else:
			velocity = Vector2.ZERO
		rotation = dir_to_player.angle() + PI / 2.0
		return

	# AGGRESSIVE / FLANKER / COWARD: strafe pass
	# Use orbit_angle as a sweep direction — move perpendicular to player, then pull away
	orbit_angle += orbit_direction * delta * 0.6  # slow sweep angle, not fast orbit
	var cur_range: float = _get_orbit_range()
	var dist: float = global_position.distance_to(player.global_position)
	var dir_to_player := (player.global_position - global_position).normalized()
	# Move sideways relative to player + slightly toward/away
	var perp := Vector2(-dir_to_player.y, dir_to_player.x) * orbit_direction
	var radial: float = (cur_range - dist) / cur_range  # positive = too close, negative = too far
	velocity = (perp * 0.7 + dir_to_player * -radial * 0.5) * speed
	rotation = dir_to_player.angle() + PI / 2.0
	_handle_shooting(delta)


func _do_retreat(player: Node2D, _delta: float) -> void:
	var dir := (global_position - player.global_position).normalized()
	velocity = dir * speed * 1.2
	rotation = (player.global_position - global_position).angle() + PI / 2.0


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
			burst_pause = randf_range(1.5, 3.0)


func _shoot() -> void:
	if not is_instance_valid(bullet_scene):
		return
	var bullet := bullet_scene.instantiate() as Node2D
	var forward := Vector2.UP.rotated(rotation)
	bullet.global_position = global_position + forward * -20.0
	bullet.rotation = rotation
	bullet.set("is_player_bullet", false)
	bullet.set("damage", damage)
	get_parent().add_child(bullet)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.12
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
			call_deferred("_die")
			return
	# Coward: flee when below 50% HP
	if ai_style == AIStyle.COWARD and hp < max_hp * 0.5 and not _coward_fled:
		_coward_fled = true
		state = State.RETREAT
	# Coward: stop shooting after first hit
	if ai_style == AIStyle.COWARD:
		_coward_hit = true


signal died()

func _die() -> void:
	is_dead = true
	GameState.record_kill()
	var credit_reward := 20 if enemy_type == EnemyType.PIRATE else 35
	var xp_reward: int = 15 if enemy_type == EnemyType.PIRATE else 25
	GameState.add_xp(xp_reward)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 1.2 if enemy_type == EnemyType.DRONE else 1.0)
	call_deferred("_spawn_loot", credit_reward)
	_despawn_timer = 1.4
	queue_redraw()
	died.emit()


func _spawn_loot(cr: int) -> void:
	var loot_scene := load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		GameState.add_credits(cr)
		return
	var loot := loot_scene.instantiate() as Node2D
	var spawn_pos := global_position + Vector2.from_angle(randf() * TAU) * 30.0
	loot.global_position = spawn_pos
	var res: Dictionary = {}
	var drop_types: Array[String] = ["ore", "crystal", "scrap"]
	var drop_type: String = drop_types[randi() % 3]
	var drop_amt: int = randi_range(3, 8)
	res[drop_type] = drop_amt
	if GameState.has_perk("salvager"):
		res["scrap"] = res.get("scrap", 0) + randi_range(3, 6)
	if loot.has_method("setup"):
		loot.setup(cr, res)
	get_parent().add_child(loot)
	_ingredient_drop()


func _ingredient_drop() -> void:
	match enemy_type:
		EnemyType.PIRATE:
			GameState.add_ingredient("scrap_protein", randi_range(1, 2))
		EnemyType.DRONE:
			GameState.add_ingredient("void_flesh", 1)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _setup_sprite() -> void:
	var tex_path := ""
	var target_size := 60.0
	match enemy_type:
		EnemyType.PIRATE:
			tex_path = "res://assets/2026-03-15-enemy-pirate.png"
		EnemyType.DRONE:
			tex_path = "res://assets/2026-03-15-drone.png"
			target_size = 52.0
	if tex_path.is_empty():
		return
	var sprite := Sprite2D.new()
	var tex := load(tex_path) as Texture2D
	if is_instance_valid(tex):
		sprite.texture = tex
		var tex_size := tex.get_size()
		var scale_factor: float = target_size / max(tex_size.x, tex_size.y)
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.rotation = PI  # sprites face down, game uses UP as forward
		add_child(sprite)
		_has_sprite = true


func _draw() -> void:
	if is_dead:
		return
	var base_color := Color.RED if enemy_type == EnemyType.PIRATE else Color.ORANGE
	match enemy_type:
		EnemyType.PIRATE:
			if not _has_sprite:
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, -12), Vector2(-9, 0), Vector2(0, 12), Vector2(9, 0)
				]), base_color)
		EnemyType.DRONE:
			var pts := PackedVector2Array()
			for i in range(6):
				var a := i * TAU / 6.0 - PI / 2.0
				pts.append(Vector2(cos(a), sin(a)) * 14)
			draw_colored_polygon(pts, base_color)
	if hp < max_hp:
		var bw := 28.0; var bh := 4.0; var by := -22.0
		var pct := hp / max_hp
		draw_rect(Rect2(-bw / 2.0, by, bw, bh), Color(0.2, 0.2, 0.2, 0.8))
		var fc := Color(0.2, 0.9, 0.2) if pct > 0.5 else (Color(0.9, 0.7, 0.1) if pct > 0.25 else Color(0.9, 0.1, 0.1))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, bh), fc)
