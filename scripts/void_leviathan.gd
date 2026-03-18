extends Node2D

enum State { PATROL, ATTACK }

var hp: float = 600.0
var max_hp: float = 600.0
var is_dead: bool = false
var speed: float = 25.0
var state: State = State.PATROL
var difficulty_mult: float = 1.0

var velocity: Vector2 = Vector2.ZERO
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0
var _shoot_timer: float = 0.0
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false
var _sprite_tex: Texture2D = null
var _sprite_size: float = 40.0

var bullet_scene: PackedScene

const AGGRO_RANGE := 500.0
const DEAGGRO_RANGE := 700.0
const SHOOT_INTERVAL := 3.0
const BULLET_SPEED := 60.0
const COLOR := Color(0.7, 0.2, 0.9)

signal died()


func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult


func _ready() -> void:
	add_to_group("wildlife")
	add_to_group("enemies")
	scale = Vector2(2.0, 2.0)
	hp *= difficulty_mult
	max_hp = hp
	bullet_scene = load("res://scenes/bullet.tscn")
	_patrol_dir = Vector2.from_angle(randf() * TAU)
	# HUD warning
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("VOID LEVIATHAN DETECTED!", 3.0)
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
			queue_redraw()

	var player := _get_player()
	var dist := INF
	if is_instance_valid(player):
		dist = global_position.distance_to(player.global_position)

	match state:
		State.PATROL:
			if dist < AGGRO_RANGE:
				state = State.ATTACK
		State.ATTACK:
			if dist > DEAGGRO_RANGE:
				state = State.PATROL

	match state:
		State.PATROL:
			_patrol_timer += delta
			if _patrol_timer > randf_range(3.0, 6.0):
				_patrol_timer = 0.0
				_patrol_dir = Vector2.from_angle(randf() * TAU)
			velocity = _patrol_dir * speed
		State.ATTACK:
			# Slow approach
			if is_instance_valid(player):
				var dir := (player.global_position - global_position).normalized()
				velocity = dir * speed * 0.5
			_shoot_timer += delta
			if _shoot_timer >= SHOOT_INTERVAL:
				_shoot_timer = 0.0
				call_deferred("_shoot")

	if velocity.length() > 0.1:
		rotation = velocity.angle() + PI / 2.0
	position += velocity * delta


func _shoot() -> void:
	if not is_instance_valid(bullet_scene):
		return
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var bullet := bullet_scene.instantiate() as Node2D
	var dir := (player.global_position - global_position).normalized()
	bullet.global_position = global_position + dir * 50.0
	bullet.rotation = dir.angle() - PI / 2.0
	bullet.set("is_player_bullet", false)
	bullet.set("damage", 25.0 * difficulty_mult)
	# Override speed to be slower — set via constant on bullet
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


func _die() -> void:
	is_dead = true
	GameState.record_kill()
	GameState.add_xp(100)
	GameState.drop_ingredients("void_leviathan")
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 2.0)
	call_deferred("_spawn_ingredient_loot")
	_despawn_timer = 1.4
	queue_redraw()
	died.emit()


func _spawn_ingredient_loot() -> void:
	GameState.add_ingredient("leviathan_cut", randi_range(4, 6))
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_float"):
		em.add_float("+Leviathan Cut", global_position + Vector2(0, -40), Color(0.9, 0.5, 1.0))


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-18-wildlife-void-leviathan.png") as Texture2D
	if not is_instance_valid(tex):
		return
	_sprite_tex = tex
	_sprite_size = 90.0
	_has_sprite = true
	queue_redraw()

func _draw() -> void:
	if _has_sprite and is_instance_valid(_sprite_tex):
		if is_dead:
			return
		var sz: float = _sprite_size
		draw_texture_rect(_sprite_tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false)
		if hp < max_hp:
			var bw: float = sz
			var by: float = -sz * 0.5 - 5.0
			var pct: float = hp / max_hp
			draw_rect(Rect2(-bw*0.5, by, bw, 3.0), Color(0.2,0.2,0.2,0.8))
			var fc := Color(0.2,0.9,0.2) if pct>0.5 else (Color(0.9,0.7,0.1) if pct>0.25 else Color(0.9,0.1,0.1))
			draw_rect(Rect2(-bw*0.5, by, bw*pct, 3.0), fc)
		return
	if is_dead:
		return
	# Large irregular polygon (8 points)
	var pts := PackedVector2Array()
	var radii: Array[float] = [40.0, 32.0, 38.0, 28.0, 42.0, 30.0, 36.0, 34.0]
	for i in range(8):
		var a: float = i * TAU / 8.0
		pts.append(Vector2(cos(a), sin(a)) * radii[i])
	draw_colored_polygon(pts, COLOR)
	# Inner glow
	draw_circle(Vector2.ZERO, 15.0, Color(0.9, 0.4, 1.0, 0.3))
	# HP bar
	if hp < max_hp:
		var bw := 50.0
		var bh := 4.0
		var by := -48.0
		var pct := hp / max_hp
		draw_rect(Rect2(-bw / 2.0, by, bw, bh), Color(0.2, 0.2, 0.2, 0.8))
		var fc := Color(0.2, 0.9, 0.2) if pct > 0.5 else (Color(0.9, 0.7, 0.1) if pct > 0.25 else Color(0.9, 0.1, 0.1))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, bh), fc)
