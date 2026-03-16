extends Node2D

var difficulty_mult: float = 1.0
var _armed := false
var _arm_timer: float = 1.5   # grace period before arming
var _lifetime: float = 30.0
var _blink_timer: float = 0.0
var _triggered := false

const TRIGGER_RANGE := 55.0
const EXPLOSION_DAMAGE := 22.0
const EXPLOSION_RADIUS := 90.0

func _ready() -> void:
	add_to_group("mines")
	queue_redraw()

func setup(diff_mult: float) -> void:
	difficulty_mult = diff_mult

func _process(delta: float) -> void:
	if _triggered:
		return

	_arm_timer -= delta
	if _arm_timer <= 0 and not _armed:
		_armed = true

	_lifetime -= delta
	if _lifetime <= 0:
		call_deferred("queue_free")
		return

	_blink_timer += delta

	if _armed:
		var player := _get_player()
		if is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist < TRIGGER_RANGE:
				_triggered = true
				call_deferred("_explode")

	queue_redraw()

func _explode() -> void:
	var player := _get_player()
	if is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist < EXPLOSION_RADIUS:
			GameState.take_damage(EXPLOSION_DAMAGE * difficulty_mult)

	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 1.2)
		em.add_float("MINE!", global_position + Vector2(0, -20), Color(1.0, 0.5, 0.0))

	call_deferred("queue_free")

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _draw() -> void:
	if _triggered:
		return
	var tex := load("res://assets/2026-03-15-mine.png") as Texture2D
	if is_instance_valid(tex):
		var s := tex.get_size()
		draw_texture(tex, -s / 2.0)
		return
	# Fallback: spiky circle mine
	var blink_on := _armed and fmod(_blink_timer, 0.6) < 0.3
	var body_col := Color(0.3, 0.3, 0.35) if _armed else Color(0.4, 0.4, 0.45)
	draw_circle(Vector2.ZERO, 7.0, body_col)
	# Spikes
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		var inner := Vector2(cos(angle), sin(angle)) * 7.0
		var outer := Vector2(cos(angle), sin(angle)) * 12.0
		draw_line(inner, outer, body_col, 2.0)
	# Warning light
	var light_col := Color(0.9, 0.1, 0.1, 1.0) if blink_on else Color(0.4, 0.1, 0.1)
	draw_circle(Vector2.ZERO, 3.0, light_col)
