extends Node2D

const EVENT_HORIZON := 45.0
const PULL_RANGE := 400.0
const PULL_STRENGTH := 28000.0
const TELEPORT_DAMAGE := 20.0

var _anim_time: float = 0.0
var _teleporting := false


func _ready() -> void:
	add_to_group("black_holes")
	queue_redraw()


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()

	if _teleporting:
		return

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var ship := players[0] as Node2D
	if not is_instance_valid(ship):
		return

	var to_hole := global_position - ship.global_position
	var dist := to_hole.length()

	if dist < EVENT_HORIZON:
		_teleporting = true
		call_deferred("_do_teleport")
		return

	if dist < PULL_RANGE:
		var force: float = PULL_STRENGTH / max(dist * dist, 100.0)
		var pull_vec: Vector2 = to_hole.normalized() * force * delta
		if ship.has_method("apply_gravity"):
			ship.apply_gravity(pull_vec)


func _do_teleport() -> void:
	_teleporting = false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var ship := players[0] as Node2D
	if not is_instance_valid(ship):
		return
	var angle := randf() * TAU
	var dist := randf_range(1500.0, 3200.0)
	ship.global_position = Vector2(cos(angle), sin(angle)) * dist
	GameState.take_damage(TELEPORT_DAMAGE)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(ship.global_position, 0.6)
	var hud := get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("GRAVITATIONAL WARP — Location unknown", 3.0)


func _draw() -> void:
	var t := _anim_time
	# Accretion disk rings (outside-in)
	var ring_colors := [
		Color(0.6, 0.1, 1.0, 0.25),
		Color(0.7, 0.2, 1.0, 0.35),
		Color(0.8, 0.3, 1.0, 0.45),
		Color(0.9, 0.5, 1.0, 0.5),
		Color(1.0, 0.7, 1.0, 0.4),
	]
	for i in range(5):
		var r := EVENT_HORIZON + 60.0 - i * 11.0
		var rot_offset := t * (0.6 + i * 0.15) * (1 if i % 2 == 0 else -1)
		draw_arc(Vector2.ZERO, r, rot_offset, rot_offset + TAU * 0.85, 32, ring_colors[i], 3.5 - i * 0.4)
	# Event horizon
	draw_circle(Vector2.ZERO, EVENT_HORIZON, Color(0.0, 0.0, 0.0))
	# Inner singularity glow
	draw_arc(Vector2.ZERO, EVENT_HORIZON, 0.0, TAU, 32, Color(0.5, 0.0, 1.0, 0.7), 2.5)
	draw_arc(Vector2.ZERO, EVENT_HORIZON * 0.6, 0.0, TAU, 24, Color(0.8, 0.2, 1.0, 0.4), 1.5)
