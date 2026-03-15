extends CanvasLayer

var _joystick: Control
var _fire_button: Control
var _fire_pressed := false
var _items_button: Button = null
var _items_panel: CanvasLayer = null

# Action popup
var _action_button: Button
var _action_target: Node2D = null
var _action_type: String = ""

# Labels
var _hull_bar: ProgressBar
var _fuel_bar: ProgressBar
var _credits_label: Label
var _resource_label: Label
var _notification_label: Label
var _notification_timer: float = 0.0


func _ready() -> void:
	add_to_group("hud")
	layer = 10
	_build_ui()
	_connect_signals()
	_update_all()


func _build_ui() -> void:
	# Top bar container
	var top_bar := VBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 80
	top_bar.offset_left = 10
	top_bar.offset_right = -10
	top_bar.offset_top = 10
	add_child(top_bar)

	# Hull bar
	var hull_container := HBoxContainer.new()
	top_bar.add_child(hull_container)
	var hull_label := Label.new()
	hull_label.text = "Hull"
	hull_label.add_theme_font_size_override("font_size", 14)
	hull_label.custom_minimum_size.x = 50
	hull_container.add_child(hull_label)
	_hull_bar = ProgressBar.new()
	_hull_bar.max_value = GameState.max_hull
	_hull_bar.value = GameState.hull
	_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hull_bar.custom_minimum_size.y = 18
	var hull_style := StyleBoxFlat.new()
	hull_style.bg_color = Color(0.8, 0.1, 0.1)
	_hull_bar.add_theme_stylebox_override("fill", hull_style)
	hull_container.add_child(_hull_bar)

	# Fuel bar
	var fuel_container := HBoxContainer.new()
	top_bar.add_child(fuel_container)
	var fuel_label := Label.new()
	fuel_label.text = "Fuel"
	fuel_label.add_theme_font_size_override("font_size", 14)
	fuel_label.custom_minimum_size.x = 50
	fuel_container.add_child(fuel_label)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.max_value = GameState.max_fuel
	_fuel_bar.value = GameState.fuel
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_bar.custom_minimum_size.y = 18
	var fuel_style := StyleBoxFlat.new()
	fuel_style.bg_color = Color(0.1, 0.3, 0.9)
	_fuel_bar.add_theme_stylebox_override("fill", fuel_style)
	fuel_container.add_child(_fuel_bar)

	# Credits label
	_credits_label = Label.new()
	_credits_label.text = "Credits: " + str(GameState.credits)
	_credits_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(_credits_label)

	# Resource display (top-right)
	_resource_label = Label.new()
	_resource_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_resource_label.offset_left = -140
	_resource_label.offset_top = 10
	_resource_label.offset_right = -10
	_resource_label.add_theme_font_size_override("font_size", 12)
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_resource_label)

	# Virtual joystick (center-bottom)
	_joystick = Control.new()
	_joystick.set_script(load("res://scripts/virtual_joystick.gd"))
	_joystick.anchor_left = 0.5
	_joystick.anchor_right = 0.5
	_joystick.anchor_top = 1.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = -75
	_joystick.offset_right = 75
	_joystick.offset_top = -210
	_joystick.offset_bottom = -60
	add_child(_joystick)

	# Fire button (bottom-right) — styled Button
	var fire_btn := Button.new()
	fire_btn.text = "FIRE"
	fire_btn.add_theme_font_size_override("font_size", 16)
	fire_btn.anchor_left = 1.0
	fire_btn.anchor_right = 1.0
	fire_btn.anchor_top = 1.0
	fire_btn.anchor_bottom = 1.0
	fire_btn.offset_left = -110
	fire_btn.offset_right = -20
	fire_btn.offset_top = -110
	fire_btn.offset_bottom = -20
	var fire_style := StyleBoxFlat.new()
	fire_style.bg_color = Color(0.7, 0.1, 0.1, 0.6)
	fire_style.corner_radius_top_left = 45
	fire_style.corner_radius_top_right = 45
	fire_style.corner_radius_bottom_left = 45
	fire_style.corner_radius_bottom_right = 45
	fire_btn.add_theme_stylebox_override("normal", fire_style)
	var fire_style_pressed := fire_style.duplicate() as StyleBoxFlat
	fire_style_pressed.bg_color = Color(1.0, 0.2, 0.2, 0.9)
	fire_btn.add_theme_stylebox_override("pressed", fire_style_pressed)
	fire_btn.gui_input.connect(_on_fire_input)
	_fire_button = fire_btn
	add_child(_fire_button)

	# Action button (center of screen, above controls)
	_action_button = Button.new()
	_action_button.set_anchors_preset(Control.PRESET_CENTER)
	_action_button.offset_left = -80
	_action_button.offset_right = 80
	_action_button.offset_top = 60
	_action_button.offset_bottom = 110
	_action_button.add_theme_font_size_override("font_size", 18)
	_action_button.visible = false
	_action_button.pressed.connect(_on_action_pressed)
	add_child(_action_button)

	# Notification label (center)
	_notification_label = Label.new()
	_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notification_label.offset_top = 100
	_notification_label.offset_left = -150
	_notification_label.offset_right = 150
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.add_theme_font_size_override("font_size", 16)
	_notification_label.add_theme_color_override("font_color", Color.YELLOW)
	_notification_label.visible = false
	add_child(_notification_label)


