extends Node2D

var credits: int = 0
var resources: Dictionary = {}  # e.g. {"ore": 3}
var _anim_time: float = 0.0
var _lifetime: float = 0.0
var _collected := false
var _check_timer: float = 0.0
var _grace_timer: float = 0.0
const GRACE_PERIOD := 0.5  # seconds before loot can be collected

const PICKUP_RANGE := 40.0
const MAX_LIFETIME := 18.0
var _drift_dir: Vector2


func _ready() -> void:
	add_to_group("loot_drops")
	_drift_dir = Vector2.from_angle(randf() * TAU) * randf_range(8.0, 18.0)
	queue_redraw()


func setup(cr: int, res: Dictionary) -> void:
	credits = cr
	resources = res


func _process(delta: float) -> void:
	if _collected:
		return

	_anim_time += delta
	_lifetime += delta
	position += _drift_dir * delta
	_drift_dir *= 0.96  # slow drift to stop

	if _lifetime >= MAX_LIFETIME:
		_collected = true
		call_deferred("queue_free")
		return

	_grace_timer += delta

	_check_timer += delta
	if _grace_timer < GRACE_PERIOD:
		pass
	if _grace_timer >= GRACE_PERIOD and _check_timer >= 0.15:
		_check_timer = 0.0
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var ship := players[0] as Node2D
			if is_instance_valid(ship) and global_position.distance_to(ship.global_position) < PICKUP_RANGE:
				_collected = true
				call_deferred("_collect")

	queue_redraw()


func _collect() -> void:
	if not _collected:
		_collected = true
	if credits > 0:
		GameState.add_credits(credits)
		var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
		if is_instance_valid(em) and em.has_method("add_float"):
			em.add_float("+" + str(credits) + " cr", global_position, Color.GOLD)
	for res in resources:
		var amt: int = resources[res]
		if amt > 0:
			GameState.add_resource(res, amt)
	call_deferred("queue_free")


func _draw() -> void:
	if _collected:
		return
	var blink: float = 0.6 + 0.4 * sin(_anim_time * 5.0)
	var fade: float = 1.0 - clamp(_lifetime / MAX_LIFETIME, 0.0, 1.0) * 0.6
	# Outer glow
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.85, 0.1, 0.15 * blink * fade))
	# Main orb
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.2, 0.7 * blink * fade))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 1.0, 0.6, fade))
	# Credit label if has credits
	if credits > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-12, -12), str(credits) + "cr",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 1.0, 0.4, 0.8 * fade))
