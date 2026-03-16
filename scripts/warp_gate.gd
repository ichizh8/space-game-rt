extends Node2D

var gate_name: String = "Gate"
var dest_sector: int = 1
var fuel_cost: int = 50

var _phase: float = 0.0

func _ready() -> void:
	add_to_group("warp_gates")

func _process(delta: float) -> void:
	_phase += delta * 2.0
	queue_redraw()

func activate() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if GameState.fuel < float(fuel_cost):
		if is_instance_valid(hud) and hud.has_method("show_notification"):
			hud.show_notification("Need " + str(fuel_cost) + " fuel to warp!", 3.0)
		return
	if is_instance_valid(hud) and hud.has_method("show_notification"):
		hud.show_notification("Warping to " + gate_name + "...", 2.0)
	GameState.fuel -= float(fuel_cost)
	GameState.call_deferred("travel_to_sector", dest_sector)

func _draw() -> void:
	var pulse: float = 0.7 + 0.3 * sin(_phase)
	var outer_r: float = 55.0
	var inner_r: float = 38.0
	# Outer glow ring
	draw_circle(Vector2.ZERO, outer_r + 6.0, Color(0.1, 0.5, 1.0, 0.2 * pulse))
	draw_circle(Vector2.ZERO, outer_r, Color(0.3, 0.7, 1.0, 0.5 * pulse))
	# Inner portal
	draw_circle(Vector2.ZERO, inner_r, Color(0.0, 0.2, 0.6, 0.7 * pulse))
	# Hex ring using arcs
	draw_arc(Vector2.ZERO, outer_r, 0.0, TAU, 32, Color(0.5, 0.9, 1.0, pulse), 3.0)
	# Gate name label
	draw_string(ThemeDB.fallback_font, Vector2(-30, outer_r + 20), gate_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.9, 1.0, 0.9))
	if fuel_cost > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-20, outer_r + 32), str(fuel_cost) + " fuel",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.8, 0.5, 0.8))
