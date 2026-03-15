extends Node2D

var artifact_data: Dictionary = {}
var _pulse_timer: float = 0.0
var _collected := false

signal collected(data: Dictionary)


func _ready() -> void:
	add_to_group("artifacts")
	queue_redraw()


func setup(data: Dictionary) -> void:
	artifact_data = data
	queue_redraw()


func try_collect(body: Node2D) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collected = true
		GameState.collect_artifact(artifact_data)
		GameState.record_artifact()
		GameState.add_xp(50)
		collected.emit(artifact_data)
		# Floating text
		var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
		if is_instance_valid(em) and em.has_method("add_float"):
			em.add_float("ARTIFACT!", global_position, Color.GOLD)
		queue_redraw()



func _process(delta: float) -> void:
	_pulse_timer += delta
	queue_redraw()
	# Auto-collect when ship is close
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0]
		if is_instance_valid(player) and global_position.distance_to(player.global_position) < 30.0:
			try_collect(player)


func _draw() -> void:
	if _collected:
		return
	var pulse := (sin(_pulse_timer * 3.0) + 1.0) * 0.5
	var glow_radius := 12.0 + pulse * 4.0
	draw_circle(Vector2.ZERO, glow_radius, Color(1.0, 0.8, 0.2, 0.2 + pulse * 0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -8), Vector2(-6, 0), Vector2(0, 8), Vector2(6, 0)
	]), Color(1.0, 0.85, 0.0))
	draw_circle(Vector2(0, -4), 2, Color.WHITE)
