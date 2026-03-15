extends Area2D

var resource_type: String = "ore"
var amount: int = 10
var is_being_mined := false

signal mining_started()
signal mining_complete()


func _ready() -> void:
	add_to_group("asteroids")
	var types := ["ore", "crystal", "scrap"]
	resource_type = types[randi() % types.size()]
	amount = randi_range(5, 20)
	queue_redraw()


func mine() -> void:
	if is_being_mined:
		return
	is_being_mined = true
	mining_started.emit()

	var mine_time := 1.0 - GameState.player_mining_speed_bonus
	mine_time = max(mine_time, 0.2)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), mine_time)
	tween.tween_callback(_finish_mining)


func _finish_mining() -> void:
	GameState.add_resource(resource_type, amount)
	mining_complete.emit()
	queue_free()


func get_resource_color() -> Color:
	match resource_type:
		"ore":
			return Color(0.67, 0.67, 0.67)
		"crystal":
			return Color(0.53, 1.0, 1.0)
		"scrap":
			return Color(0.53, 0.53, 0.27)
		_:
			return Color.WHITE


func _draw() -> void:
	# Draw irregular asteroid shape
	var color := get_resource_color()
	var points := PackedVector2Array()
	var num_points := 7
	for i in range(num_points):
		var angle := i * TAU / num_points
		var radius := 10.0 + randf_range(-3.0, 3.0) if i > 0 else 12.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
	# Small indicator dot for resource type
	draw_circle(Vector2.ZERO, 3, color.lightened(0.4))
