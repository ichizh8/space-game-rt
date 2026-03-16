extends Node2D

var is_salvaged := false
var _rot_offset: float = 0.0

signal scavenge_started()


func _ready() -> void:
	add_to_group("derelicts")
	_rot_offset = randf_range(-0.5, 0.5)
	rotation = randf() * TAU
	queue_redraw()


func can_scavenge() -> bool:
	return not is_salvaged


func scavenge() -> void:
	if is_salvaged:
		return
	is_salvaged = true
	scavenge_started.emit()
	call_deferred("_do_scavenge")


func _do_scavenge() -> void:
	# Show notification for the 6s timer
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("Scavenging wreck... (6s)", 6.0)

	# Wait using a timer node
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 6.0
	add_child(timer)
	timer.timeout.connect(_on_scavenge_complete)
	timer.start()


func _on_scavenge_complete() -> void:
	# Drop resources
	var loot_scene: PackedScene = load("res://scenes/loot_drop.tscn") as PackedScene
	if not is_instance_valid(loot_scene):
		return
	var types: Array[String] = ["ore", "crystal", "scrap"]
	var res: Dictionary = {}
	var drop_count: int = randi_range(3, 8)
	for i in range(drop_count):
		var t: String = types[randi() % types.size()]
		res[t] = int(res.get(t, 0)) + 1

	var cr: int = randi_range(15, 40)

	# Artifact chance 15%
	if randf() < 0.15:
		var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
		if is_instance_valid(em) and em.has_method("add_float"):
			em.add_float("ARTIFACT FOUND!", global_position + Vector2(0, -30), Color(1.0, 0.8, 0.0))
		GameState.record_artifact()
		cr += 50

	var loot: Node2D = loot_scene.instantiate() as Node2D
	loot.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	if loot.has_method("setup"):
		loot.setup(cr, res)
	get_parent().add_child(loot)

	var hud: Node = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("Scavenging complete!", 2.0)
	queue_redraw()


func _draw() -> void:
	# Dark gray irregular shape — derelict wreck
	var col: Color = Color(0.35, 0.35, 0.38, 0.9) if not is_salvaged else Color(0.25, 0.25, 0.28, 0.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8), Vector2(-4, -14), Vector2(10, -10),
		Vector2(14, 2), Vector2(8, 12), Vector2(-6, 10), Vector2(-14, 4)
	]), col)
	# Damage marks
	draw_line(Vector2(-8, -4), Vector2(4, 6), Color(0.2, 0.2, 0.2, 0.6), 1.5)
	draw_line(Vector2(2, -8), Vector2(-4, 4), Color(0.2, 0.2, 0.2, 0.5), 1.0)
	# Label
	var label: String = "DERELICT" if not is_salvaged else "SALVAGED"
	var label_col: Color = Color(0.6, 0.6, 0.7, 0.6) if not is_salvaged else Color(0.4, 0.4, 0.5, 0.4)
	draw_string(ThemeDB.fallback_font, Vector2(-16, -18), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, label_col)
