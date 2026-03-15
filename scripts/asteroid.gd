extends Node2D

var resource_type: String = "ore"
var amount: int = 10
var is_being_mined := false
var _shape_points: PackedVector2Array

signal mining_complete()


func _ready() -> void:
	add_to_group("asteroids")
	var types := ["ore", "ore", "crystal", "scrap"]
	resource_type = types[randi() % types.size()]
	amount = randi_range(5, 20)
	_generate_shape()
	queue_redraw()


func _generate_shape() -> void:
	_shape_points = PackedVector2Array()
	for i in range(7):
		var angle: float = i * TAU / 7.0
		var radius: float = randf_range(9.0, 14.0)
		_shape_points.append(Vector2(cos(angle), sin(angle)) * radius)


func mine() -> void:
	if is_being_mined:
		return
	is_being_mined = true
	var bonus_mult := 1.0 + GameState.captain_mining_bonus
	var final_amount := int(round(float(amount) * bonus_mult))
	GameState.add_resource(resource_type, final_amount)
	GameState.add_xp(5)
	# Floating text effect
	var em := get_tree().get_first_node_in_group("effects_manager") as Node2D
	if is_instance_valid(em) and em.has_method("add_float"):
		var res_color := get_resource_color().lightened(0.3)
		var label := "+" + str(final_amount) + " " + resource_type.to_upper()
		em.add_float(label, global_position, res_color)
	queue_redraw()
	call_deferred("queue_free")



func get_resource_color() -> Color:
	match resource_type:
		"ore": return Color(0.67, 0.67, 0.67)
		"crystal": return Color(0.53, 1.0, 1.0)
		"scrap": return Color(0.53, 0.53, 0.27)
		_: return Color.WHITE


func _draw() -> void:
	if is_being_mined:
		return
	if _shape_points.is_empty():
		return
	draw_colored_polygon(_shape_points, get_resource_color())
	draw_circle(Vector2.ZERO, 3, get_resource_color().lightened(0.4))
