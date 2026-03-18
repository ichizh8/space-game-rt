extends Node2D

enum State { GRAZE, CHARGE }

var hp: float = 200.0
var max_hp: float = 200.0
var is_dead: bool = false
var speed: float = 60.0
var state: State = State.GRAZE
var difficulty_mult: float = 1.0

var velocity: Vector2 = Vector2.ZERO
var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_timer: float = 0.0
var _been_attacked: bool = false
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _has_sprite: bool = false

const CHARGE_RANGE := 300.0
const DEAGGRO_RANGE := 500.0
const COLOR := Color(0.4, 0.9, 0.8)

signal died()


func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult


func _ready() -> void:
	add_to_group("wildlife")
	add_to_group("enemies")
	hp *= difficulty_mult
	max_hp = hp
	_wander_dir = Vector2.from_angle(randf() * TAU)
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
		State.GRAZE:
			if _been_attacked and dist < CHARGE_RANGE:
				state = State.CHARGE
		State.CHARGE:
			if dist > DEAGGRO_RANGE:
				state = State.GRAZE
				_been_attacked = false

	match state:
		State.GRAZE:
			_wander_timer += delta
			if _wander_timer > randf_range(3.0, 6.0):
				_wander_timer = 0.0
				_wander_dir = Vector2.from_angle(randf() * TAU)
			velocity = _wander_dir * speed * 0.4
		State.CHARGE:
			if is_instance_valid(player):
				var dir := (player.global_position - global_position).normalized()
				velocity = dir * speed * 2.0

	if velocity.length() > 0.1:
		rotation = velocity.angle() + PI / 2.0
	position += velocity * delta


func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp -= amount
	_been_attacked = true
	_flash_timer = 0.12
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	queue_redraw()
	if hp <= 0:
		call_deferred("_die")


func _die() -> void:
	is_dead = true
	GameState.record_kill()
	GameState.add_xp(35)
	GameState.drop_ingredients("crystal_feeder")
	GameState.add_resource("crystal", randi_range(5, 10))
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 1.3)
	call_deferred("_spawn_ingredient_loot")
	_despawn_timer = 1.4
	queue_redraw()
	died.emit()


func _spawn_ingredient_loot() -> void:
	GameState.add_ingredient("feeder_flesh", randi_range(1, 2))
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_float"):
		em.add_float("+Feeder Flesh", global_position + Vector2(0, -20), COLOR)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _setup_sprite() -> void:
	var tex := load("res://assets/2026-03-18-wildlife-crystal-feeder.png") as Texture2D
	if not is_instance_valid(tex):
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var scale_factor: float = 46.0 / max(tex.get_size().x, tex.get_size().y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.rotation = PI
	add_child(sprite)
	_has_sprite = true

func _draw() -> void:
	if _has_sprite:
		return
	if is_dead:
		return
	# Hexagon with spiky outline
	var pts := PackedVector2Array()
	for i in range(6):
		var a: float = i * TAU / 6.0 - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * 18.0)
	draw_colored_polygon(pts, COLOR)
	# Spiky outline
	for i in range(6):
		var a: float = i * TAU / 6.0 - PI / 2.0
		var a2: float = (i + 1) * TAU / 6.0 - PI / 2.0
		var mid_a: float = (a + a2) * 0.5
		var spike := Vector2(cos(mid_a), sin(mid_a)) * 24.0
		var p1 := Vector2(cos(a), sin(a)) * 18.0
		var p2 := Vector2(cos(a2), sin(a2)) * 18.0
		draw_line(p1, spike, Color(0.6, 1.0, 0.9, 0.8), 1.5)
		draw_line(spike, p2, Color(0.6, 1.0, 0.9, 0.8), 1.5)
	# HP bar
	if hp < max_hp:
		var bw := 32.0
		var bh := 4.0
		var by := -30.0
		var pct := hp / max_hp
		draw_rect(Rect2(-bw / 2.0, by, bw, bh), Color(0.2, 0.2, 0.2, 0.8))
		var fc := Color(0.2, 0.9, 0.2) if pct > 0.5 else (Color(0.9, 0.7, 0.1) if pct > 0.25 else Color(0.9, 0.1, 0.1))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, bh), fc)