func _connect_signals() -> void:
	GameState.hull_changed.connect(_on_hull_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.resources_changed.connect(_on_resources_changed)


func _process(delta: float) -> void:
	_check_nearby_objects()

	if _notification_timer > 0:
		_notification_timer -= delta
		if _notification_timer <= 0:
			_notification_label.visible = false

	# Continuously update fire state on ship
	var ship := get_tree().get_first_node_in_group("player")
	if is_instance_valid(ship) and ship.has_method("set_firing"):
		ship.set_firing(_fire_pressed)


func get_joystick_direction() -> Vector2:
	_update_items_button()
	if is_instance_valid(_joystick) and _joystick.has_method("get_direction"):
		return _joystick.get_direction()
	return Vector2.ZERO


func _on_fire_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_fire_pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		_fire_pressed = (event as InputEventMouseButton).pressed


func _check_nearby_objects() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(ship):
		_hide_action()
		return

	var ship_pos: Vector2 = ship.global_position
	var closest_dist := 999999.0
	var closest_node: Node2D = null
	var closest_type := ""

	# Check asteroids
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(asteroid):
			continue
		if asteroid.get("is_being_mined") == true:
			continue
		var dist: float = ship_pos.distance_to(asteroid.global_position)
		if dist < 80.0 and dist < closest_dist:
			closest_dist = dist
			closest_node = asteroid
			closest_type = "Mine"

	# Check planets
	for planet in get_tree().get_nodes_in_group("planets"):
		if not is_instance_valid(planet):
			continue
		var dist: float = ship_pos.distance_to(planet.global_position)
		if dist < 80.0 and dist < closest_dist:
			closest_dist = dist
			closest_node = planet
			closest_type = "Land"

	if is_instance_valid(closest_node):
		_show_action(closest_type, closest_node)
	else:
		_hide_action()


func _show_action(action_type: String, target: Node2D) -> void:
	_action_type = action_type
	_action_target = target
	_action_button.text = action_type
	_action_button.visible = true


func _hide_action() -> void:
	_action_button.visible = false
	_action_target = null
	_action_type = ""


func _on_action_pressed() -> void:
	if not is_instance_valid(_action_target):
		return
	# Reset joystick to prevent stuck touch state
	if is_instance_valid(_joystick) and _joystick.has_method("_reset"):
		_joystick._reset()
	match _action_type:
		"Mine":
			if _action_target.has_method("mine"):
				_action_target.mine()
				_hide_action()
		"Land":
			if _action_target.has_method("land"):
				_action_target.land()
				_hide_action()


func show_notification(text: String, duration: float = 3.0) -> void:
	_notification_label.text = text
	_notification_label.visible = true
	_notification_timer = duration


func _update_all() -> void:
	_on_hull_changed(GameState.hull)
	_on_fuel_changed(GameState.fuel)
	_on_credits_changed(GameState.credits)
	_on_resources_changed()


func _on_hull_changed(value: float) -> void:
	if is_instance_valid(_hull_bar):
		_hull_bar.value = value


func _on_fuel_changed(value: float) -> void:
	if is_instance_valid(_fuel_bar):
		_fuel_bar.value = value


func _on_credits_changed(value: int) -> void:
	if is_instance_valid(_credits_label):
		_credits_label.text = "Credits: " + str(value)


func _on_resources_changed() -> void:
	if is_instance_valid(_resource_label):
		_resource_label.text = "Ore: %d\nCrystal: %d\nFuel: %d\nScrap: %d" % [
			GameState.resources["ore"],
			GameState.resources["crystal"],
			GameState.resources["fuel"],
			GameState.resources["scrap"]
		]


func _draw_fire_button() -> void:
	pass  # Drawn by child Control


# Draw fire button visuals
func _on_fire_button_draw() -> void:
	var center := _fire_button.size / 2.0
	var radius: float = min(center.x, center.y) - 5
	_fire_button.draw_circle(center, radius, Color(0.8, 0.1, 0.1, 0.5 if not _fire_pressed else 0.8))
	_fire_button.draw_arc(center, radius, 0, TAU, 24, Color(1, 0.3, 0.3, 0.8), 2.0)
	# Draw crosshair
	_fire_button.draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color.WHITE, 2.0)
	_fire_button.draw_line(center + Vector2(0, -10), center + Vector2(0, 10), Color.WHITE, 2.0)

func _update_items_button() -> void:
	if is_instance_valid(_items_button):
		var count := GameState.artifacts_collected.size()
		_items_button.text = "ITEMS %d" % count


func _on_items_pressed() -> void:
	if is_instance_valid(_items_panel):
		_items_panel.queue_free()
		_items_panel = null
		return
	_show_items_panel()


func _show_items_panel() -> void:
	var panel_layer := CanvasLayer.new()
	panel_layer.layer = 10
	_items_panel = panel_layer

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_layer.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -160
	panel.offset_right = 160
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "COLLECTED ARTIFACTS"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	if GameState.artifacts_collected.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No artifacts found yet.\nExplore to find them!"
		none_lbl.add_theme_font_size_override("font_size", 13)
		none_lbl.add_theme_color_override("font_color", Color.GRAY)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(none_lbl)
	else:
		for art_id in GameState.artifacts_collected:
			var data := WorldData.get_artifact_by_id(art_id)
			if data.is_empty():
				continue
			var row := VBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.text = "★ " + data.get("name", art_id)
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color", Color.YELLOW)
			row.add_child(name_lbl)
			var desc_lbl := Label.new()
			desc_lbl.text = data.get("description", "")
			desc_lbl.add_theme_font_size_override("font_size", 11)
			desc_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(desc_lbl)
			vbox.add_child(row)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size.y = 40
	close_btn.pressed.connect(func():
		if is_instance_valid(_items_panel):
			_items_panel.queue_free()
			_items_panel = null)
	vbox.add_child(close_btn)

	add_child(panel_layer)
