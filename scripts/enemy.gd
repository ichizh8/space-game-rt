extends Node2D

enum State { PATROL, CHASE, ORBIT, RETREAT }
enum EnemyType { PIRATE, DRONE }

@export var enemy_type: EnemyType = EnemyType.PIRATE

var hp: float = 30.0
var max_hp: float = 30.0
var is_dead := false
var damage: float = 10.0
var speed: float = 160.0
var state: State = State.PATROL

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

var bullet_scene: PackedScene

const AGGRO_RANGE := 180.0
const ORBIT_RANGE := 120.0
const RETREAT_RANGE := 50.0
const DEAGGRO_RANGE := 400.0


func _ready() -> void:
	add_to_group("enemies")
	bullet_scene = load("res://scenes/bullet.tscn")
	match enemy_type:
		EnemyType.PIRATE:
			speed = 160.0; hp = 30.0; max_hp = 30.0; damage = 10.0
			shoot_cooldown = 0.25; burst_max = 3
			orbit_direction = 1 if randf() > 0.5 else -1
		EnemyType.DRONE:
			speed = 80.0; hp = 60.0; max_hp = 60.0; damage = 18.0
			shoot_cooldown = 1.5; burst_max = 1
	orbit_angle = randf() * TAU
	patrol_direction = Vector2.from_angle(randf() * TAU)
	queue_redraw()


func _process(delta: float) -> void:
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
			if dist < AGGRO_RANGE:
				state = State.CHASE
				orbit_angle = (global_position - player.global_position).angle()
		State.CHASE:
			if dist > DEAGGRO_RANGE:
				state = State.PATROL
			elif dist < ORBIT_RANGE:
				state = State.ORBIT
		State.ORBIT:
			if dist > DEAGGRO_RANGE:
				state = State.PATROL
			elif dist < RETREAT_RANGE:
				state = State.RETREAT
		State.RETREAT:
			if dist > RETREAT_RANGE * 1.5:
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
	velocity = dir * speed
	rotation = dir.angle() + PI / 2.0


func _do_orbit(player: Node2D, delta: float) -> void:
	orbit_angle += orbit_direction * delta * (speed / ORBIT_RANGE) * 0.8
	var target_pos := player.global_position + Vector2.from_angle(orbit_angle) * ORBIT_RANGE
	var dir := (target_pos - global_position).normalized()
	velocity = dir * speed
	var face_dir := (player.global_position - global_position).normalized()
	rotation = face_dir.angle() + PI / 2.0
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
		_shoot()
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
	get_tree().current_scene.add_child(bullet)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.12
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
		_die()


func _die() -> void:
	is_dead = true
	set_process(false)
	hide()
	var drop_types := ["ore", "crystal", "scrap", "fuel"]
	GameState.add_resource(drop_types[randi() % drop_types.size()], randi_range(5, 10))


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _draw() -> void:
	var base_color := Color.RED if enemy_type == EnemyType.PIRATE else Color.ORANGE
	match enemy_type:
		EnemyType.PIRATE:
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
