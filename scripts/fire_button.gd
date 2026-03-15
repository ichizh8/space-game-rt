extends Control

signal toggled(active: bool)

var is_active := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			is_active = not is_active
			toggled.emit(is_active)
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			is_active = not is_active
			toggled.emit(is_active)
			queue_redraw()
			get_viewport().set_input_as_handled()


func set_active(value: bool) -> void:
	is_active = value
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius: float = min(center.x, center.y) - 5
	if is_active:
		draw_circle(center, radius, Color(1.0, 0.15, 0.15, 0.85))
		draw_arc(center, radius, 0, TAU, 32, Color(1.0, 0.5, 0.5, 1.0), 3.5)
		draw_string(ThemeDB.fallback_font, center + Vector2(-16, 5),
			"● AUTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	else:
		draw_circle(center, radius, Color(0.5, 0.1, 0.1, 0.45))
		draw_arc(center, radius, 0, TAU, 24, Color(0.8, 0.3, 0.3, 0.6), 2.0)
		draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color.WHITE, 2.0)
		draw_line(center + Vector2(0, -10), center + Vector2(0, 10), Color.WHITE, 2.0)
