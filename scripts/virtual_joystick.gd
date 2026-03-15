extends Control

const JOYSTICK_RADIUS := 60.0
const KNOB_RADIUS := 25.0

var _touch_index: int = -1
var _direction: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO


func get_direction() -> Vector2:
	return _direction


func _get_center() -> Vector2:
	return size / 2.0


func _input(event: InputEvent) -> void:
	# Catch touch releases anywhere on screen — gui_input only fires inside bounds
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and touch.index == _touch_index:
			_reset()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and _touch_index == 0:
			_reset()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_knob_offset = Vector2.ZERO
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_update_knob(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _touch_index == -1:
				_touch_index = 0
				_update_knob(mb.position)
			elif not mb.pressed and _touch_index == 0:
				_reset()
	elif event is InputEventMouseMotion:
		if _touch_index == 0:
			_update_knob(event.position)


func _update_knob(pos: Vector2) -> void:
	var center := _get_center()
	var diff := pos - center
	if diff.length() > JOYSTICK_RADIUS:
		diff = diff.normalized() * JOYSTICK_RADIUS
	_knob_offset = diff
	_direction = diff / JOYSTICK_RADIUS
	queue_redraw()


func _reset() -> void:
	_touch_index = -1
	_direction = Vector2.ZERO
	_knob_offset = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center := _get_center()
	var knob_pos := center + _knob_offset
	draw_circle(center, JOYSTICK_RADIUS, Color(1, 1, 1, 0.06))
	draw_arc(center, JOYSTICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(knob_pos, KNOB_RADIUS, Color(1, 1, 1, 0.45))
	draw_arc(knob_pos, KNOB_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.7), 2.0)
