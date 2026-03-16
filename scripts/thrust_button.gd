extends Control

signal thrust_changed(active: bool)

var _is_active := false
var _touch_index := -1

const BTN_COLOR_INACTIVE := Color(0.15, 0.15, 0.2, 0.85)
const BTN_COLOR_ACTIVE := Color(0.2, 0.65, 1.0, 0.95)
const LABEL_COLOR := Color(0.8, 0.9, 1.0, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_set_active(true)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_set_active(false)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_set_active(event.pressed)

func _set_active(val: bool) -> void:
	if _is_active == val:
		return
	_is_active = val
	thrust_changed.emit(_is_active)
	queue_redraw()

func get_active() -> bool:
	return _is_active

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var style_color := BTN_COLOR_ACTIVE if _is_active else BTN_COLOR_INACTIVE
	draw_rect(r, style_color, true, -1.0)
	draw_rect(r, Color(0.4, 0.7, 1.0, 0.6), false, 2.0)
	# Triangle pointing up (thrust icon)
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var tri := PackedVector2Array([
		Vector2(cx, cy - 18),
		Vector2(cx - 14, cy + 12),
		Vector2(cx + 14, cy + 12)
	])
	draw_colored_polygon(tri, Color(0.8, 0.9, 1.0, 0.9))
	var lbl_font := ThemeDB.fallback_font
	draw_string(lbl_font, Vector2(cx - 22, cy + 30), "THRUST", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.85, 1.0, 0.8))
