extends Node2D

var hp: float = 120.0
var max_hp: float = 120.0
var is_dead: bool = false
var speed: float = 30.0
var difficulty_mult: float = 1.0

var velocity: Vector2 = Vector2.ZERO
var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_timer: float = 0.0
var _pulse_timer: float = 0.0
var _flash_timer: float = 0.0
var _despawn_timer: float = -1.0
var _time: float = 0.0

const PULSE_INTERVAL := 4.0
const PULSE_RANGE := 150.0
const PULSE_DAMAGE := 20.0
const COLOR := Color(0.5, 0.3, 0.9)

signal died()


func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult


func _ready() -> void:
	add_to_group("wildlife")
	add_to_group("enemies")
	hp *= difficulty_mult
	max_hp = hp
	_wander_dir = Vector2.from_angle(randf() * TAU)
	queue_redraw()


func _process(delta: float) -> void:
	if _despawn_timer > 0.0:
		_despawn_timer -= delta
		if _despawn_timer <= 0.0:
			call_deferred("queue_free")
			return

	if is_dead:
		return

	_time += delta

	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer <= 0:
			modulate = Color.WHITE
			queue_redraw()

	# Slow random wander
	_wander_timer += delta
	if _wander_timer > randf_range(3.0, 6.0):
		_wander_timer = 0.0
		_wander_dir = Vector2.from_angle(randf() * TAU)
	velocity = _wander_dir * speed
	position += velocity * delta

	# Electric pulse
	_pulse_timer += delta
	if _pulse_timer >= PULSE_INTERVAL:
		_pulse_timer = 0.0
		var player := _get_player()
		if is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist < PULSE_RANGE:
				call_deferred("_deal_pulse_damage")

	queue_redraw()


func _deal_pulse_damage() -> void:
	GameState.take_damage(PULSE_DAMAGE)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_float"):
		em.add_float("ZAP!", global_position + Vector2(0, -30), Color(0.7, 0.4, 1.0))


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
	GameState.add_xp(20)
	GameState.drop_ingredients("membrane_drifter")
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 1.2)
	call_deferred("_spawn_ingredient_loot")
	_despawn_timer = 1.4
	queue_redraw()
	died.emit()


func _spawn_ingredient_loot() -> void:
	GameState.add_ingredient("drifter_organ", 1)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_float"):
		em.add_float("+Drifter Organ", global_position + Vector2(0, -20), COLOR)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _draw() -> void:
	if is_dead:
		return
	# Circle with pulsing outer ring
	draw_circle(Vector2.ZERO, 25.0, COLOR * 0.5)
	draw_circle(Vector2.ZERO, 20.0, COLOR)
	var pulse_r: float = 25.0 + sin(_time * 2.0) * 5.0
	draw_arc(Vector2.ZERO, pulse_r, 0.0, TAU, 32, Color(0.7, 0.5, 1.0, 0.6), 2.0)
	# HP bar
	if hp < max_hp:
		var bw := 32.0
		var bh := 3.0
		var by := -34.0
		var pct := hp / max_hp
		draw_rect(Rect2(-bw / 2.0, by, bw, bh), Color(0.2, 0.2, 0.2, 0.8))
		var fc := Color(0.2, 0.9, 0.2) if pct > 0.5 else (Color(0.9, 0.7, 0.1) if pct > 0.25 else Color(0.9, 0.1, 0.1))
		draw_rect(Rect2(-bw / 2.0, by, bw * pct, bh), fc)
