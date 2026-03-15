extends Node2D

var station_name: String = "Station Alpha"
var station_id: String = ""
var _anim_time: float = 0.0

signal docked(s_id: String, s_name: String)


func _ready() -> void:
	add_to_group("stations")
	queue_redraw()


func setup(s_id: String, s_name: String) -> void:
	station_id = s_id
	station_name = s_name


func dock() -> void:
	docked.emit(station_id, station_name)


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()


func _draw() -> void:
	var t := _anim_time * 0.4
	# Rotating body
	var pts := PackedVector2Array()
	for i in range(6):
		var a := t + i * TAU / 6.0
		pts.append(Vector2(cos(a), sin(a)) * 14.0)
	draw_colored_polygon(pts, Color(0.45, 0.55, 0.65))
	# Cross arms
	draw_rect(Rect2(-22, -4, 44, 8), Color(0.35, 0.45, 0.55))
	draw_rect(Rect2(-4, -22, 8, 44), Color(0.35, 0.45, 0.55))
	# Solar panels
	draw_rect(Rect2(-34, -7, 12, 14), Color(0.1, 0.25, 0.75, 0.85))
	draw_rect(Rect2(22, -7, 12, 14), Color(0.1, 0.25, 0.75, 0.85))
	draw_rect(Rect2(-7, -34, 14, 12), Color(0.1, 0.25, 0.75, 0.85))
	draw_rect(Rect2(-7, 22, 14, 12), Color(0.1, 0.25, 0.75, 0.85))
	# Hub
	draw_circle(Vector2.ZERO, 10.0, Color(0.6, 0.65, 0.7))
	# Running lights
	var blink := 0.5 + 0.5 * sin(_anim_time * 2.5)
	draw_circle(Vector2(14, 0), 2.5, Color(1.0, 0.9, 0.3, blink))
	draw_circle(Vector2(-14, 0), 2.5, Color(0.3, 0.7, 1.0, blink))
	draw_circle(Vector2(0, 14), 2.5, Color(1.0, 0.3, 0.3, 1.0 - blink))
	draw_circle(Vector2(0, -14), 2.5, Color(0.3, 1.0, 0.5, 1.0 - blink))
	# Docking label
	draw_string(ThemeDB.fallback_font, Vector2(-28, 30), station_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.8, 1.0, 0.85))
