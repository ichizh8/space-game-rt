extends Control

# Emits current throttle value 0.0–1.0 whenever it changes
signal throttle_changed(value: float)

var _throttle: float = 0.0      # 0.0 = off, 1.0 = full
var _touch_index: int = -1
var _drag_start_y: float = 0.0
var _drag_start_throttle: float = 0.0

const TRACK_HEIGHT: float = 160.0   # drawable track height in px
const TRACK_WIDTH: float = 36.0
const KNOB_RADIUS: float = 18.0
const COLOR_TRACK := Color(0.12, 0.14, 0.2, 0.85)
const COLOR_FILL := Color(0.2, 0.65, 1.0, 0.9)
const COLOR_KNOB := Color(0.85, 0.93, 1.0, 1.0)
const COLOR_BORDER := Color(0.4, 0.7, 1.0, 0.5)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(TRACK_WIDTH + 20.0, TRACK_HEIGHT + KNOB_RADIUS * 2.0 + 20.0)
	queue_redraw()

func get_throttle() -> float:
	return _throttle

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_drag_start_y = event.position.y
			_drag_start_throttle = _throttle
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			# throttle stays at current value — do not reset
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			var delta_y: float = _drag_start_y - event.position.y  # up = positive
			var delta_throttle: float = delta_y / TRACK_HEIGHT
			_throttle = clamp(_drag_start_throttle + delta_throttle, 0.0, 1.0)
			throttle_changed.emit(_throttle)
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start_y = event.position.y
				_drag_start_throttle = _throttle
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var delta_y: float = _drag_start_y - event.position.y
			var delta_throttle: float = delta_y / TRACK_HEIGHT
			_throttle = clamp(_drag_start_throttle + delta_throttle, 0.0, 1.0)
			throttle_changed.emit(_throttle)
			queue_redraw()

func _draw() -> void:
	var cx: float = size.x * 0.5
	var track_top: float = KNOB_RADIUS + 10.0
	var track_bottom: float = track_top + TRACK_HEIGHT

	# Track background
	draw_rect(Rect2(cx - TRACK_WIDTH * 0.5, track_top, TRACK_WIDTH, TRACK_HEIGHT), COLOR_TRACK, true, -1.0)
	draw_rect(Rect2(cx - TRACK_WIDTH * 0.5, track_top, TRACK_WIDTH, TRACK_HEIGHT), COLOR_BORDER, false, 1.5)

	# Fill (bottom to knob)
	var fill_height: float = TRACK_HEIGHT * _throttle
	draw_rect(Rect2(cx - TRACK_WIDTH * 0.5, track_bottom - fill_height, TRACK_WIDTH, fill_height), COLOR_FILL, true, -1.0)

	# Knob
	var knob_y: float = track_bottom - TRACK_HEIGHT * _throttle
	draw_circle(Vector2(cx, knob_y), KNOB_RADIUS, COLOR_KNOB)
	draw_circle(Vector2(cx, knob_y), KNOB_RADIUS, COLOR_BORDER, false, 1.5)

	# Label
	var lbl_font := ThemeDB.fallback_font
	draw_string(lbl_font, Vector2(cx - 18.0, track_bottom + KNOB_RADIUS + 14.0), "THRUST", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.85, 1.0, 0.75))

	# Throttle % indicator
	var pct_str: String = str(int(_throttle * 100.0)) + "%"
	draw_string(lbl_font, Vector2(cx - 12.0, track_top - 6.0), pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_FILL if _throttle > 0.0 else Color(0.5, 0.5, 0.5, 0.6))
