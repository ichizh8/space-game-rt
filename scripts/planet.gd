extends Node2D

var planet_id: String = ""
var planet_name: String = "Unknown"
var quest_id: String = ""
var planet_color: Color = Color.GREEN
var _color_h: float = 0.3
var planet_radius: float = 30.0

signal landed(p_planet_id: String, p_planet_name: String, p_quest_id: String)


func _ready() -> void:
	add_to_group("planets")
	queue_redraw()


func setup(p_name: String, p_id: String, p_quest_id: String) -> void:
	planet_name = p_name
	planet_id = p_id
	quest_id = p_quest_id
	# Generate a color based on name hash
	var hash_val := planet_name.hash()
	_color_h = fmod(abs(float(hash_val)) / 1000.0, 1.0)
	planet_color = Color.from_hsv(_color_h, 0.5, 0.8)
	planet_radius = randf_range(25.0, 40.0)
	queue_redraw()


func land() -> void:
	GameState.last_planet_id = planet_id
	landed.emit(planet_id, planet_name, quest_id)


func _draw() -> void:
	# Planet body
	draw_circle(Vector2.ZERO, planet_radius, planet_color)
	# Atmosphere ring
	draw_arc(Vector2.ZERO, planet_radius + 4, 0, TAU, 32, planet_color.lightened(0.3), 2.0)
	# Surface detail (horizontal line)
	draw_line(
		Vector2(-planet_radius * 0.7, planet_radius * 0.2),
		Vector2(planet_radius * 0.7, planet_radius * 0.2),
		planet_color.darkened(0.3), 2.0
	)
	draw_line(
		Vector2(-planet_radius * 0.5, -planet_radius * 0.3),
		Vector2(planet_radius * 0.5, -planet_radius * 0.3),
		planet_color.darkened(0.2), 1.5
	)
	# Name label
	var name_width: float = planet_name.length() * 6.0
	draw_string(ThemeDB.fallback_font, Vector2(-name_width * 0.5, planet_radius + 14.0),
		planet_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.95, 1.0, 0.9))
