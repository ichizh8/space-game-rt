extends Control

const JOYSTICK_RADIUS := 60.0
const KNOB_RADIUS := 25.0

var _touch_index: int = -1
var _direction: Vector2 = Vector2.ZERO
var _knob_position: Vector2 = Vector2.ZERO
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	_center = size / 2.0
	_knob_position = _center


func get_direction() -> Vector2:
	return _direction


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_index = touch.index
			_update_knob(touch.position)
		elif touch.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_touch_index = 0
			_update_knob(mb.position)
		else:
			_reset()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _touch_index >= 0:
			_update_knob(mm.position)


func _update_knob(pos: Vector2) -> void:
	var diff := pos - _center
	if diff.length() > JOYSTICK_RADIUS:
		diff = diff.normalized() * JOYSTICK_RADIUS
	_knob_position = _center + diff
	_direction = diff / JOYSTICK_RADIUS
	queue_redraw()


func _reset() -> void:
	_touch_index = -1
	_direction = Vector2.ZERO
	_knob_position = _center
	queue_redraw()


func _draw() -> void:
	# Outer ring
	draw_arc(_center, JOYSTICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.3), 2.0)
	draw_circle(_center, JOYSTICK_RADIUS, Color(1, 1, 1, 0.05))
	# Inner knob
	draw_circle(_knob_position, KNOB_RADIUS, Color(1, 1, 1, 0.4))
	draw_arc(_knob_position, KNOB_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
