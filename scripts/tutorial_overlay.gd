extends CanvasLayer

var _current_panel: int = 0
var _panels: Array[Control] = []

const TUTORIAL_FLAG_PATH := "user://tutorial_done.flag"


func _ready() -> void:
	layer = 30
	# Check if tutorial already completed
	if FileAccess.file_exists(TUTORIAL_FLAG_PATH):
		call_deferred("queue_free")
		return
	_build_ui()


func _build_ui() -> void:
	# Semi-transparent overlay
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	# Build 3 panels
	_panels.append(_build_panel_1(bg))
	_panels.append(_build_panel_2(bg))
	_panels.append(_build_panel_3(bg))

	# Show only the first panel
	for i in range(_panels.size()):
		_panels[i].visible = (i == 0)


func _build_panel_1(parent: Control) -> Control:
	var vbox := _make_centered_vbox(parent)

	var title := Label.new()
	title.text = "MOVEMENT"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_spacer(20))

	var desc := Label.new()
	desc.text = "Use the joystick to fly your ship"
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color.WHITE)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var arrow := Label.new()
	arrow.text = "v"
	arrow.add_theme_font_size_override("font_size", 40)
	arrow.add_theme_color_override("font_color", Color.YELLOW)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(arrow)

	vbox.add_child(_spacer(20))

	var btn := Button.new()
	btn.text = "TAP TO CONTINUE"
	btn.custom_minimum_size.y = 44
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_next_panel)
	vbox.add_child(btn)

	return vbox


func _build_panel_2(parent: Control) -> Control:
	var vbox := _make_centered_vbox(parent)

	var title := Label.new()
	title.text = "MINING"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_spacer(20))

	var desc := Label.new()
	desc.text = "Fly near asteroids to mine resources\nResources fuel upgrades and repairs"
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color.WHITE)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(_spacer(30))

	var btn := Button.new()
	btn.text = "TAP TO CONTINUE"
	btn.custom_minimum_size.y = 44
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_next_panel)
	vbox.add_child(btn)

	return vbox


func _build_panel_3(parent: Control) -> Control:
	var vbox := _make_centered_vbox(parent)

	var title := Label.new()
	title.text = "COMBAT"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_spacer(20))

	var desc := Label.new()
	desc.text = "FIRE button toggles auto-fire\nDestroy enemies to earn credits and XP"
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color.WHITE)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(_spacer(30))

	var btn := Button.new()
	btn.text = "GOT IT"
	btn.custom_minimum_size.y = 48
	btn.add_theme_font_size_override("font_size", 18)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.5, 0.2, 0.9)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(_finish_tutorial)
	vbox.add_child(btn)

	return vbox


func _make_centered_vbox(parent: Control) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(280, 300)
	vbox.offset_left = -140
	vbox.offset_top = -150
	vbox.offset_right = 140
	vbox.offset_bottom = 150
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)
	return vbox


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = height
	return s


func _next_panel() -> void:
	if _current_panel < _panels.size():
		_panels[_current_panel].visible = false
	_current_panel += 1
	if _current_panel < _panels.size():
		_panels[_current_panel].visible = true


func _finish_tutorial() -> void:
	# Mark tutorial as done
	var file := FileAccess.open(TUTORIAL_FLAG_PATH, FileAccess.WRITE)
	if file:
		file.store_string("done")
		file.close()
	call_deferred("queue_free")
