extends Node2D

enum State { PATROL, CHASE, COMBAT }

var hp: float = 180.0
var max_hp: float = 180.0
var is_dead := false
var speed: float = 55.0
var state: State = State.PATROL
var _flash_timer: float = 0.0
var _shoot_timer: float = 0.0
var _despawn_timer: float = -1.0
var _patrol_timer: float = 0.0
var _patrol_dir: Vector2 = Vector2.RIGHT

const AGGRO_RANGE := 300.0
const COMBAT_RANGE := 220.0
const SHOOT_COOLDOWN := 2.8
const SPREAD_ANGLE := 0.3
const BULLET_DAMAGE := 14.0
const XP_REWARD := 60
const CREDIT_REWARD := 80

var difficulty_mult: float = 1.0

func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult
	hp = 120.0 * difficulty_mult
	max_hp = hp

var bullet_scene: PackedScene


func _ready() -> void:
	add_to_group("enemies")
	bullet_scene = load("res://scenes/bullet.tscn")
	_patrol_dir = Vector2.from_angle(randf() * TAU)
	_setup_sprite()
	queue_redraw()


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-15-battleship.png") as Texture2D
	if not is_instance_valid(tex):
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var scale_factor: float = 90.0 / max(tex.get_size().x, tex.get_size().y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.rotation = PI
	add_child(sprite)


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

	queue_redraw()

	var player := _get_player()
	if not is_instance_valid(player):
		_do_patrol(delta)
		return

	var dist := global_position.distance_to(player.global_position)

	match state:
		State.PATROL:
			if dist < AGGRO_RANGE:
				state = State.CHASE
		State.CHASE:
			if dist < COMBAT_RANGE:
				state = State.COMBAT
			elif dist > AGGRO_RANGE * 1.4:
				state = State.PATROL
		State.COMBAT:
			if dist > COMBAT_RANGE * 1.3:
				state = State.CHASE

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.CHASE:
			var dir := (player.global_position - global_position).normalized()
			position += dir * speed * delta
			rotation = dir.angle() + PI / 2.0
		State.COMBAT:
			var dir := (player.global_position - global_position).normalized()
			rotation = dir.angle() + PI / 2.0
			_shoot_timer += delta
			if _shoot_timer >= SHOOT_COOLDOWN:
				_shoot_timer = 0.0
				call_deferred("_fire_spread")


func _do_patrol(delta: float) -> void:
	_patrol_timer += delta
	if _patrol_timer > randf_range(3.0, 6.0):
		_patrol_timer = 0.0
		_patrol_dir = Vector2.from_angle(randf() * TAU)
	position += _patrol_dir * speed * 0.4 * delta
	if _patrol_dir.length() > 0.1:
		rotation = _patrol_dir.angle() + PI / 2.0


func _fire_spread() -> void:
	var angles := [-SPREAD_ANGLE, 0.0, SPREAD_ANGLE]
	for a in angles:
		var bullet := bullet_scene.instantiate() as Node2D
		var forward := Vector2.UP.rotated(rotation + a)
		bullet.global_position = global_position + forward * -25.0
		bullet.rotation = rotation + a
		bullet.set("is_player_bullet", false)
		bullet.set("damage", BULLET_DAMAGE)
		get_parent().add_child(bullet)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_flash_timer = 0.15
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
			call_deferred("_die")


signal died()

func _die() -> void:
	is_dead = true
	GameState.record_kill()
	GameState.add_xp(XP_REWARD)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 2.5)
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
	var res: Dictionary = {"scrap": randi_range(8, 15), "ore": randi_range(5, 10)}
	if loot.has_method("setup"):
		loot.setup(CREDIT_REWARD, res)
	get_parent().add_child(loot)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _draw() -> void:
	if is_dead:
		return
	# Main hull — large hexagon
	var pts := PackedVector2Array()
	for i in range(6):
		var a := i * TAU / 6.0 - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * 22.0)
	draw_colored_polygon(pts, Color(0.55, 0.35, 0.15))
	# Armor plating overlay
	var pts2 := PackedVector2Array()
	for i in range(6):
		var a := i * TAU / 6.0 - PI / 2.0
		pts2.append(Vector2(cos(a), sin(a)) * 16.0)
	draw_colored_polygon(pts2, Color(0.45, 0.3, 0.12))
	# Gun mounts
	draw_rect(Rect2(-4, -24, 8, 10), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(-14, -18, 6, 8), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(8, -18, 6, 8), Color(0.3, 0.3, 0.3))
	# HP bar
	if hp < max_hp:
		var bw := 36.0
		var bh := 4.0
		var by := -32.0
		var pct := hp / max_hp
		draw_rect(Rect2(-bw / 2.0, by, bw, bh), Color(0.2, 0.2, 0.2, 0.8))
		var fc := Color(0.2, 0.9, 0.2) if pct > 0.5 else (Color(0.9, 0.7, 0.1) if pct > 0.25 else Color(0.9, 0.1, 0.1))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, bh), fc)
