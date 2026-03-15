extends Node2D

var _shape_points: PackedVector2Array
var _hit := false
var _size: float = 1.0

const CONTACT_DAMAGE := 6.0
const CONTACT_RANGE := 18.0
const CHECK_INTERVAL := 0.3
var _check_timer: float = 0.0


func _ready() -> void:
	add_to_group("hazard_asteroids")
	_size = randf_range(0.7, 1.3)
	_generate_shape()
	queue_redraw()


func _generate_shape() -> void:
	_shape_points = PackedVector2Array()
	for i in range(7):
		var angle: float = i * TAU / 7.0
		var radius: float = randf_range(9.0, 14.0) * _size
		_shape_points.append(Vector2(cos(angle), sin(angle)) * radius)


func _process(delta: float) -> void:
	if _hit:
		return
	_check_timer += delta
	if _check_timer < CHECK_INTERVAL:
		return
	_check_timer = 0.0

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var ship := players[0] as Node2D
	if not is_instance_valid(ship):
		return
	if global_position.distance_to(ship.global_position) < CONTACT_RANGE * _size:
		_on_hit()
		GameState.take_damage(CONTACT_DAMAGE)


func take_damage(_amount: float) -> void:
	if _hit:
		return
	_on_hit()


func _on_hit() -> void:
	_hit = true
	# Tiny scrap drop (50% chance of 1 scrap)
	if randf() < 0.5:
		GameState.add_resource("scrap", 1)
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_explosion"):
		em.add_explosion(global_position, 0.4)
	queue_redraw()


func _draw() -> void:
	if _hit:
		return
	# Dark red/orange hazard color, cracked look
	draw_colored_polygon(_shape_points, Color(0.55, 0.2, 0.1))
	# Hazard glow
	draw_arc(Vector2.ZERO, 13.0 * _size, 0.0, TAU, 8, Color(0.9, 0.3, 0.1, 0.35), 1.5)
	# Center
	draw_circle(Vector2.ZERO, 3.0 * _size, Color(0.8, 0.4, 0.1, 0.6))
